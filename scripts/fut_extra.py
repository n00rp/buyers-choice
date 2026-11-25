import json, glob, re, sys
E = '/tmp/geo/env/'; F = sys.argv[1]
d = json.load(open(F)); FP = d['f']
def clean(v):
    v = (v or '').strip()
    return '' if v in ('None', '_', '') else re.sub(r'\s+', ' ', v).strip()
def link(v):
    v = clean(v)
    if not v: return None
    m = re.search(r'data-link=\\?"?(https://[^\s>"\\]+)', v)
    t = re.sub(r'<[^>]+>', '', v).strip()
    t = re.sub(r'\s+', ' ', t)
    if m: return [t or 'Extern länk', m.group(1)]
    return [t or 'Läs mer i översiktsplanen', '']  # internal chapter, no verified deep link
i = 0
for f in sorted(glob.glob(E + 'fp_*.json')):
    for x in json.load(open(f))['features']:
        if not x.get('geometry'): continue
        p = x['properties']; o = FP[i]
        assert o['n'] == (p.get('objekt_namn') or '').strip(), (i, o['n'])
        o['u'] = clean(p.get('objekt_utredningslage'))
        o['gb'] = clean(p.get('generell_objektsbeskrivning'))
        o['s'] = clean(p.get('status'))
        o['c'] = clean(p.get('underkategori_1'))
        o['a'] = clean(p.get('ansvarig'))
        o['bf'] = clean(p.get('befintlig_framtida'))
        lk = [l for l in (link(p.get('intern_url_1')), link(p.get('intern_url_2')), link(p.get('extern_url'))) if l]
        if lk: o['lk'] = lk
        o['b'] = clean(o.get('b')); o['r'] = clean(o.get('r'))
        i += 1
assert i == len(FP), (i, len(FP))
d['beslut'] = 'Antagen av kommunfullmäktige 2022-05-19'
d['url'] = 'https://oversiktsplan.goteborg.se/'
json.dump(d, open(F, 'w'), ensure_ascii=False, separators=(',', ':'))
print('ok', i, sum(1 for o in FP if o.get('lk')))
