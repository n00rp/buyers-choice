# Buyers Choice

En portal som samlar det en bostadsköpare behöver veta om platsen innan visning och budgivning: gällande detaljplan, vad staden planerar runt omkring, miljö och risker samt närservice. Användaren söker på en adress. Om hen har en annonslänk visas den som ett kort med länk tillbaka till annonsen.

Portalen visar neutral information med källa. Den betygsätter inte bostäder eller områden.

Pilotkommun är **Göteborg**, och portalen täcker både villor och bostadsrätter.

## Kom igång

Prototypen är en statisk webbsida utan byggsteg. Den läser JSON-filer med relativa sökvägar, så den behöver serveras över HTTP (inte öppnas direkt som fil):

```bash
cd portal
python3 -m http.server 8000
# öppna http://localhost:8000
```

Samma mapp kan publiceras direkt med GitHub Pages eller valfri statisk webbhotell.

## Innehåll

| Sökväg | Vad |
| --- | --- |
| `portal/index.html` | Själva portalen: adressök, adresskort, detaljplan, framtida planer, miljö och risk, närservice. |
| `portal/adresser.json` | Alla cirka 102 000 adresspunkter i Göteborg, grupperade per gata, med index till plan- och miljödata. |
| `portal/planer.json` | Cirka 7 500 gällande planer (detaljplan, stadsplan, byggnadsplan, tomtindelning m.fl.) med beteckning, typ, namn och länk till planhandlingen (PDF). |
| `portal/framtid.json` | Utpekade förändringar i översiktsplanen (ny bebyggelse, vägar, kollektivtrafik, älvförbindelser m.m.). |
| `portal/m/*.json` | Miljö- och riskvärden per adress, uppdelat i block om 5 000 adresser. Kolumnerna beskrivs i `portal/miljo-meta.json`. |
| `portal/r/*.json` | Vägnät i rutor om 2,5 × 2,5 km, för kartritning. Beskrivs i `portal/roads-meta.json`. |
| `portal/service.json` | Hållplatser, skolor, förskolor, livsmedelsbutiker m.m. med koordinater. |
| `data/vildkaprifolen-5-detaljplan.json` | Manuellt tolkade planbestämmelser för exempeladressen Vildkaprifolen 5, Torslanda. |
| `scripts/` | Python-skripten som bygger JSON-filerna ovan ur stadens rådata. |
| `docs/datakallor.md` | Kartläggningen av datakällor: vad som finns, villkor, kostnad och juridik. |
| `arkiv/vildkaprifolen-5.html` | Den första prototypen, en sida för en enda adress. |

Koordinater är SWEREF 99 12 00 (EPSG:3007). I `adresser.json` lagras de som heltal relativt origo i fältet `o`.

## Datan är förberäknad

Portalen anropar inga kart- eller datatjänster när den körs. All data hämtades från öppna tjänster den **25 november 2026** och räknades fram i förväg: varje adresspunkt har slagits ihop med planen den ligger inom, bullervärden, luftkvalitet, radon, avstånd till skyfallsled, översvämningsområde, förorenad mark, flygbuller och farligt gods, samt fastighetsbeteckning och fastighetsarea.

Det betyder att:

- sidan laddar snabbt och fungerar utan nycklar eller inloggning,
- datan blir inaktuell med tiden och behöver byggas om för att spegla nya planbeslut,
- värdena är avlästa ur myndigheternas kartdata för punkten, inte mätningar på plats.

## Datakällor

Allt kommer från öppna tjänster utan nyckel. Fullständig kartläggning med villkor finns i [docs/datakallor.md](docs/datakallor.md).

| Data | Källa |
| --- | --- |
| Adresser | Göteborgs Stad, adress-WFS (`opengeodata.goteborg.se/services/adresser/wfs/v1`), CC0 |
| Gällande planer och planhandlingar | Stadsbyggnadskontoret, `geodata-external.sbk.goteborg.se/services/planer-v3` och `/dokument/` |
| Fastighetsgränser och beteckningar | Stadsbyggnadskontoret, `sbf-extern-fastighetsgrans-v1` (WMS GetFeatureInfo) |
| Översiktsplan, framtida förändringar, skyfall, översvämning, radon, förorenad mark | Göteborgs Stad, översiktsplan (`services.sbk.goteborg.se/oversiktsplan-v4`) |
| Vägtrafikbuller, luft (NO₂, PM10) | Miljöförvaltningen, `geoserverextern.miljoforvaltningen.goteborg.se` |
| Hållplatser | Trafikkontoret, `open.geodata.tkgbg.se/wfs` |
| Skolor | Skolverkets skolenhetsregister (`api.skolverket.se/skolenhetsregistret/v2`) |
| Förskolor | Göteborgs Stad, Hitta förskolor |

Inga annonser hämtas eller lagras. Portalen skrapar inte Hemnet eller Booli, och annonsbilder visas inte.

## Bygga om datan

Skripten i `scripts/` är de som användes för att ta fram den nuvarande datan. De är skrivna för en engångskörning och förväntar sig att rådata redan är nedladdad som GeoJSON under `/tmp/geo/` (adresser, planer, miljölager). Själva nedladdningen från WFS-tjänsterna gjordes för hand och finns inte som skript ännu.

| Skript | Gör |
| --- | --- |
| `build.py` | Kopplar adresser till planer och skriver `adresser.json`, `planer.json` och `service.json`. |
| `build_env.py` | Räknar fram miljö- och riskvärden per adress och skriver `framtid.json`. |
| `noise2.py` | Bullervärden per adress (fasad och lägsta nivå). |
| `fast.py` | Hämtar fastighetsbeteckning och area per adress via fastighets-WMS. |
| `fut_extra.py` | Kompletterar `framtid.json` med länkar ur översiktsplanen. |
| `build_roads.py` | Delar upp vägnätet i rutor (`r/`). |
| `shards.py` | Delar upp miljödatan i block (`m/`) och skriver `miljo-meta.json`. |

Beroenden: Python 3, `numpy`, `shapely`, `pyproj`, `tifffile`.

Ett naturligt nästa steg är ett hämtningsskript som laddar ned rådata från tjänsterna ovan, så att hela kedjan kan köras om med ett kommando.

## Status

Detta är en prototyp. Planbestämmelser är bara tolkade manuellt för exempeladressen. Pågående planarbete, bygglov och bostadsrättsföreningars årsredovisningar finns inte maskinläsbart och ingår inte ännu.
