import json,os
m=json.load(open('/tmp/geo/out/miljo.json'));nz=json.load(open('/tmp/geo/noise2.json'));fa=json.load(open('/tmp/geo/out_fast.json'))
rows=m['r']
for i,r in enumerate(rows):
    lo,hi=nz['leq'][0][i],nz['leq'][1][i]; mlo,mhi=nz['max'][0][i],nz['max'][1][i]
    r[0]=hi if hi is not None else -1; r[1]=mhi if mhi is not None else -1
    f=fa[i]; r.append(f[0] if f else None); r.append(f[1] if f else None)
    r.append(lo if lo is not None else -1); r.append(mlo if mlo is not None else -1)
B=5000;os.makedirs('/tmp/geo/out/m',exist_ok=True)
for s in range(0,len(rows),B): json.dump(rows[s:s+B],open(f'/tmp/geo/out/m/{s//B}.json','w'),ensure_ascii=False,separators=(',',':'))
meta={k:v for k,v in m.items() if k!='r'};meta['block']=B;meta['cols']=meta['cols']+['fastighet','fastighet_area_m2','leq_lagsta','lmax_lagsta']
json.dump(meta,open('/tmp/geo/out/miljo-meta.json','w'),ensure_ascii=False)
print('ok',rows[94941])
