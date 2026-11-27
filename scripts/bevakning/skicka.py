#!/usr/bin/env python3
"""Skickar mejl om nya händelser nära bevakade adresser.

Läser händelserna som hamta.py skrev (portal/bevakning/handelser.json) och listan över
bevakningar. Varje bevakning får ett mejl när något nytt har hänt inom dess radie.

Bevakningarna är en JSON-lista, antingen i miljövariabeln BEVAKNINGAR (en hemlighet i GitHub,
så att mejladresser aldrig hamnar i repot) eller i en fil som anges med --bevakningar:

    [{"mejl": "kopare@example.se", "adress": "Vildkaprifolen 5", "radie": 1000}]

"adress" skrivs som i portalens sökning (gata och nummer). "radie" är i meter, standard 1000.

Mejlen skickas med SMTP. Inställningar via miljövariabler:
    SMTP_HOST, SMTP_PORT (465 = SSL, 587 = STARTTLS), SMTP_USER, SMTP_PASSWORD, MAIL_FROM
    PORTAL_URL  (valfri) adressen där portalen ligger, för länkar i mejlet

Utan SMTP_HOST, eller med --torrkorning, skickas inget. Mejlen skrivs i stället som filer
under utskick/ så att de går att granska.

Vilka händelser som redan skickats sparas i bevakning/skickat.json. Där finns bara en
kontrollsumma per bevakning, inga mejladresser.
"""
import argparse
import datetime as dt
import hashlib
import html
import json
import math
import os
import smtplib
import ssl
import sys
import urllib.parse
from email.message import EmailMessage
from email.utils import formatdate, make_msgid

ROT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HANDELSER = os.path.join(ROT, "portal", "bevakning", "handelser.json")
PLANARBETE = os.path.join(ROT, "portal", "bevakning", "planarbete.json")
ADRESSER = os.path.join(ROT, "portal", "adresser.json")
SKICKAT = os.path.join(ROT, "bevakning", "skickat.json")
UTSKICK = os.path.join(ROT, "utskick")

TYPNAMN = {"nytt_planarbete": "Nytt planarbete", "nytt_skede": "Nytt skede", "synpunkter": "Öppet för synpunkter",
           "ny_plan": "Ny gällande plan", "notis": "Uppdatering från staden"}
AKTIVA = {"tidigt", "samrad", "granskning", "antagande", "overklagad", "bygge"}
MAN = ["januari", "februari", "mars", "april", "maj", "juni", "juli", "augusti", "september", "oktober", "november", "december"]


def datum_text(iso):
    y, m, d = iso.split("-")
    return f"{int(d)} {MAN[int(m) - 1]} {y}"


def fold(s):
    s = s.lower()
    for a, b in (("å", "a"), ("ä", "a"), ("ö", "o"), ("é", "e"), ("ü", "u")):
        s = s.replace(a, b)
    return " ".join("".join(c if c.isalnum() else " " for c in s).split())


def adressindex():
    a = json.load(open(ADRESSER, encoding="utf-8"))
    e0, n0 = a["o"]
    ut = {}
    k = 0
    for namn, rader in a["s"]:
        for r in rader:
            etikett = f"{namn} {r[0]}" if r[0] else namn
            ut[fold(etikett).replace(" ", "")] = (etikett, r[1] + e0, r[2] + n0, k)
            k += 1
    return ut


def avstand_text(m):
    if m < 1000:
        return f"{round(m / 10) * 10} m"
    return f"{m / 1000:.1f}".replace(".0", "").replace(".", ",") + " km"


def nyckel(b):
    return hashlib.sha256(f"{b['mejl'].strip().lower()}|{fold(b['adress'])}".encode()).hexdigest()[:16]


