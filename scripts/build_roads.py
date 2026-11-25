import json,glob,collections,os
from shapely.geometry import shape, box
import shapely
T=2500; bb=json.load(open('env/bbox.json')); X0=int(bb[0]//T*T); Y0=int(bb[1]//T*T)
tiles=collections.defaultdict(list); names=collections.defaultdict(dict)
def cls(p):
    n=p.get('vagtrafiknat') or ''
    if 'bil' in n:
        k=(p.get('vagklass') or '9').split(',')[0]
        return 0 if k in '012345' and k!='' else 1
    return 2
for f in glob.glob('env/road*.json'):
    for x in json.load(open(f))['features']:
        if not x.get('geometry'): continue
        g=shape(x['geometry']).simplify(1.5)
        c=cls(x['properties']); nm=x['properties'].get('gatunamn') or ''
        b=g.bounds
        for i in range(int((b[0]-X0)//T),int((b[2]-X0)//T)+1):
            for j in range(int((b[1]-Y0)//T),int((b[3]-Y0)//T)+1):
                tx,ty=X0+i*T,Y0+j*T
                part=g.intersection(box(tx-20,ty-20,tx+T+20,ty+T+20))
                if part.is_empty: continue
                lines=[part] if part.geom_type=='LineString' else [p for p in getattr(part,'geoms',[]) if p.geom_type=='LineString']
                nd=names[(i,j)]
                ni=nd.setdefault(nm,len(nd)) if nm else -1
                for L in lines:
                    cs=[v for xy in L.coords for v in (round(xy[0]-tx),round(xy[1]-ty))]
                    if len(cs)>=4: tiles[(i,j)].append([c,ni]+cs)
os.makedirs('out/r',exist_ok=True)
for (i,j),ls in tiles.items():
    nd=names[(i,j)];nl=[None]*len(nd)
    for k,v in nd.items(): nl[v]=k
    json.dump({'n':nl,'l':ls},open(f'out/r/{i}_{j}.json','w'),ensure_ascii=False,separators=(',',':'))
json.dump({'T':T,'X0':X0,'Y0':Y0,'tiles':sorted(f'{i}_{j}' for i,j in tiles)},open('out/roads-meta.json','w'))
print(len(tiles))
