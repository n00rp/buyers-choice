"""Bygger portalens datafiler för Partille kommun.

Steg 1 (hämtning): python3 scripts/kommun_partille.py hamta
    Laddar ned rådata från Partille kommuns öppna ArcGIS-tjänster och
    Skolverkets skolenhetsregister till /tmp/geo/partille/.
Steg 2 (bygge):    python3 scripts/kommun_partille.py bygg
    Räknar fram per adress och skriver portal/k/partille/.

Allt ligger i SWEREF 99 12 00 (EPSG:3007), samma som Göteborg.
Beroenden: numpy, shapely, pyproj.
"""
import collections, glob, json, os, re, sys, urllib.parse, urllib.request
from datetime import datetime, timezone, timedelta

RAW = '/tmp/geo/partille/'
OUT = os.path.join(os.path.dirname(__file__), '..', 'portal', 'k', 'partille') + '/'
GBG = os.path.join(os.path.dirname(__file__), '..', 'portal') + '/'
ARC = 'https://geodata.partille.se/arcgis/rest/services/'
SKV = 'https://api.skolverket.se/skolenhetsregistret/v2/school-units'
KOMMUNKOD = '1402'


def arc(service, layer, out, fields='*', page=1000):
    feats, off = [], 0
    while True:
        q = urllib.parse.urlencode({'where': '1=1', 'outFields': fields, 'f': 'geojson', 'outSR': 3007,
                                    'resultOffset': off, 'resultRecordCount': page, 'orderByFields': 'OBJECTID' if fields == '*' else 'ID'})
        d = json.load(urllib.request.urlopen(f'{ARC}{service}/MapServer/{layer}/query?{q}', timeout=180))
        f = d.get('features', [])
        feats += f
        off += len(f)
        if len(f) < page:
            break
    json.dump({'type': 'FeatureCollection', 'features': feats}, open(RAW + out, 'w'), ensure_ascii=False)
    print(out, len(feats))


def hamta():
    os.makedirs(RAW + 'su', exist_ok=True)
    arc('adresser', 0, 'adr.json')
    arc('gallande_detaljplaner_', 0, 'plan.json')
    arc('forskolor_publik', 0, 'forskolor.json')
    arc('samhallsbyggnadsprojekt_publik', 9, 'projekt.json')
    arc('geotekniska_utredningar_publik', 1, 'geoteknik.json')
    arc('fastighetsgranser', 0, 'fast.json', fields='FASTIGHET,DETALJTYP,TOTALAREAL_FASTIGHET', page=2000)
    # vägnätet i kommunens bakgrundskarta (lager 36, väglinjer i största skala)
    arc('bakgrundskarta_farg_wms', 36, 'vagar.json', fields='Id,Objekttyp,Gatunamn', page=2000)
    d = json.load(urllib.request.urlopen(f'{SKV}?municipality_code={KOMMUNKOD}', timeout=60))
    for u in d['data']['attributes']:
        if u['status'] != 'AKTIV':
            continue
        c = u['schoolUnitCode']
        open(f'{RAW}su/{c}.json', 'wb').write(urllib.request.urlopen(f'{SKV}/{c}', timeout=60).read())


# Partilles plantyper översatta till de typer portalen redan förklarar
PLANTYP = {'Detaljplan': 'Detaljplan', 'Detljplan': 'Detaljplan', 'Enkel detaljplan': 'Enkelt planförfarande',
           'Detaljplan (ändr)': 'Detaljplan ändring', 'Ändring av detaljpla': 'Detaljplan ändring',
           'Stadsplan': 'Stadsplan', 'Byggnadsplan': 'Byggnadsplan', 'Avstyckningsplan': 'Avstyckningsplan',
           'Områdesbestämmelser': 'Områdesbestämmelse', 'Bestämmelser': 'Bestämmelser', 'Gatuhöjder': 'Gatuhöjder'}
# stöddokument, inte planbeslut
SKIP = {'Gestaltningsprogram'}


def ms_date(v):
    if v is None:
        return ''
    return (datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(milliseconds=v)).strftime('%Y-%m-%d')


