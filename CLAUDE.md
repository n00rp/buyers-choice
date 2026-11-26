# Buyers Choice – projektminne för Claude

Den här filen sammanfattar vad som har bestämts i projektet hittills, så att en ny session (lokalt eller i molnet) vet var vi står. Läs också `README.md` och `docs/datakallor.md`.

## Mål

En portal som samlar det en bostadsköpare behöver veta om platsen inför visning och budgivning: gällande detaljplan, vad kommunen planerar runt omkring, miljö och risker samt närservice.

## Beslut

- **Inga avtal med Hemnet eller Booli.** Martin räknar inte med att få något, så portalen bygger inte på deras data.
- **Ingen skrapning** av annonssajter.
- **Ingång: adressökning** på valfri adress. Om användaren klistrar in en annonslänk visas ett annonskort med länk tillbaka till annonsen.
- **Annonsbilder visas inte.** Annonskortet har en platshållare och en länk till annonsen.
- **Neutral information med källa.** Inga betyg, inget bra/dåligt och inga trafikljus.
- **Pilotkommun: Göteborg.** Både villor och bostadsrätter, eftersom planändringar påverkar båda.
- **Slutprodukten är en visuell webbportal**, inte en PDF-rapport.
- Användaren (Martin) skriver på svenska. Skriv texter i portalen, commits och svar på svenska.

## Design

- Ljust, modernt tema (ljust som standard).
- Vänstermeny med grupperade rubriker (t.ex. Bostaden, Området, Inför köpet). På mobil ersätts den av en meny i sidhuvudet.
- Genomarbetat, funktionellt, lätt att förstå och professionellt. Inte plottrigt.

## Hur det är byggt

- `portal/index.html` är hela portalen: en statisk sida utan byggsteg som läser förberäknade JSON-filer i `portal/`.
- All data hämtades från öppna tjänster utan nyckel den 25 november 2026 och räknades fram i förväg per adress. Portalen anropar inga externa tjänster när den körs.
- Koordinater är SWEREF 99 12 00 (EPSG:3007).
- `scripts/` innehåller Python-skripten som byggde JSON-filerna (beroenden: `numpy`, `shapely`, `pyproj`, `tifffile`). De förväntar sig rådata som GeoJSON under `/tmp/geo/`. Nedladdningen gjordes för hand och saknar skript.
- `scripts/screenshots.js` tar skärmbilderna i `docs/screenshots/` medan portalen körs.
- Exempeladressen **Vildkaprifolen 5, Torslanda** har en fullständig rapport med manuellt tolkade planbestämmelser (`data/vildkaprifolen-5-detaljplan.json`). Andra adresser får en grundrapport.
- `arkiv/vildkaprifolen-5.html` är den första prototypen för en enda adress.

### Köra lokalt

```bash
cd portal
python3 -m http.server 8000
# öppna http://localhost:8000
```

Sidan måste serveras över HTTP, inte öppnas direkt som fil.

## Datakällor

Se tabellen i `README.md` och hela kartläggningen i `docs/datakallor.md`. I korthet: Göteborgs Stads adress-WFS, Stadsbyggnadskontorets plan- och fastighetstjänster, översiktsplanen, Miljöförvaltningens geoserver (buller, luft, livsmedelsobjekt), Trafikkontorets hållplatser, Skolverkets skolenhetsregister och stadens förskolelista.

Externa länkar från tidigare arbete:
- Prototyp (artefakt): https://claude.ai/artifact/VzstYCAcEVqCb14THHu7EC
- Datakällor (artefakt): https://claude.ai/artifact/EGf7Vjc8rFh5BhzVVoWP8F

## Vad som återstår

- **Pågående detaljplaner** (samråd, granskning) finns inte som öppen datatjänst för hela staden, bara som webbsidor och PDF:er. Kräver insamling och troligen en liten backend.
- **Skred och kvicklera** saknar öppen, frågbar källa per adress för hela staden (SGI:s kartering gäller främst längs Göta älv). Kräver också backend eller manuell tolkning av planbeskrivningar.
- **Badplatser** är pausade av Martin. De kräver en gratis app-nyckel från data.goteborg.se.
- **Taxeringsvärde** är inte öppna data. Användaren fyller i det själv för att räkna fram fastighetsavgiften.
- Planbestämmelser är bara tolkade för exempeladressen.
- Ett hämtningsskript som laddar ned rådata, så att hela datakedjan kan köras om med ett kommando.
- Bygglov och bostadsrättsföreningars årsredovisningar ingår inte ännu.
