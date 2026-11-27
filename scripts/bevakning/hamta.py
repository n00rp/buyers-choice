#!/usr/bin/env python3
"""Hämtar läget för planarbete och gällande planer i Göteborg och skriver vad som är nytt.

Körs av GitHub Actions varje dag (se .github/workflows/bevakning.yml), men går lika bra att
köra för hand från repots rot:

    python3 scripts/bevakning/hamta.py

Källor (öppna, utan nyckel):
  * Stadens databas för plan- och byggprojekt, samma som visar projektsidorna på goteborg.se
    (www5.goteborg.se/prod/fastighetskontoret/etjanst/planobygg.nsf). Där finns varje
    planarbetes processteg (startskede, samråd, granskning, antagande, laga kraft …),
    koordinat, tider för synpunkter och stadens egna uppdateringsnotiser.
  * Stadsbyggnadskontorets WFS för gällande planer (planer-v3).

Skriver:
  bevakning/lage.json               senaste läget, används för att se vad som ändrats
  portal/bevakning/planarbete.json  publicerade planarbeten med läge och skede (till portalen)
  portal/bevakning/handelser.json   händelser de senaste 400 dagarna (till portalen och mejlen)

Bara standardbiblioteket används, så skriptet kräver inga paket.
"""
import datetime as dt
import email.utils
import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ROT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LAGE = os.path.join(ROT, "bevakning", "lage.json")
UT_PROJ = os.path.join(ROT, "portal", "bevakning", "planarbete.json")
UT_HAND = os.path.join(ROT, "portal", "bevakning", "handelser.json")
ADRESSER = os.path.join(ROT, "portal", "adresser.json")

PLANOBYGG = "https://www5.goteborg.se/prod/fastighetskontoret/etjanst/planobygg.nsf"
PLANER_WFS = ("https://geodata-external.sbk.goteborg.se/services/planer-v3/wfs?service=WFS&version=2.0.0"
              "&request=GetFeature&typeNames=planer-v3:planer&outputFormat=application/json&srsName=EPSG:3007")
PROJEKTSIDA = "https://goteborg.se/wps/portal?uri=gbglnk:gbg.page.bb7386fd-1152-47cb-9da4-d06bd7780a77&projektid="
SPARA_DAGAR = 400
UA = {"User-Agent": "buyers-choice-bevakning/1.0"}


def hamta(url, timeout=120):
    req = urllib.request.Request(url, headers=UA)
    for forsok in range(3):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:  # nätverksfel: försök igen
            if forsok == 2:
                raise
            print(f"  försöker igen ({e})", file=sys.stderr)


def vy(namn):
    """Läser en vy ur planobygg-databasen som lista av dict (kolumnnamn -> värde)."""
    url = f"{PLANOBYGG}/{urllib.parse.quote(namn)}?ReadViewEntries&count=10000"
    rot = ET.fromstring(hamta(url))
    ut = []
    for ve in rot.iter("viewentry"):
        d = {"unid": ve.get("unid")}
        for ed in ve.iter("entrydata"):
            v = [x.text or "" for x in ed.iter() if x.tag in ("text", "datetime", "number")]
            d[ed.get("name")] = v[0] if len(v) == 1 else v
        ut.append(d)
    return ut


def ren(s):
    return re.sub(r"\s+", " ", s or "").strip()


def dnr_nyckel(s):
    """Normaliserar diarienummer så att 'SBF 2024-01464', 'SBF: SBF-2024-01464' och 'SBF-2024-01464' blir lika."""
    s = urllib.parse.unquote(s or "").upper()
    s = re.sub(r"^[A-Z]+:\s*", "", s)
    return re.sub(r"[^A-Z0-9/]", "", s)


# Processteg -> fas. Faserna är neutrala beskrivningar av var i processen planarbetet är.
FASER = [
    ("avbrutet", r"avbrut|avslutat"),
    ("pausad", r"vilande|pausad"),
    ("overklagad", r"överklag"),
    ("fardig", r"färdigställ|inflytt"),
    ("bygge", r"bygg|pågående arbeten"),
    ("lagakraft", r"laga kraft|godkän|antecknat"),
    ("antagande", r"antagande"),
    ("granskning", r"granskning|utställning|slutligt förslag"),
    ("samrad", r"samråd"),
    ("tidigt", r"start|förstudie|inför program|program|utredning|studie|stadsutvecklings"),
]
FASNAMN = {
    "tidigt": "Tidigt skede", "samrad": "Samråd", "granskning": "Granskning", "antagande": "Antagande",
    "overklagad": "Överklagad", "lagakraft": "Laga kraft", "bygge": "Byggande pågår", "fardig": "Färdigställt",
    "avbrutet": "Avbrutet", "pausad": "Pausat", "okand": "Okänt skede",
}


