"""Lägger till linjer per hållplats i portal/service.json.

Källa: Trafikkontoret Göteborg, öppen WFS (vt:alla_linjer), hämtad med
  curl "https://open.geodata.tkgbg.se/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=vt:alla_linjer&outputFormat=application/json&srsName=EPSG:3007" -o /tmp/geo/linjer.json

En linje räknas till en hållplats om linjens sträckning går inom MAXD meter från hållplatsens läge.
Det är sträckningen som jämförs, inte tidtabellen, så en snabblinje som kör förbi utan att stanna
kan komma med. Portalen säger det i källtexten.

Skriver: service.json får nyckeln "lines" = [[kortnamn, typ, beskrivning], ...] och varje hållplats
får ett fjärde fält med index i den listan.
"""
import json, re, sys
import shapely
from shapely.geometry import shape

MAXD = 45
SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/geo/linjer.json"
OUT = sys.argv[2] if len(sys.argv) > 2 else "portal/service.json"

TYP = {"Spårvagn": "Spårvagn", "Buss": "Buss", "Stombuss": "Buss", "Högtrafiklinje": "Buss",
       "Expressbuss": "Buss", "Båt": "Båt", "TÅG": "Tåg", "FLYGBUSS": "Flygbuss"}


def kort(p):
    e, b = p.get("Egenskap") or "", (p.get("Beskrivning") or "").strip()
    if e in ("TÅG", "FLYGBUSS"):
        rest = re.sub(r"^(TÅG|FLYG)\s+", "", b)
        return ("Tåg" if e == "TÅG" else "Flyg"), rest
    m = re.match(r"(\S+)\s+(.*)", b)
    if not m:
        return b, ""
    k = m.group(1)
    k = {"SVAR": "SVART"}.get(k, k)
    return k, m.group(2)


feats = json.load(open(SRC, encoding="utf-8"))["features"]
lines, idx, geoms, gidx = [], {}, [], []
for f in feats:
    p = f["properties"]
    if not f.get("geometry"):
        continue
    k, rest = kort(p)
    t = TYP.get(p.get("Egenskap") or "", "Buss")
    key = (k, t)
    if key not in idx:
        idx[key] = len(lines)
        lines.append([k, t, "Pendel- och regiontåg" if t == "Tåg" else re.sub(r"\s+-\s+", "–", rest)])
    geoms.append(shape(f["geometry"]))
    gidx.append(idx[key])

svc = json.load(open(OUT, encoding="utf-8"))
tree = shapely.STRtree(geoms)
n_with = 0
for s in svc["stops"]:
    pt = shapely.Point(s[1], s[2])
    hit = sorted({gidx[i] for i in tree.query(pt, predicate="dwithin", distance=MAXD)})
    del s[3:]
    s.append(hit)
    n_with += bool(hit)
svc["lines"] = lines
json.dump(svc, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("linjer", len(lines), "hållplatser", len(svc["stops"]), "med linjer", n_with)