def bygg():
    import numpy as np, shapely
    from shapely.geometry import shape, Point
    from pyproj import Transformer
    os.makedirs(OUT + 'm', exist_ok=True)

    # adresser
    adr = []
    for f in json.load(open(RAW + 'adr.json'))['features']:
        p = f['properties']
        x, y = f['geometry']['coordinates'][:2]
        adr.append((p['ADRESSOMRADE'].strip(), (p['ADRESSPLATS'] or '').strip(), round(x), round(y), p['POSTORT']))
    pts = shapely.points(np.array([[a[2], a[3]] for a in adr], dtype=float))

    # detaljplaner, en rad per plannummer
    plans, geoms, pkey = [], [], {}
    for f in json.load(open(RAW + 'plan.json'))['features']:
        p = f['properties']
        if not f.get('geometry') or p['plantyp'] in SKIP:
            continue
        k = p['plannr']
        if k not in pkey:
            pkey[k] = len(plans)
            plans.append(p)
        geoms.append((pkey[k], shape(f['geometry'])))
    tree = shapely.STRtree([g for _, g in geoms])
    ai, gi = tree.query(pts, predicate='intersects')
    cov = collections.defaultdict(set)
    for a, g in zip(ai, gi):
        cov[int(a)].add(geoms[int(g)][0])
    used = sorted({g for v in cov.values() for g in v})
    remap = {g: i for i, g in enumerate(used)}
    ptab = []
    for g in used:
        p = plans[g]
        # [beteckning, typ, namn, plankarta, planbeskrivning, laga kraft]
        ptab.append([p['plannr'], PLANTYP.get(p['plantyp'], p['plantyp']), (p['plannamn'] or '').strip(),
                     p.get('plankarta') or '', p.get('planbeskrivning') or '', ms_date(p.get('lagakraft'))])

    E0 = min(a[2] for a in adr)
    N0 = min(a[3] for a in adr)
    streets = collections.OrderedDict()
    order = sorted(enumerate(adr), key=lambda t: (t[1][0].lower(), int(re.match(r'\d*', t[1][1]).group() or 0), t[1][1]))
    for i, a in order:
        streets.setdefault(a[0], []).append((i, [a[1], a[2] - E0, a[3] - N0] + sorted(remap[g] for g in cov.get(i, []))))
    # adressernas ordning i filen styr radnumren i m/
    seq = [i for rows in streets.values() for i, _ in rows]
    s_out = []
    for name, rows in streets.items():
        po = collections.Counter(adr[i][4] for i, _ in rows).most_common(1)[0][0]
        s_out.append([name, [r for _, r in rows], po])
    json.dump({'o': [E0, N0], 's': s_out}, open(OUT + 'adresser.json', 'w'), ensure_ascii=False, separators=(',', ':'))
    json.dump({'pfx': '', 'p': ptab}, open(OUT + 'planer.json', 'w'), ensure_ascii=False, separators=(',', ':'))
    print('adresser', len(adr), 'i plan', len(cov), 'planer', len(ptab))

    # fastigheter
    fast = [(f['properties'], shape(f['geometry'])) for f in json.load(open(RAW + 'fast.json'))['features'] if f.get('geometry')]
    ftree = shapely.STRtree([g for _, g in fast])
    fi_a, fi_g = ftree.query(pts, predicate='intersects')
    fmap = {}
    for a, g in zip(fi_a, fi_g):
        p, geom = fast[int(g)]
        if int(a) not in fmap or p.get('DETALJTYP') == 'fastighetsområde':
            fmap[int(a)] = (p.get('FASTIGHET'), round(geom.area))

    # geotekniska utredningar: närmaste, år och antal inom 250 m
    geo = [(f['properties'], shape(f['geometry'])) for f in json.load(open(RAW + 'geoteknik.json'))['features'] if f.get('geometry')]
    gtree = shapely.STRtree([g for _, g in geo])

    # samhällsbyggnadsprojekt -> framtid.json
    proj = []
    for f in json.load(open(RAW + 'projekt.json'))['features']:
        p = f['properties']
        if p.get('Synligt_externt') != 'Ja' or not f.get('geometry'):
            continue
        g = shape(f['geometry'])
        proj.append((p, g))
    fut = []
    for p, g in proj:
        gs = g.simplify(2)
        fut.append({'n': p['Namn'], 'k': 'Samhällsbyggnadsprojekt', 't': p.get('Status') or '',
                    'b': ('Genomförande ' + p['Tidsplan_genomforande']) if p.get('Tidsplan_genomforande') else '',
                    'a': {'trafik': 'trafik', 'va': 'vatten och avlopp'}.get(p.get('Enhet_ansvarig'), p.get('Enhet_ansvarig') or ''),
                    'g': json.loads(json.dumps(shapely.geometry.mapping(gs), default=list), parse_float=lambda s: round(float(s)))})
    json.dump({'src': 'Partille kommun, kartlagret samhällsbyggnadsprojekt (geodata.partille.se), hämtat 2026-11-27',
               'url': 'https://geodata.partille.se/portal/apps/experiencebuilder/experience/?id=474d7df7acca4470aa21f7092a467c70',
               'f': fut}, open(OUT + 'framtid.json', 'w'), ensure_ascii=False, separators=(',', ':'))

    rows = []
    for i in seq:
        x, y = adr[i][2], adr[i][3]
        pt = Point(x, y)
        fids = []
        for j, (p, g) in enumerate(proj):
            d = round(g.distance(pt))
            if d <= 1500:
                fids += [j, d]
        # [antal utredningar som täcker punkten, senaste år, äldsta år] eller [0, avstånd till närmaste inom 250 m]
        cover = gtree.query(pt, predicate='intersects')
        if len(cover):
            yrs = sorted(ms_date(geo[int(j)][0].get('ar'))[:4] for j in cover if geo[int(j)][0].get('ar') is not None)
            gt = [len(cover), yrs[-1] if yrs else None, yrs[0] if yrs else None]
        else:
            near = gtree.query(pt.buffer(250), predicate='intersects')
            gt = [0, min(round(geo[int(j)][1].distance(pt)) for j in near)] if len(near) else [0, None]
        fa = fmap.get(i)
        # samma kolumner som Göteborg; det som saknas i Partilles öppna data är -1 eller null
        rows.append([-1, -1, None, None, -1, None, None, None, None, None, None, fids,
                     fa[0] if fa else None, fa[1] if fa else None, -1, -1, gt])
    B = 5000
    for s in range(0, len(rows), B):
        json.dump(rows[s:s + B], open(f'{OUT}m/{s // B}.json', 'w'), ensure_ascii=False, separators=(',', ':'))
    gm = json.load(open(GBG + 'miljo-meta.json'))
    meta = {k: gm[k] for k in ('leqb', 'maxb', 'radon')}
    meta.update({'cols': gm['cols'] + ['geoteknik'], 'block': B})
    json.dump(meta, open(OUT + 'miljo-meta.json', 'w'), ensure_ascii=False)
    print('fastighet', sum(1 for r in rows if r[12]), 'geoteknik', sum(1 for r in rows if r[16]))

    # närservice: skolor från Skolverket, förskolor från kommunen.
    # Göteborgs skolor och förskolor nära gränsen tas med, eftersom de ligger lika nära för många adresser.
    T = Transformer.from_crs(4326, 3007, always_xy=True)
    schools = []
    for fn in glob.glob(RAW + 'su/*.json'):
        a = json.load(open(fn))['data']['attributes']
        ad = [x for x in a.get('addresses', []) if x.get('type') == 'BESOKSADRESS' and x.get('geoCoordinates')]
        if a.get('status') != 'AKTIV' or not ad:
            continue
        g = ad[0]['geoCoordinates']
        x, y = T.transform(float(g['longitude']), float(g['latitude']))
        tp = a.get('schoolTypes') or []
        stp = a.get('schoolTypeProperties') or {}
        grades = (stp.get('gr') or stp.get('grs') or {}).get('grades') or []
        kind = 'gy' if ('GY' in tp or 'GYS' in tp) and 'GR' not in tp and 'GRS' not in tp else ('gr' if ('GR' in tp or 'GRS' in tp or 'FKLASS' in tp) else 'ovr')
        if kind == 'ovr':
            continue
        schools.append([a.get('displayName') or a.get('schoolName'), round(x), round(y), kind,
                        (('F–' + grades[-1]) if 'FKLASS' in tp and grades else (grades[0] + '–' + grades[-1] if grades else '')),
                        ad[0].get('streetAddress', ''), fn.split('/')[-1][:-5], 1 if 'GRS' in tp or 'GYS' in tp else 0])
    pre = []
    for f in json.load(open(RAW + 'forskolor.json'))['features']:
        p = f['properties']
        x, y = f['geometry']['coordinates'][:2]
        pre.append([p['namn'], round(x), round(y), (p.get('besoksadress') or '').split(',')[0], '', p.get('driftsform') or ''])
    xs = [a[2] for a in adr]
    ys = [a[3] for a in adr]
    bb = (min(xs) - 2500, min(ys) - 2500, max(xs) + 2500, max(ys) + 2500)
    inb = lambda r: bb[0] <= r[1] <= bb[2] and bb[1] <= r[2] <= bb[3]
    g = json.load(open(GBG + 'service.json'))
    own = {s[6] for s in schools}
    schools += [s + ['Göteborg'] for s in g['schools'] if inb(s) and s[6] not in own]
    pre += [[p[0], p[1], p[2], p[3], p[4], '', 'Göteborg'] for p in g['pre'] if inb(p)]
    json.dump({'stops': [], 'schools': schools, 'pre': pre, 'shops': [], 'pharm': []},
              open(OUT + 'service.json', 'w'), ensure_ascii=False, separators=(',', ':'))
    print('skolor', len(schools), 'förskolor', len(pre))
    vagar()