def fas(steg):
    s = (steg or "").lower()
    for f, mon in FASER:
        if re.search(mon, s):
            return f
    return "okand"


def slag(steg, namn):
    s = (steg or "").lower()
    if s.startswith("program") or namn.lower().startswith("program"):
        return "Program"
    if "översiktsplan" in s:
        return "Översiktsplan"
    if "trafik" in s:
        return "Trafikprojekt"
    if "områdesbestämmelse" in s:
        return "Områdesbestämmelser"
    if s.startswith(("plan", "enkel plan")):
        return "Detaljplan"
    return "Projekt"


def gatuindex():
    """Gatunamn -> (medelpunkt, {husnummer: punkt}), för planarbeten som saknar koordinat i stadens databas."""
    try:
        a = json.load(open(ADRESSER, encoding="utf-8"))
    except OSError:
        return {}
    e0, n0 = a["o"]
    ut = {}
    for namn, rader in a["s"]:
        if not rader or len(namn) < 6:
            continue
        e = sum(r[1] for r in rader) / len(rader) + e0
        n = sum(r[2] for r in rader) / len(rader) + n0
        ut[namn.lower()] = ((round(e), round(n)), {str(r[0]).lower(): (r[1] + e0, r[2] + n0) for r in rader})
    return ut


def gissa_lage(namn, gator):
    """Letar efter ett gatunamn, gärna med husnummer, i planarbetets namn ('… vid Karl Johansgatan 130').
    Ger None om inget hittas. Läget blir då ungefärligt och märks så i portalen."""
    lag = namn.lower()
    basta = None
    for g in gator:
        if g in lag and re.search(r"(?<![a-zåäöé])" + re.escape(g) + r"(?![a-zåäöé])", lag):
            if basta is None or len(g) > len(basta):
                basta = g
    if not basta:
        return None
    mitt, nummer = gator[basta]
    m = re.search(re.escape(basta) + r"\s+(\d+\s?[a-z]?)\b", lag)
    if m and m.group(1).replace(" ", "") in nummer:
        return nummer[m.group(1).replace(" ", "")]
    return mitt


def hamta_projekt():
    koord = vy("(lookupProjektXMLKoordinater)")
    publ = {r["unid"]: r.get("keyPublicerad") == "ja" for r in vy("Bara projektdefinitioner")}
    syn = {r["unid"]: (r.get("datLamnaSynpunktFrom", ""), r.get("datLamnaSynpunktTom", ""))
           for r in vy("vyPlanSynpunkt")}
    gator = gatuindex()
    proj = {}
    for r in koord:
        u = r["unid"]
        if not u or not publ.get(u):
            continue
        namn = ren(r.get("txtPlannamn"))
        steg = ren(r.get("keyProcessteg")).rstrip(".")
        dnr = ren(r.get("$26"))
        x, y, ungefar = r.get("koordX"), r.get("koordY"), False
        try:
            x, y = int(float(x)), int(float(y))
        except (TypeError, ValueError):
            g = gissa_lage(namn, gator)
            x, y, ungefar = (g[0], g[1], True) if g else (None, None, False)
        p = {"namn": namn, "steg": steg, "fas": fas(steg), "slag": slag(steg, namn), "dnr": dnr,
             "x": x, "y": y, "lank": PROJEKTSIDA + urllib.parse.quote(dnr) if dnr else ""}
        if ungefar:
            p["ungefar"] = True
        if u in syn:
            p["synpunkter"] = [d[:8] for d in syn[u]]
        proj[u] = p
    return proj


