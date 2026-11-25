import json, threading, time, urllib.request, collections, sys
from concurrent.futures import ThreadPoolExecutor
from shapely.geometry import shape, Point
W = "https://geodata-external.sbk.goteborg.se/services/sbf-extern-fastighetsgrans-v1/wms"
a = json.load(open('/tmp/geo/out/adresser.json')); E0, N0 = a['o']
pts = []
for name, rows in a['s']:
    for r in rows: pts.append((r[1] + E0, r[2] + N0))
print(len(pts), flush=True)
lock = threading.Lock()
polys = {}  # id -> (geom, props)
grid = collections.defaultdict(set)
G = 100
def cellkeys(b):
    for i in range(int(b[0] // G), int(b[2] // G) + 1):
        for j in range(int(b[1] // G), int(b[3] // G) + 1):
            yield (i, j)
def lookup(x, y):
    p = Point(x, y)
    for fid in list(grid.get((int(x // G), int(y // G)), ())):
        g, pr = polys[fid]
        if g.contains(p): return fid
    return None
def query(x, y):
    url = (f"{W}?service=WMS&version=1.1.1&request=GetFeatureInfo&layers=fastighetsgrans&query_layers=fastighetsgrans"
           f"&srs=EPSG:3007&bbox={x-50},{y-50},{x+50},{y+50}&width=101&height=101&x=50&y=50&info_format=application/json&feature_count=50")
    for t in range(4):
        try:
            with urllib.request.urlopen(url, timeout=60) as r: return json.load(r)['features']
        except Exception as e:
            time.sleep(2 + 3 * t)
    return []
res = [None] * len(pts)
order = sorted(range(len(pts)), key=lambda i: (int(pts[i][0] // 400), int(pts[i][1] // 400), pts[i]))
chunks = collections.defaultdict(list)
for i in order: chunks[(int(pts[i][0] // 400), int(pts[i][1] // 400))].append(i)
nq = [0]
def work(idxs):
    for i in idxs:
        x, y = pts[i]
        with lock: fid = lookup(x, y)
        if fid is None:
            feats = query(x, y)
            with lock:
                nq[0] += 1
                for f in feats:
                    fid2 = f.get('id')
                    if fid2 in polys or not f.get('geometry'): continue
                    try: g = shape(f['geometry'])
                    except Exception: continue
                    pr = f['properties']
                    polys[fid2] = (g, (pr.get('fastighet'), round(g.area)))
                    for k in cellkeys(g.bounds): grid[k].add(fid2)
                fid = lookup(x, y)
        res[i] = fid
with ThreadPoolExecutor(12) as ex:
    futs = [ex.submit(work, c) for c in chunks.values()]
    t0 = time.time()
    while not all(f.done() for f in futs):
        time.sleep(30); print(time.time() - t0, nq[0], sum(r is not None for r in res), flush=True)
for f in futs: f.result()
out = [(polys[f][1] if f else None) for f in res]
json.dump(out, open('/tmp/geo/out_fast.json', 'w'), ensure_ascii=False)
print('done', nq[0], sum(o is not None for o in out), flush=True)
