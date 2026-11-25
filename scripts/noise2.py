import json,glob,numpy as np,shapely
from shapely.geometry import shape
a=json.load(open('out/adresser.json'));E0,N0=a['o']
xy=np.array([[r[1]+E0,r[2]+N0] for k,v in a['s'] for r in v],dtype=float);P=shapely.points(xy);n=len(xy)
res={}
for tag in ['leq','max']:
    seen={}
    for f in glob.glob(f'env/n_{tag}_*.json'):
        for x in json.load(open(f))['features']:
            if x.get('geometry') and x['id'] not in seen: seen[x['id']]=x
    fs=list(seen.values());bands=sorted({x['properties']['min'] for x in fs})
    t=shapely.STRtree([shape(x['geometry']) for x in fs]);ai,gi=t.query(P,predicate='dwithin',distance=25)
    lo=[None]*n;hi=[None]*n
    for i,g in zip(ai,gi):
        b=bands.index(fs[g]['properties']['min'])
        if hi[i] is None or b>hi[i]:hi[i]=b
        if lo[i] is None or b<lo[i]:lo[i]=b
    res[tag]=(lo,hi);print(tag,sum(h is not None for h in hi),flush=True)
json.dump(res,open('noise2.json','w'))