def hamta_notiser():
    """Stadens egna notiser om uppdaterade projektsidor ('Samråd pågår', 'Nu finns granskningshandlingarna …')."""
    ut = []
    for r in vy("viewrssall"):
        it = r.get("$4") or ""
        if isinstance(it, list):
            it = "".join(it)
        t = re.search(r"<title>(.*?)</title>", it, re.S)
        l = re.search(r"<link>(.*?)</link>", it, re.S)
        d = re.search(r"<description>(.*?)</description>", it, re.S)
        p = re.search(r"<pubDate>(.*?)</pubDate>", it, re.S)
        if not (t and l and p):
            continue
        lank = l.group(1).replace("&amp;", "&")
        q = urllib.parse.parse_qs(urllib.parse.urlparse(lank).query)
        try:
            datum = email.utils.parsedate_to_datetime(p.group(1)).date().isoformat()
        except (TypeError, ValueError):
            continue
        ut.append({"unid": r["unid"], "rubrik": ren(t.group(1)).removeprefix("Uppdatering i ").strip(),
                   "text": ren(d.group(1)) if d else "", "datum": datum, "lank": lank,
                   "dnr": dnr_nyckel((q.get("projektid") or [""])[0])})
    return ut


def hamta_planer():
    fc = json.loads(hamta(PLANER_WFS, timeout=300))
    ut = {}
    for f in fc["features"]:
        pr = f["properties"]
        bet = pr.get("beteckning")
        if not bet:
            continue
        xs, ys = [], []

        def gå(c):
            if c and isinstance(c[0], (int, float)):
                xs.append(c[0]); ys.append(c[1])
            else:
                for d in c or []:
                    gå(d)
        gå((f.get("geometry") or {}).get("coordinates"))
        b = ut.get(bet)
        box = [min(xs), min(ys), max(xs), max(ys)] if xs else None
        if b and box and b["box"]:
            b["box"] = [min(b["box"][0], box[0]), min(b["box"][1], box[1]), max(b["box"][2], box[2]), max(b["box"][3], box[3])]
            continue
        ut[bet] = {"typ": pr.get("typ") or "", "namn": ren(pr.get("beskrivning")), "url": pr.get("url") or "", "box": box}
    for b in ut.values():
        bx = b.pop("box")
        b["x"], b["y"] = (round((bx[0] + bx[2]) / 2), round((bx[1] + bx[3]) / 2)) if bx else (None, None)
    return ut


def hid(*delar):
    return hashlib.sha1("|".join(map(str, delar)).encode()).hexdigest()[:12]


def planens_namn(s):
    s = re.sub(r"^\s*\d+\s*[-–]\s*", "", s or "").strip()
    return s[:1] + s[1:].lower() if s.isupper() else s


def handelser_fran(fore, nu, idag):
    """Jämför två lägen och ger nya händelser."""
    ut = []
    fp, np_ = fore.get("projekt", {}), nu["projekt"]
    for u, p in np_.items():
        g = fp.get(u)
        if g is None:
            ut.append({"typ": "nytt_planarbete", "rubrik": p["namn"],
                       "text": f"Nytt planarbete i stadens projektlista. Skede: {p['steg'] or FASNAMN[p['fas']]}.",
                       "projekt": u})
        elif g.get("steg") != p["steg"] and p["steg"]:
            ut.append({"typ": "nytt_skede", "rubrik": p["namn"],
                       "text": f"Planarbetet har gått från {g.get('steg') or 'okänt skede'} till {p['steg']}.",
                       "projekt": u, "fas": p["fas"]})
        if p.get("synpunkter") and (g or {}).get("synpunkter") != p["synpunkter"]:
            fr, to = p["synpunkter"]
            ut.append({"typ": "synpunkter", "rubrik": p["namn"],
                       "text": f"Det går att lämna synpunkter {datum_text(fr)} till {datum_text(to)}.",
                       "projekt": u, "datum": iso(fr) or idag})
    if fore.get("planer") is not None:
        kanda = set(fore["planer"])
        for bet, pl in nu["planer"].items():
            if bet not in kanda:
                ut.append({"typ": "ny_plan", "rubrik": planens_namn(pl["namn"]) or bet,
                           "text": f"{pl['typ'] or 'Plan'} {bet} finns nu bland stadens gällande planer.",
                           "x": pl["x"], "y": pl["y"], "lank": pl["url"], "plan": bet})
    fn = set(fore.get("notiser", []))
    for n in nu["_notiser"]:
        if n["unid"] not in fn:
            ut.append({"typ": "notis", "rubrik": n["rubrik"], "text": n["text"] or "Staden har uppdaterat projektsidan.",
                       "datum": n["datum"], "lank": n["lank"], "dnr": n["dnr"]})
    for h in ut:
        h.setdefault("datum", idag)
    return ut


