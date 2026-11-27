#!/usr/bin/env python3
"""Hämtar stadens pågående planarbeten och skriver portal/planarbete.json.

Portalen visar dem i grundrapporten under Planer i området, med avstånd från adressen och skede.

Källa (öppen, utan nyckel): stadens databas för plan- och byggprojekt, samma som visar
projektsidorna på goteborg.se (www5.goteborg.se/prod/fastighetskontoret/etjanst/planobygg.nsf).

Logiken är densamma som i bevakningens hämtningsskript (scripts/bevakning/hamta.py) och filen
har samma format som portal/bevakning/planarbete.json. Finns bevakningens fil, som uppdateras
varje dag, läser portalen den i första hand och den här filen annars.

Kör från repots rot:  python3 scripts/build_planarbete.py
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

ROT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UT_PROJ = os.path.join(ROT, "portal", "planarbete.json")
ADRESSER = os.path.join(ROT, "portal", "adresser.json")

PLANOBYGG = "https://www5.goteborg.se/prod/fastighetskontoret/etjanst/planobygg.nsf"
PROJEKTSIDA = "https://goteborg.se/wps/portal?uri=gbglnk:gbg.page.bb7386fd-1152-47cb-9da4-d06bd7780a77&projektid="
UA = {"User-Agent": "buyers-choice/1.0"}



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



def main():
    idag = dt.date.today().isoformat()
    proj = hamta_projekt()
    kol = ["namn", "slag", "steg", "fas", "x", "y", "lank", "synpunkter", "ungefar"]
    rader = [[p.get(k) for k in kol] for p in sorted(proj.values(), key=lambda p: p["namn"]) if p["x"] is not None]
    with open(UT_PROJ, "w", encoding="utf-8") as f:
        json.dump({"uppdaterad": idag, "faser": FASNAMN, "kol": kol, "p": rader}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(proj)} publicerade planarbeten, {len(rader)} med läge")


if __name__ == "__main__":
    main()
