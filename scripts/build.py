import json,glob,collections,re
import numpy as np, shapely
from shapely.geometry import shape
from pyproj import Transformer
A='/tmp/geo/all/'; S='/tmp/geo/svc/'; O='/tmp/geo/out/'
adr=[]
for i in range(6):
    for f in json.load(open(f'{A}adr{i}.json'))['features']:
        p=f['properties']; x,y=f['geometry']['coordinates'][:2]
        adr.append((p['gatunamn'] or p['adress'], p['nr_littera'] or '', round(x), round(y), p['adress']))
plans=[];geoms=[]
for i in range(4):
    for f in json.load(open(f'{A}pl{i}.json')).get('features',[]):
        if not f.get('geometry'): continue
        p=f['properties']; plans.append(p); geoms.append(shape(f['geometry']))
print(len(adr),len(plans))
tree=shapely.STRtree(geoms)
pts=shapely.points(np.array([[a[2],a[3]] for a in adr],dtype=float))
ai,gi=tree.query(pts,predicate='intersects')
cov=collections.defaultdict(list)
for a,g in zip(ai,gi): cov[int(a)].append(int(g))
used=sorted({g for v in cov.values() for g in v}); remap={g:i for i,g in enumerate(used)}
PFX='https://geodata-external.sbk.goteborg.se/dokument/'
ptab=[]
for g in used:
    p=plans[g]; u=p.get('url') or ''
    ptab.append([p.get('beteckning') or '', p.get('typ') or '', (p.get('beskrivning') or '').strip(), u[len(PFX):] if u.startswith(PFX) else u])
E0=min(a[2] for a in adr); N0=min(a[3] for a in adr)
streets=collections.OrderedDict()
for i,a in sorted(enumerate(adr),key=lambda t:(t[1][0].lower(),int(re.match(r'\d*',t[1][1]).group() or 0),t[1][1])):
    streets.setdefault(a[0],[]).append([a[1],a[2]-E0,a[3]-N0]+[remap[g] for g in cov.get(i,[])])
json.dump({'o':[E0,N0],'s':[[k,v] for k,v in streets.items()]},open(O+'adresser.json','w'),ensure_ascii=False,separators=(',',':'))
json.dump({'pfx':PFX,'p':ptab},open(O+'planer.json','w'),ensure_ascii=False,separators=(',',':'))
print('covered',len(cov),'plans used',len(used),'streets',len(streets))
# services
T=Transformer.from_crs(4326,3007,always_xy=True)
st=collections.defaultdict(list)
for f in json.load(open(S+'hpl.json'))['features']:
    p=f['properties']; st[p['namn']].append((float(p['x_sweref']),float(p['y_sweref'])))
stops=[[n,round(sum(x for x,_ in v)/len(v)),round(sum(y for _,y in v)/len(v))] for n,v in st.items()]
schools=[]
for fn in glob.glob(S+'su/*.json'):
    a=json.load(open(fn))['data']['attributes']
    if a.get('status')!='AKTIV': continue
    ad=[x for x in a.get('addresses',[]) if x.get('type')=='BESOKSADRESS' and x.get('geoCoordinates')]
    if not ad: continue
    g=ad[0]['geoCoordinates']; x,y=T.transform(float(g['longitude']),float(g['latitude']))
    tp=a.get('schoolTypes') or []; stp=a.get('schoolTypeProperties') or {}
    grades=(stp.get('gr') or stp.get('grs') or {}).get('grades') or []
    kind='gy' if ('GY' in tp or 'GYS' in tp) and 'GR' not in tp and 'GRS' not in tp else ('gr' if ('GR' in tp or 'GRS' in tp or 'FKLASS' in tp) else 'ovr')
    if kind=='ovr': continue
    schools.append([a.get('displayName') or a.get('schoolName'),round(x),round(y),kind,(('F–'+grades[-1]) if 'FKLASS' in tp and grades else (grades[0]+'–'+grades[-1] if grades else '')),ad[0].get('streetAddress',''),fn.split('/')[-1][:-5], 1 if 'GRS' in tp or 'GYS' in tp else 0])
pre=[]
for p in json.load(open(S+'forskolor.json')):
    x,y=T.transform(p['lon'],p['lat']); pre.append([p['namn'],round(x),round(y),p['adress'],p['id']])
json.dump({'stops':stops,'schools':schools,'pre':pre},open(O+'service.json','w'),ensure_ascii=False,separators=(',',':'))
print('stops',len(stops),'schools',len(schools),'pre',len(pre))