def bygg_mejl(b, adr, nya, aktiva, forsta, portal):
    etikett, _, _, k = adr
    radie = avstand_text(b["radie"])
    lank = f"{portal.rstrip('/')}/#a{k}-bevakning" if portal else ""
    if forsta:
        amne = f"Bevakningen av {etikett} är startad"
        intro = (f"Du bevakar nu {etikett} i Buyers Choice. Vi skickar ett mejl när staden startar ett nytt "
                 f"planarbete inom {radie}, när ett planarbete går vidare till samråd, granskning, antagande "
                 f"eller laga kraft, när det går att lämna synpunkter, eller när en ny detaljplan börjar gälla.")
    else:
        amne = f"{len(nya)} {'ny händelse' if len(nya) == 1 else 'nya händelser'} nära {etikett}"
        intro = f"Det här är nytt inom {radie} från {etikett} sedan förra mejlet."

    def rad_txt(h):
        s = f"- {TYPNAMN.get(h['typ'], 'Händelse')}, {datum_text(h['datum'])}, {avstand_text(h['m'])} bort: {h['rubrik']}\n  {h['text']}"
        return s + (f"\n  {h['lank']}" if h.get("lank") else "")

    def rad_html(h):
        rub = html.escape(h["rubrik"])
        if h.get("lank"):
            rub = f'<a href="{html.escape(h["lank"])}" style="color:#2F5D50">{rub}</a>'
        return (f'<tr><td style="padding:14px 0;border-bottom:1px solid #E9E4DA">'
                f'<div style="font-size:13px;color:#6B655C">{TYPNAMN.get(h["typ"], "Händelse")} · {datum_text(h["datum"])} · {avstand_text(h["m"])} bort</div>'
                f'<div style="font-weight:600;margin:2px 0">{rub}</div>'
                f'<div style="color:#1C1A17">{html.escape(h["text"])}</div></td></tr>')

    txt = [intro, ""]
    hdel = [f'<p>{html.escape(intro)}</p>']
    if nya:
        txt += [rad_txt(h) for h in nya] + [""]
        hdel.append('<table style="width:100%;border-collapse:collapse;border-top:1px solid #E9E4DA">' + "".join(rad_html(h) for h in nya) + "</table>")
    if forsta:
        if aktiva:
            txt.append(f"Pågående planarbete inom {radie} just nu:")
            txt += [f"- {p['namn']} ({p['skede']}, {avstand_text(p['m'])} bort)" for p in aktiva[:10]]
            txt.append("")
            hdel.append(f'<p style="margin-top:20px"><b>Pågående planarbete inom {radie} just nu</b></p><ul>' +
                        "".join(f'<li>{html.escape(p["namn"])} <span style="color:#6B655C">({html.escape(p["skede"])}, {avstand_text(p["m"])} bort)</span></li>' for p in aktiva[:10]) + "</ul>")
        else:
            txt += [f"Just nu pågår inget planarbete inom {radie} enligt stadens projektlista.", ""]
            hdel.append(f"<p>Just nu pågår inget planarbete inom {radie} enligt stadens projektlista.</p>")
    if lank:
        txt += [f"Se allt i portalen: {lank}", ""]
        hdel.append(f'<p><a href="{html.escape(lank)}" style="display:inline-block;background:#2F5D50;color:#fff;padding:10px 18px;border-radius:999px;text-decoration:none">Öppna bevakningen i portalen</a></p>')
    fot = ("Uppgifterna kommer från Göteborgs Stads lista över plan- och byggprojekt och stadens register över "
           "gällande planer. Bygglov ingår inte än. Svara på mejlet om du vill avsluta bevakningen.")
    txt.append(fot)
    hdel.append(f'<p style="font-size:13px;color:#6B655C;margin-top:24px">{html.escape(fot)}</p>')
    kropp = ('<div style="font-family:Inter,Arial,sans-serif;font-size:15px;line-height:1.55;color:#1C1A17;max-width:620px;margin:0 auto;padding:24px;background:#FCFBF8">'
             f'<div style="font-family:Fraunces,Georgia,serif;font-size:24px;margin-bottom:12px">{html.escape(amne)}</div>' + "".join(hdel) + "</div>")
    return amne, "\n".join(txt), kropp


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bevakningar", help="JSON-fil med bevakningar (annars miljövariabeln BEVAKNINGAR)")
    ap.add_argument("--torrkorning", action="store_true", help="skicka inget, skriv mejlen till utskick/")
    a = ap.parse_args()

    if a.bevakningar:
        bev = json.load(open(a.bevakningar, encoding="utf-8"))
    elif os.environ.get("BEVAKNINGAR", "").strip():
        bev = json.loads(os.environ["BEVAKNINGAR"])
    else:
        print("Inga bevakningar (sätt BEVAKNINGAR eller --bevakningar). Inget att skicka.")
        return
    torr = a.torrkorning or not os.environ.get("SMTP_HOST")
    portal = os.environ.get("PORTAL_URL", "")

    H = json.load(open(HANDELSER, encoding="utf-8"))["h"]
    P = json.load(open(PLANARBETE, encoding="utf-8"))
    kol = {k: i for i, k in enumerate(P["kol"])}
    A = adressindex()
    try:
        skickat = json.load(open(SKICKAT, encoding="utf-8"))
    except OSError:
        skickat = {}

    utkorg = []
    for b in bev:
        b.setdefault("radie", 1000)
        adr = A.get(fold(b.get("adress", "")).replace(" ", ""))
        if not adr or "@" not in b.get("mejl", ""):
            print(f"Hoppar över en bevakning: adressen '{b.get('adress')}' finns inte eller mejl saknas", file=sys.stderr)
            continue
        _, e, n, _ = adr
        nara = []
        for h in H:
            if h.get("x") is None:
                continue
            m = math.hypot(h["x"] - e, h["y"] - n)
            if m <= b["radie"]:
                nara.append(dict(h, m=m))
        nyc = nyckel(b)
        forsta = nyc not in skickat
        sett = set((skickat.get(nyc) or {}).get("id", []))
        nya = [] if forsta else [h for h in nara if h["id"] not in sett]
        aktiva = []
        if forsta:
            for r in P["p"]:
                if r[kol["fas"]] in AKTIVA:
                    m = math.hypot(r[kol["x"]] - e, r[kol["y"]] - n)
                    if m <= b["radie"]:
                        aktiva.append({"namn": r[kol["namn"]], "skede": P["faser"][r[kol["fas"]]], "m": m})
            aktiva.sort(key=lambda p: p["m"])
        if forsta or nya:
            amne, txt, kropp = bygg_mejl(b, adr, nya, aktiva, forsta, portal)
            utkorg.append((b["mejl"], amne, txt, kropp))
        skickat[nyc] = {"senast": dt.date.today().isoformat(), "id": sorted(sett | {h["id"] for h in nara})}

    if not utkorg:
        print("Inga nya händelser nära någon bevakad adress.")
    elif torr:
        os.makedirs(UTSKICK, exist_ok=True)
        for i, (_, amne, txt, kropp) in enumerate(utkorg, 1):
            with open(os.path.join(UTSKICK, f"{i:02d}.html"), "w", encoding="utf-8") as f:
                f.write(f"<!doctype html><meta charset=utf-8><title>{html.escape(amne)}</title>{kropp}")
            with open(os.path.join(UTSKICK, f"{i:02d}.txt"), "w", encoding="utf-8") as f:
                f.write(f"Ämne: {amne}\n\n{txt}\n")
        print(f"Torrkörning: {len(utkorg)} mejl skrivna till {os.path.relpath(UTSKICK, ROT)}/, inget skickat.")
    else:
        avs = os.environ.get("MAIL_FROM") or os.environ.get("SMTP_USER")
        port = int(os.environ.get("SMTP_PORT", "465"))
        ctx = ssl.create_default_context()
        if port == 465:
            s = smtplib.SMTP_SSL(os.environ["SMTP_HOST"], port, context=ctx, timeout=60)
        else:
            s = smtplib.SMTP(os.environ["SMTP_HOST"], port, timeout=60)
            s.starttls(context=ctx)
        with s:
            if os.environ.get("SMTP_USER"):
                s.login(os.environ["SMTP_USER"], os.environ.get("SMTP_PASSWORD", ""))
            for till, amne, txt, kropp in utkorg:
                msg = EmailMessage()
                msg["From"], msg["To"], msg["Subject"] = avs, till, amne
                msg["Date"], msg["Message-ID"] = formatdate(localtime=True), make_msgid(domain=avs.split("@")[-1])
                msg.set_content(txt)
                msg.add_alternative(kropp, subtype="html")
                s.send_message(msg)
        print(f"Skickade {len(utkorg)} mejl.")

    if not torr:
        with open(SKICKAT, "w", encoding="utf-8") as f:
            json.dump(skickat, f, ensure_ascii=False, indent=0, sort_keys=True)
    else:
        print("Torrkörning: bevakning/skickat.json lämnas orörd.")


if __name__ == "__main__":
    main()