# vägtyper som ritas som huvudväg; övriga bilvägar ritas som lokalgator
HUVUDVAG = {'Motorväg', 'Motortrafikled', 'Huvudgata', 'Landsväg', 'Landsväg liten', 'Övergripande länk', 'Infartsväg/Utfartsväg'}


def vagar():
    """Delar Partilles vägnät i rutor i samma rutnät som Göteborgs (portal/roads-meta.json),
    så att kartan kan rita båda kommunernas vägar nära gränsen."""
    from shapely.geometry import shape, box
    gm = json.load(open(GBG + 'roads-meta.json'))
    T, X0, Y0 = gm['T'], gm['X0'], gm['Y0']
    tiles = collections.defaultdict(list)
    names = collections.defaultdict(dict)
    for x in json.load(open(RAW + 'vagar.json'))['features']:
        if not x.get('geometry'):
            continue
        p = x['properties']
        g = shape(x['geometry']).simplify(1.5)
        c = 0 if p.get('Objekttyp') in HUVUDVAG else 1
        nm = (p.get('Gatunamn') or '').strip()
        b = g.bounds
        for i in range(int((b[0] - X0) // T), int((b[2] - X0) // T) + 1):
            for j in range(int((b[1] - Y0) // T), int((b[3] - Y0) // T) + 1):
                tx, ty = X0 + i * T, Y0 + j * T
                part = g.intersection(box(tx - 20, ty - 20, tx + T + 20, ty + T + 20))
                if part.is_empty:
                    continue
                lines = [part] if part.geom_type == 'LineString' else [q for q in getattr(part, 'geoms', []) if q.geom_type == 'LineString']
                nd = names[(i, j)]
                ni = nd.setdefault(nm, len(nd)) if nm else -1
                for L in lines:
                    cs = [v for xy in L.coords for v in (round(xy[0] - tx), round(xy[1] - ty))]
                    if len(cs) >= 4:
                        tiles[(i, j)].append([c, ni] + cs)
    os.makedirs(OUT + 'r', exist_ok=True)
    for (i, j), ls in tiles.items():
        nd = names[(i, j)]
        nl = [None] * len(nd)
        for k, v in nd.items():
            nl[v] = k
        json.dump({'n': nl, 'l': ls}, open(f'{OUT}r/{i}_{j}.json', 'w'), ensure_ascii=False, separators=(',', ':'))
    json.dump({'T': T, 'X0': X0, 'Y0': Y0, 'tiles': sorted(f'{i}_{j}' for i, j in tiles)}, open(OUT + 'roads-meta.json', 'w'))
    print('vägrutor', len(tiles))


if __name__ == '__main__':
    {'hamta': hamta, 'bygg': bygg, 'vagar': vagar}[sys.argv[1] if len(sys.argv) > 1 else 'bygg']()
