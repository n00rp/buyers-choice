"""Hämtar detaljplaner ur Lantmäteriets nationella geodataplattform (NGP).

Användning:
    python scripts/ngp/hamta_ngp.py                    # alla kommuner som levererar
    python scripts/ngp/hamta_ngp.py --kommuner 1480,1402
    python scripts/ngp/hamta_ngp.py --bara-lista       # bara vilka kommuner som finns

Skriptet behöver bara Pythons standardbibliotek, så det går att köra på
Windows utan att installera något.

Inloggning (sätt som miljövariabler, aldrig i koden):
    LM_ANVANDARE och LM_LOSENORD        Geotorget-kontot (Basic auth), eller
    LM_CONSUMER_KEY och LM_CONSUMER_SECRET   nycklar från API-portalen (OAuth 2.0)

NGP får bara användas inom EU/EES. Anrop från andra länder (till exempel
molnmiljöer och GitHubs körare i USA) får svaret "Geolocation Block!".

Resultat i --ut (standard ngp-data/):
    kommuner.json        datamängderna (en per kommun) med kommunkod och namn
    <kod>.geojson.gz     alla referensobjekt för kommunen, i SWEREF 99 TM (EPSG:3006)
    tackning.csv         sammanställning per kommun: hur många planer, hur gamla,
                         och hur många som är pågående. Det är den som visar luckan.

API: Geodatakatalog Sökning för detaljplan 2.2 (STAC / OGC API Features),
https://namespace.lantmateriet.se/distribution/geodatakatalog/sokning/v1/detaljplan/v2/detaljplan-api-2.2.html
Licens för datan: CC0.
"""
import argparse
import base64
import csv
import gzip
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BAS = 'https://api.lantmateriet.se/distribution/geodatakatalog/sokning/v1/detaljplan/v2'
TOKEN_URL = 'https://api.lantmateriet.se/token'
SIDA = 10000  # API:ets största tillåtna limit
PAGAENDE = {'påbörjad', 'samråd', 'granskning', 'antagen', 'överklagad', 'tillsyn'}
GAMLA_TYPER = {'stadsplan', 'byggnadsplan', 'avstyckningsplan'}
GRANS = '2022-01-01'  # planer påbörjade efter 2021 måste finnas i NGP


class Inloggning:
    """Lägger till Authorization-huvud. Hämtar och förnyar OAuth-token vid behov."""

    def __init__(self, env=os.environ, token_url=TOKEN_URL):
        self.env = env
        self.token_url = token_url
        self.token = None
        self.giltig_till = 0

    def huvud(self):
        anv, lsn = self.env.get('LM_ANVANDARE'), self.env.get('LM_LOSENORD')
        if anv and lsn:
            return 'Basic ' + base64.b64encode(f'{anv}:{lsn}'.encode()).decode()
        nyckel, hemlis = self.env.get('LM_CONSUMER_KEY'), self.env.get('LM_CONSUMER_SECRET')
        if nyckel and hemlis:
            if not self.token or time.time() > self.giltig_till - 60:
                self._ny_token(nyckel, hemlis)
            return 'Bearer ' + self.token
        sys.exit('Saknar inloggning: sätt LM_ANVANDARE och LM_LOSENORD, '
                 'eller LM_CONSUMER_KEY och LM_CONSUMER_SECRET.')

    def _ny_token(self, nyckel, hemlis):
        auth = base64.b64encode(f'{nyckel}:{hemlis}'.encode()).decode()
        req = urllib.request.Request(self.token_url, data=b'grant_type=client_credentials',
                                     headers={'Authorization': 'Basic ' + auth,
                                              'Content-Type': 'application/x-www-form-urlencoded'})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        self.token = d['access_token']
        self.giltig_till = time.time() + int(d.get('expires_in', 3600))


def hamta_json(url, inl, forsok=4):
    for i in range(forsok):
        req = urllib.request.Request(url, headers={'Authorization': inl.huvud(),
                                                   'Accept': 'application/geo+json, application/json'})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            text = e.read().decode('utf-8', 'replace')[:300]
            if 'Geolocation' in text:
                sys.exit('NGP spärrar anrop utanför EU/EES ("Geolocation Block!"). '
                         'Kör skriptet från en dator i Sverige.')
            if e.code in (401, 403):
                sys.exit(f'Inloggningen godtogs inte ({e.code}): {text}')
            if e.code == 429 or e.code >= 500:
                time.sleep(5 * (i + 1))
                continue
            raise
        except urllib.error.URLError:
            time.sleep(5 * (i + 1))
    raise RuntimeError(f'Gav upp efter {forsok} försök: {url}')


