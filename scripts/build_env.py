import json, glob, collections, math
import numpy as np, shapely, tifffile
from shapely.geometry import shape
E = '/tmp/geo/env/'; O = '/tmp/geo/out/'
a = json.load(open(O + 'adresser.json')); E0, N0 = a['o']
xy = np.array([[r[1] + E0, r[2] + N0] for k, v in a['s'] for r in v], dtype=float)
P = shapely.points(xy); n = len(xy); print(n, flush=True)

def load(files):
    seen = {};
    for f in files:
        try: fs = json.load(open(f))['features']
        except Exception: continue
        for x in fs:
            if x.get('geometry') and x['id'] not in seen: seen[x['id']] = x
    return list(seen.values())

def band_at(feats):
    geoms = [shape(f['geometry']) for f in feats]; vals = [f['properties'].get('min') for f in feats]
    t = shapely.STRtree(geoms); ai, gi = t.query(P, predicate='intersects')
    out = [None] * n
    for i, g in zip(ai, gi):
        v = vals[g]
        if v is not None and (out[i] is None or v > out[i]): out[i] = v
    return out, sorted({(f['properties'].get('min'), f['properties'].get('max')) for f in feats})

leq, leqb = band_at(load(glob.glob(E + 'n_leq_*.json'))); print('leq bands', leqb, flush=True)
lmax, maxb = band_at(load(glob.glob(E + 'n_max_*.json'))); print('max bands', maxb, flush=True)

def raster(f, E0r, Nt, s, scale):
    r = tifffile.imread(f); out = []
    for x, y in xy:
        i, j = int((Nt - y) / s), int((x - E0r) / s)
        v = r[i, j] if 0 <= i < r.shape[0] and 0 <= j < r.shape[1] else 0
        out.append(int(round(float(v) * scale)) if v and v > 0 else None)
    return out
no2 = raster(E + 'miljoovervakning_luft_v1__RS_NO2_2023_year.tif', 124455.0, 6416366.9507, 15.625, 1)
pm10 = raster(E + 'miljoovervakning_luft_v1__RS_PM10_2023_year_new_gbg.tif', 127658.0, 6416128.0, 50.0, 10)

def layer(name):
    fs = json.load(open(E + name))['features']; return [f for f in fs if f.get('geometry')]
rad = layer('op_op_radon.json'); RADT = sorted({f['properties']['objekt_typ'] for f in rad})
t = shapely.STRtree([shape(f['geometry']) for f in rad]); ai, gi = t.query(P, predicate='intersects')
radon = [None] * n
for i, g in zip(ai, gi): radon[i] = RADT.index(rad[g]['properties']['objekt_typ'])

def dist(name, cap):
    fs = layer(name); geoms = [shape(f['geometry']) for f in fs]; t = shapely.STRtree(geoms)
    idx, d = t.query_nearest(P, max_distance=cap, return_distance=True, all_matches=False)
    out = [None] * n
    for (i, g), dd in zip(idx.T, d): out[i] = int(round(dd / 10) * 10) if dd > 0 else 0
    return out
sky = dist('op_op_skyfall_hansyn.json', 1000)
flood = dist('op_op_risk_oversvamning_hoga_vattenstand_hansyn.json', 2000)
foro = dist('op_ttop_riskomraden_fororenade_omraden.json', 1000)
flyg = dist('op_op_omrade_med_tillstand_for_flyg_hansyn.json', 2000)
fm = dist('op_op_ri_gbg_fm_paverkansomrade_for_buller_eller_annan_risk.json', 2000)
fg = dist('op_op_farligt_gods_hansyn.json', 500)

# framtida enligt översiktsplanen
FP = []; fgeoms = []
for f in sorted(glob.glob(E + 'fp_*.json')):
    lay = f.split('fp_')[1][:-5]
    for x in json.load(open(f))['features']:
        if not x.get('geometry'): continue
        p = x['properties']; g = shape(x['geometry'])
        gs = g.simplify(8, preserve_topology=True)
        FP.append({'l': lay, 'n': (p.get('objekt_namn') or '').strip(), 't': (p.get('objekt_typ') or '').strip(), 'k': (p.get('underkategori_2') or '').strip(),
                   'r': (p.get('rekommendation') or '').strip(), 'b': (p.get('objekt_beskrivning') or '').strip(),
                   'g': shapely.geometry.mapping(shapely.transform(gs, lambda c: np.round(c)))})
        fgeoms.append(g)
t = shapely.STRtree(fgeoms)
near = [[] for _ in range(n)]
ai, gi = t.query(P, predicate='dwithin', distance=1500)
for i, g in zip(ai, gi): near[i].append((int(round(shapely.distance(P[i], fgeoms[g]) / 10) * 10), int(g)))
for l in near: l.sort()
json.dump({'src': 'Göteborgs Stad, översiktsplan (oversiktsplan-v4), hämtad 2026-11-25', 'f': FP}, open(O + 'framtid.json', 'w'), ensure_ascii=False, separators=(',', ':'))

LEQB = [list(b) for b in leqb]; MAXB = [list(b) for b in maxb]
def bi(v, bands):
    if v is None: return -1
    for k, b in enumerate(bands):
        if b[0] == v: return k
    return -1
rows = []
for i in range(n):
    rows.append([bi(leq[i], leqb), bi(lmax[i], maxb), no2[i], pm10[i], radon[i] if radon[i] is not None else -1,
                 sky[i], flood[i], foro[i], flyg[i], fm[i], fg[i], [x for d, g in near[i][:8] for x in (g, d)]])
json.dump({'leqb': LEQB, 'maxb': MAXB, 'radon': RADT, 'cols': ['leq', 'lmax', 'no2', 'pm10x10', 'radon', 'skyfall_m', 'oversvamning_m', 'fororenat_m', 'flyg_m', 'fm_m', 'farligt_gods_m', 'framtid'], 'r': rows},
          open(O + 'miljo.json', 'w'), separators=(',', ':'))
k = [i for i in range(n)]
print('done', sum(x is not None for x in leq), sum(x is not None for x in no2), sum(x is not None for x in radon), flush=True)
