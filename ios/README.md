# Buyers Choice för iOS

En nativ app i SwiftUI (iOS 17 och senare) som visar samma grundrapport som portalen. Appen läser portalens förberäknade JSON-filer från GitHub Pages (`AppConfig.dataBase` i `BuyersChoice/Core/DataStore.swift`), så data uppdateras på ett ställe.

## Struktur

- `project.yml` beskriver Xcode-projektet. Projektfilen skapas med [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate`) och checkas inte in.
- `BuyersChoice/Core/` läser och räknar på datan: koordinater (SWEREF 99 12 00 till WGS 84), sökning, texter i rapporten och det användaren sparar.
- `BuyersChoice/UI/` är vyerna: sök, rapport, karta, sparade och om.
- `BuyersChoiceTests/` är enhetstester för omräkning, sökning och tolkning av filerna.
- `scripts/` används av molnbygget för att välja simulator och ta skärmbilder.

## Bygga utan egen Mac

Arbetsflödet `.github/workflows/ios.yml` körs på en Mac hos GitHub när något under `ios/` ändras. Det bygger appen, kör testerna och sparar skärmbilder från simulatorn under **Artifacts** på körningen.

## Första gången: TestFlight

Det här görs en gång, i webbläsaren.

1. **Bundle-id.** Logga in på [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) → Identifiers → + → App IDs → App. Beskrivning "Buyers Choice", Bundle ID explicit `se.buyerschoice.app` (eller ett eget, ändra då `PRODUCT_BUNDLE_IDENTIFIER` i `project.yml`).
2. **Appen i App Store Connect.** [appstoreconnect.apple.com](https://appstoreconnect.apple.com/apps) → Appar → + → Ny app. Plattform iOS, namn "Buyers Choice" (eller ledigt namn), primärt språk svenska, bundle-id från steg 1, SKU till exempel `buyerschoice`.
3. **API-nyckel.** App Store Connect → Användare och åtkomst → Integrationer → App Store Connect API → Team Keys → +. Namn "GitHub Actions", åtkomst **Admin** (behövs för att molnbygget ska få skapa certifikat och profiler). Ladda ned `.p8`-filen (går bara en gång) och notera **Key ID** och **Issuer ID**.
4. **Team ID.** Står under [Membership details](https://developer.apple.com/account#MembershipDetailsCard), tio tecken.
5. **Hemligheter i GitHub.** Repot → Settings → Secrets and variables → Actions → New repository secret:
   - `ASC_KEY_ID`: Key ID
   - `ASC_ISSUER_ID`: Issuer ID
   - `ASC_KEY_P8`: hela innehållet i `.p8`-filen, inklusive raderna BEGIN och END
   - `APPLE_TEAM_ID`: Team ID
6. **Ladda upp.** Repot → Actions → iOS-app → Run workflow → bocka i "Ladda upp en ny version till TestFlight". När körningen är klar tar Apple 15–30 minuter att behandla bygget.
7. **Testa.** Installera appen TestFlight på iPhone. I App Store Connect → appen → TestFlight → Interna testare, lägg till dig själv. Appen dyker upp i TestFlight.

Byggnumret sätts automatiskt från körningens nummer. Versionsnumret (`MARKETING_VERSION`) ändras i `project.yml`.

## Inför publicering i App Store

- Integritetspolicy som webbsida (appen samlar inte in data, men en länk krävs).
- Skärmbilder för 6,9" iPhone (molnbyggets skärmbilder är en bra början).
- Beskrivning, nyckelord, kategori (Livsstil eller Referens), åldersgradering och kontaktuppgifter.
- En riktig appikon (den nuvarande är tillfällig).
- Kontrollera att licenserna för de öppna datakällorna tillåter kommersiell användning, och behåll källhänvisningarna.