def nasta_lank(d):
    for l in d.get('links', []):
        if l.get('rel') == 'next':
            return l['href']
    return None


def kommuner(inl, bas=BAS):
    """Alla datamängder (normalt en per kommun) som NGP har."""
    ut, url = [], f'{bas}/collections'
    while url:
        d = hamta_json(url, inl)
        for c in d.get('collections', []):
            prov = (c.get('providers') or [{}])[0]
            ut.append({'id': c['id'], 'kod': prov.get('kod') or c['id'],
                       'namn': c.get('title') or prov.get('name') or c['id'],
                       'licens': c.get('license')})
        url = nasta_lank(d)
    return ut


def objekt(inl, kid, bas=BAS):
    """Alla referensobjekt (detaljplaner och planbestämmelser) i en datamängd."""
    url = f'{bas}/collections/{urllib.parse.quote(kid)}/items?limit={SIDA}'
    while url:
        d = hamta_json(url, inl)
        yield from d.get('features', [])
        url = nasta_lank(d)


def sammanstall(features):
    """Räknar per kommun. Planbestämmelser har samma detaljplan-attribut som sin plan,
    så planer räknas på unika objektidentiteter."""
    planer, antal_best = {}, 0
    for f in features:
        p = f.get('properties') or {}
        typ = (p.get('feature') or {}).get('typ')
        dp = p.get('detaljplan') or {}
        if typ and typ != 'detaljplan':
            antal_best += 1
        oid = dp.get('objektidentitet') or f.get('id')
        if oid and (typ == 'detaljplan' or oid not in planer):
            planer[oid] = dp
    lagakraft = [d.get('datumLagakraft') for d in planer.values() if d.get('datumLagakraft')]
    return {
        'planer': len(planer),
        'planbestammelser': antal_best,
        'laga_kraft': sum(1 for d in planer.values() if d.get('status') == 'laga kraft'),
        'pagaende': sum(1 for d in planer.values() if d.get('status') in PAGAENDE),
        'laga_kraft_fore_2022': sum(1 for x in lagakraft if x < GRANS),
        'paborjade_fran_2022': sum(1 for d in planer.values() if (d.get('datumPaborjat') or '') >= GRANS),
        'aldre_plantyp': sum(1 for d in planer.values() if d.get('typ') in GAMLA_TYPER),
        'tidigaste_laga_kraft': min(lagakraft) if lagakraft else '',
    }


KOLUMNER = ['kod', 'namn', 'planer', 'planbestammelser', 'laga_kraft', 'pagaende',
            'laga_kraft_fore_2022', 'paborjade_fran_2022', 'aldre_plantyp', 'tidigaste_laga_kraft']


def main(argv=None, env=os.environ, bas=BAS, token_url=TOKEN_URL):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--ut', default='ngp-data')
    ap.add_argument('--kommuner', help='kommunkoder, kommaseparerade (standard: alla)')
    ap.add_argument('--bara-lista', action='store_true')
    a = ap.parse_args(argv)
    os.makedirs(a.ut, exist_ok=True)
    inl = Inloggning(env, token_url)

    alla = kommuner(inl, bas)
    with open(os.path.join(a.ut, 'kommuner.json'), 'w', encoding='utf-8') as f:
        json.dump(alla, f, ensure_ascii=False, indent=1)
    print(f'{len(alla)} datamängder i NGP')
    if a.bara_lista:
        return
    valda = set(a.kommuner.split(',')) if a.kommuner else None

    rader = []
    for k in alla:
        if valda and k['kod'] not in valda and k['id'] not in valda:
            continue
        feats = list(objekt(inl, k['id'], bas))
        with gzip.open(os.path.join(a.ut, f"{k['kod']}.geojson.gz"), 'wt', encoding='utf-8') as f:
            json.dump({'type': 'FeatureCollection', 'features': feats}, f, ensure_ascii=False)
        rad = {'kod': k['kod'], 'namn': k['namn'], **sammanstall(feats)}
        rader.append(rad)
        print(f"{k['kod']} {k['namn']}: {rad['planer']} planer, {rad['laga_kraft_fore_2022']} laga kraft före 2022")

    with open(os.path.join(a.ut, 'tackning.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=KOLUMNER)
        w.writeheader()
        w.writerows(sorted(rader, key=lambda r: r['kod']))
    print(f"Klart: {os.path.join(a.ut, 'tackning.csv')}")


if __name__ == '__main__':
    main()