def iso(d):
    return f"{d[:4]}-{d[4:6]}-{d[6:8]}" if d and len(d) >= 8 else None


MAN = ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"]


def datum_text(d):
    i = iso(d)
    if not i:
        return "okänt datum"
    y, m, dd = i.split("-")
    return f"{int(dd)} {MAN[int(m) - 1]} {y}"


def koppla_lage(h, proj, dnr_till_unid):
    """Ger varje händelse en koordinat och en länk."""
    u = h.get("projekt") or dnr_till_unid.get(h.get("dnr", ""))
    if u and u in proj:
        p = proj[u]
        h["projekt"] = u
        h.setdefault("x", p["x"]); h.setdefault("y", p["y"])
        if not h.get("lank"):
            h["lank"] = p["lank"]
        if p.get("ungefar"):
            h["ungefar"] = True
        h.setdefault("fas", p["fas"])
    h.pop("dnr", None)
    h["id"] = hid(h["typ"], h.get("projekt") or h.get("plan") or h["rubrik"], h["datum"], h["text"])
    return h


def main():
    idag = dt.date.today().isoformat()
    try:
        fore = json.load(open(LAGE, encoding="utf-8"))
    except OSError:
        fore = None
    print("Hämtar planarbeten …")
    proj = hamta_projekt()
    print(f"  {len(proj)} publicerade planarbeten, {sum(1 for p in proj.values() if p['x'] is None)} utan läge")
    notiser = hamta_notiser()
    print(f"  {len(notiser)} notiser")
    print("Hämtar gällande planer …")
    planer = hamta_planer()
    print(f"  {len(planer)} planer")
    nu = {"hamtad": idag, "projekt": proj, "planer": planer, "_notiser": notiser}

    if fore is None:
        # Första körningen: inget tidigare läge att jämföra med. Gällande planer blir bara
        # utgångsläge, medan stadens notiser och pågående tider för synpunkter tas med bakåt i tiden
        # så att portalen har något att visa från början.
        fore = {"projekt": {u: dict(p, synpunkter=None) for u, p in proj.items()},
                "planer": planer, "notiser": []}
        print("Inget tidigare läge, bygger en första lista över händelser.")

    nya = handelser_fran(fore, nu, idag)
    dnr_till_unid = {dnr_nyckel(p["dnr"]): u for u, p in proj.items() if p["dnr"]}
    nya = [koppla_lage(h, proj, dnr_till_unid) for h in nya]

    try:
        gamla = json.load(open(UT_HAND, encoding="utf-8"))["h"]
    except OSError:
        gamla = []
    gräns = (dt.date.today() - dt.timedelta(days=SPARA_DAGAR)).isoformat()
    sett = {h["id"] for h in gamla}
    alla = gamla + [h for h in nya if h["id"] not in sett]
    alla = [h for h in alla if h["datum"] >= gräns]
    alla.sort(key=lambda h: (h["datum"], h["id"]), reverse=True)
    print(f"{len([h for h in nya if h['id'] not in sett])} nya händelser, {len(alla)} totalt")

    os.makedirs(os.path.dirname(LAGE), exist_ok=True)
    os.makedirs(os.path.dirname(UT_HAND), exist_ok=True)
    lage = {"hamtad": idag, "projekt": proj, "planer": sorted(planer), "notiser": sorted(n["unid"] for n in notiser)}
    with open(LAGE, "w", encoding="utf-8") as f:
        json.dump(lage, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    with open(UT_HAND, "w", encoding="utf-8") as f:
        json.dump({"uppdaterad": idag, "h": alla}, f, ensure_ascii=False, separators=(",", ":"))
    kol = ["namn", "slag", "steg", "fas", "x", "y", "lank", "synpunkter", "ungefar"]
    rader = [[p.get(k) for k in kol] for p in sorted(proj.values(), key=lambda p: p["namn"]) if p["x"] is not None]
    with open(UT_PROJ, "w", encoding="utf-8") as f:
        json.dump({"uppdaterad": idag, "faser": FASNAMN, "kol": kol, "p": rader}, f, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    main()
