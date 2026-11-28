"""Tester för hamta_ngp.py mot en lokal låtsasserver som följer API-beskrivningen.

Kör: python -m unittest discover scripts/ngp
"""
import base64
import csv
import gzip
import http.server
import json
import os
import tempfile
import threading
import unittest
from urllib.parse import urlparse, parse_qs

import hamta_ngp


def plan(oid, status, typ='detaljplan', lagakraft=None, paborjat=None):
    dp = {'objektidentitet': oid, 'namn': oid, 'status': status, 'typ': typ}
    if lagakraft:
        dp['datumLagakraft'] = lagakraft
    if paborjat:
        dp['datumPaborjat'] = paborjat
    return {'type': 'Feature', 'id': oid, 'geometry': None,
            'properties': {'datetime': None, 'feature': {'typ': 'detaljplan', 'etikett': oid}, 'detaljplan': dp}}


def bestammelse(oid_plan, nr):
    f = plan(oid_plan, 'laga kraft')
    f['id'] = f'{oid_plan}-b{nr}'
    f['properties']['feature'] = {'typ': 'användningsbestämmelse', 'etikett': 'B'}
    f['properties']['planbestammelse'] = {'bestammelseformulering': 'Bostäder', 'anvandningsform': 'kvartersmark'}
    return f


OBJEKT = {
    '1480': [plan('a', 'laga kraft', 'stadsplan', '1975-03-01'),
             plan('b', 'laga kraft', 'detaljplan', '2023-05-10', '2022-02-01'),
             bestammelse('b', 1), bestammelse('b', 2),
             plan('c', 'samråd', paborjat='2025-01-01')],
    '1402': [plan('d', 'laga kraft', lagakraft='2024-01-01', paborjat='2022-06-01')],
}


class Server(http.server.BaseHTTPRequestHandler):
    krav = None  # Authorization som krävs

    def log_message(self, *a):
        pass

    def svara(self, kod, d):
        b = json.dumps(d).encode()
        self.send_response(kod)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b)

    def do_POST(self):
        if self.path == '/token':
            self.svara(200, {'access_token': 'tok123', 'expires_in': 3600})

    def do_GET(self):
        if self.headers.get('Authorization') != Server.krav:
            return self.svara(401, {'message': 'Invalid Credentials'})
        u = urlparse(self.path)
        q = parse_qs(u.query)
        bas = f'http://127.0.0.1:{self.server.server_port}'
        if u.path == '/collections':
            sida = int(q.get('sida', ['0'])[0])
            alla = [{'id': k, 'title': f'Kommun {k}', 'license': 'CC0-1.0',
                     'providers': [{'name': f'Kommun {k}', 'kod': k}]} for k in sorted(OBJEKT)]
            d = {'collections': [alla[sida]], 'links': []}
            if sida + 1 < len(alla):
                d['links'].append({'rel': 'next', 'href': f'{bas}/collections?sida={sida + 1}'})
            return self.svara(200, d)
        if u.path.startswith('/collections/') and u.path.endswith('/items'):
            kid = u.path.split('/')[2]
            feats = OBJEKT[kid]
            start = int(q.get('start', ['0'])[0])
            d = {'type': 'FeatureCollection', 'features': feats[start:start + 2], 'links': []}
            if start + 2 < len(feats):
                d['links'].append({'rel': 'next', 'href': f'{bas}{u.path}?limit=2&start={start + 2}'})
            return self.svara(200, d)
        self.svara(404, {})


class Test(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = http.server.HTTPServer(('127.0.0.1', 0), Server)
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()
        cls.bas = f'http://127.0.0.1:{cls.srv.server_port}'

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def kor(self, env, *args):
        ut = tempfile.mkdtemp()
        hamta_ngp.main(['--ut', ut, *args], env=env, bas=self.bas, token_url=self.bas + '/token')
        return ut

    def las_tackning(self, ut):
        with open(os.path.join(ut, 'tackning.csv'), encoding='utf-8') as f:
            return {r['kod']: r for r in csv.DictReader(f)}

    def test_basic_auth_och_sammanstallning(self):
        Server.krav = 'Basic ' + base64.b64encode(b'martin:hemligt').decode()
        ut = self.kor({'LM_ANVANDARE': 'martin', 'LM_LOSENORD': 'hemligt'})
        t = self.las_tackning(ut)
        self.assertEqual(set(t), {'1402', '1480'})
        g = t['1480']
        self.assertEqual(g['planer'], '3')
        self.assertEqual(g['planbestammelser'], '2')
        self.assertEqual(g['laga_kraft'], '2')
        self.assertEqual(g['pagaende'], '1')
        self.assertEqual(g['laga_kraft_fore_2022'], '1')
        self.assertEqual(g['paborjade_fran_2022'], '2')
        self.assertEqual(g['aldre_plantyp'], '1')
        self.assertEqual(g['tidigaste_laga_kraft'], '1975-03-01')
        with gzip.open(os.path.join(ut, '1480.geojson.gz'), 'rt', encoding='utf-8') as f:
            self.assertEqual(len(json.load(f)['features']), 5)  # alla sidor hämtade

    def test_oauth_och_urval(self):
        Server.krav = 'Bearer tok123'
        ut = self.kor({'LM_CONSUMER_KEY': 'k', 'LM_CONSUMER_SECRET': 's'}, '--kommuner', '1402')
        self.assertEqual(set(self.las_tackning(ut)), {'1402'})
        with open(os.path.join(ut, 'kommuner.json'), encoding='utf-8') as f:
            self.assertEqual(len(json.load(f)), 2)

    def test_utan_inloggning(self):
        with self.assertRaises(SystemExit):
            self.kor({})


if __name__ == '__main__':
    unittest.main()
