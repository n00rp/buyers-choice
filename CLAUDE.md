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
- **Fler kommuner (2026-11-27):** Partille är tillagd. Mölndal och Kungälv har ingen öppen datatjänst (bara webbkartor), så de väntar. Hämta bara från tjänster som är öppna för datauttag, inte genom att köra kommunernas webbkartor.
- **Ingen Claude-attribution** i commits eller PR:er. Commits görs som Martin (`n00rp`).
- **Slutprodukten är en visuell webbportal**, inte en PDF-rapport.
- Användaren (Martin) skriver på svenska. Skriv texter i portalen, commits och svar på svenska.

## Design

- Tema "Varm redaktionell" (godkänt 2026-11-26): benvit bakgrund #FCFBF8, sandytor #F3EFE7, text #1C1A17, accent mörkgrön #2F5D50. Rubriker i Fraunces (serif), brödtext i Inter. Rundade kort (20 px) i bento-rutnät, ett mörkt kort för gällande plan, rundade knappar. Bara ljust tema.
- Vänstermeny med grupperade rubriker (t.ex. Bostaden, Området, Inför köpet). På mobil ersätts den av en meny i sidhuvudet.
- Genomarbetat, funktionellt, lätt att förstå och professionellt. Inte plottrigt.

## Hur det är byggt

- `portal/index.html` är hela portalen: en statisk sida utan byggsteg som läser förberäknade JSON-filer i `portal/`.
- All data hämtades från öppna tjänster utan nyckel den 25 november 2026 och räknades fram i förväg per adress. Portalen anropar inga externa tjänster när den körs.
- Koordinater är SWEREF 99 12 00 (EPSG:3007).
- `scripts/` innehåller Python-skripten som byggde JSON-filerna (beroenden: `numpy`, `shapely`, `pyproj`, `tifffile`). De förväntar sig rådata som GeoJSON under `/tmp/geo/`. Nedladdningen gjordes för hand och saknar skript.
- Övriga kommuner ligger i `portal/k/<kommun>/` med samma filformat. `KOM` i `index.html` listar kommunerna och vad de har data för (`har`). Göteborg ligger först så att adresslänkarna `#a<nummer>` inte ändras. `scripts/kommun_partille.py` hämtar och bygger Partille.
- `scripts/screenshots.js` tar skärmbilderna i `docs/screenshots/` medan portalen körs.
- Exempeladressen **Vildkaprifolen 5, Torslanda** har en fullständig rapport med manuellt tolkade planbestämmelser (`data/vildkaprifolen-5-detaljplan.json`). Andra adresser får en grundrapport.
- **Jämför adresser** (`#jamfor-<nr>-<nr>`): två eller tre adresser sida vid sida, byggt på samma förberäknade data som grundrapporten. Inga markeringar av bästa värde, bara ett reglage som döljer lika rader.
- `arkiv/vildkaprifolen-5.html` är den första prototypen för en enda adress.
- **iOS-app (2026-11-27):** nativ SwiftUI under `ios/` (iOS 17+), läser samma JSON från GitHub Pages. Martin har ingen Mac, så allt byggs i `.github/workflows/ios.yml` på macOS: tester, skärmbilder (läggs i grenen `ios-skarmbilder`, med apploggar och kraschrapporter) och TestFlight för hand. Se `ios/README.md`. Undvik `async let` med `try?` i vyernas laddning, det kraschade i Swift-körtiden.

### Köra lokalt

```bash
cd portal
python3 -m http.server 8000
# öppna http://localhost:8000
```

Sidan måste serveras över HTTP, inte öppnas direkt som fil.

### Publicering

GitHub Pages via `.github/workflows/pages.yml`, som lägger ut `portal/` vid push till `main`. Adress: https://n00rp.github.io/buyers-choice/

## Datakällor

Se tabellen i `README.md` och hela kartläggningen i `docs/datakallor.md`. I korthet: Göteborgs Stads adress-WFS, Stadsbyggnadskontorets plan- och fastighetstjänster, översiktsplanen, Miljöförvaltningens geoserver (buller, luft, livsmedelsobjekt), Trafikkontorets hållplatser, Skolverkets skolenhetsregister och stadens förskolelista.

Externa länkar från tidigare arbete:
- Prototyp (artefakt): https://claude.ai/artifact/VzstYCAcEVqCb14THHu7EC
- Datakällor (artefakt): https://claude.ai/artifact/EGf7Vjc8rFh5BhzVVoWP8F

## Vad som återstår

- **Pågående detaljplaner** hämtas sedan 2026-11-27 dagligen ur stadens projektdatabas (planobygg.nsf) av `scripts/bevakning/hamta.py` och visas under Bevakning och i grundrapporten under Planer i området (inom 1,5 km). Se `docs/bevakning.md`. Planbesked och startplan i nämndhandlingar ingår inte.
- **Bevakning med mejl:** GitHub Actions skickar via SMTP till bevakningar i hemligheten `BEVAKNINGAR`. Självanmälan i portalen saknas (kräver backend). Bygglov saknas som öppen källa.
- **Skred, jordart och jorddjup** finns hos SGU (maps3.sgu.se) och SGI (mapsext.sgi.se), men bara som WMS för visning (WFS avstängd). Att fråga dem per adress för 100 000 adresser är inte ett godkänt datauttag. Nästa steg är SGU:s nedladdningsbara öppna data (jordarter, jorddjupsmodell, förutsättningar för skred), som räknas mot adresserna lokalt.
- **Badplatser** är pausade av Martin. De kräver en gratis app-nyckel från data.goteborg.se.
- **Taxeringsvärde** är inte öppna data. Användaren fyller i det själv för att räkna fram fastighetsavgiften.
- Planbestämmelser är bara tolkade för exempeladressen.
- Linjer per hållplats räknas fram ur linjesträckningar (`scripts/build_linjer.py`, inom 45 m), inte tidtabeller, så en linje som kör förbi utan att stanna kan komma med.
- Ett hämtningsskript som laddar ned rådata, så att hela datakedjan kan köras om med ett kommando.
- Bygglov ingår inte ännu.
- **Föreningens ekonomi** (vyn `#forening`, under Bostaden) bygger på att användaren själv fyller i uppgifter ur årsredovisningen, eftersom den inte är öppna data. Inmatningen sparas i localStorage per adress (`bc-brf:<adress>`). Knappen "Fyll i exempelvärden" ger påhittade värden som märks som exempel. Att läsa in årsredovisningen automatiskt (t.ex. uppladdad PDF eller Bolagsverkets API för digitalt inlämnade årsredovisningar) återstår och kräver troligen backend.
