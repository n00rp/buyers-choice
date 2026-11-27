# Datakällor för Buyers Choice

Exporterad 2026-11-25 från det levande dokumentet: https://claude.ai/artifact/EGf7Vjc8rFh5BhzVVoWP8F

## Sammanfattning

Plan-, fastighets- och riskdata går att få fram lagligt och oftast gratis. Annonserna är den svåra delen: varken Hemnet eller Booli har ett öppet API, och båda förbjuder återanvändning utan tillstånd.

- **Annonser:** bygg inte på skrapning. Starta med att användaren klistrar in en adress eller fastighetsbeteckning (eller en annonslänk som vi bara läser adressen ur), och sök avtal med mäklarsystem eller mäklarkedjor på sikt.
- **Detaljplaner:** planer påbörjade efter 31 december 2021 ska vara digitala och nås via Lantmäteriets nationella geodataplattform (NGP). Äldre planer finns hos kommunen, oftast som PDF med en planområdesgräns i kommunens karttjänst.
- **Fastighet:** fastighetsgränser är öppna data hos Lantmäteriet. Ägare, servitut, taxering och köpeskillingar kräver avtal och kostar.
- **Risk och miljö:** buller, radon, översvämning, skred, förorenad mark och kulturmiljö finns som öppna kartlager hos statliga myndigheter och länsstyrelser, ofta via WMS/WFS.

Markeringen **(A)** betyder antagande: det bygger på min kunskap och har inte kontrollerats mot en källsida i den här versionen.

## Bostadsannonser

Ingen stor annonsplattform erbjuder ett öppet API för annonsdata. Datan kommer ursprungligen från mäklarnas system, och det är där ett avtal är mest realistiskt.

| Källa | Åtkomst och format | Kostnad | Juridiska begränsningar |
| --- | --- | --- | --- |
| [Booli](https://www.booli.se/integritet/anvandarvillkor) (ägs av SBAB) | Inget öppet API beskrivet. Det tidigare publika API:et är nedlagt (A). Booli Pro är en betaltjänst för proffs. | Booli Pro: offert (A) | Villkoren kräver Boolis förhandssamtycke för all användning av innehåll och förbjuder åtkomst på annat sätt än via gränssnittet. Booli har [utgivningsbevis](https://www.booli.se/integritet/utgivaransvar) (grundlagsskyddad databas). |
| Hemnet | Inget öppet API. Mäklare skickar annonser till Hemnet via sina mäklarsystem (A). | Ej tillämpligt | Villkoren kunde inte läsas i denna version. Troligen förbud mot automatisk insamling och skydd enligt katalogskyddet i 49 § upphovsrättslagen (A). |
| Mäklarsystem (Vitec Express, Fasad, Mspecs m.fl.) (A) | Annonsdata finns här som strukturerade objekt, ofta med export till portaler. | Avtal per system eller mäklarföretag (A) | Kräver avtal med systemleverantören och samtycke från mäklaren. |
| Mäklarkedjornas egna sajter | Ingen gemensam struktur. | Ej tillämpligt | Samma upphovsrättsliga skydd som portalerna. |
| Tredjepartsskrapor (t.ex. Apify-aktörer) | Finns färdiga för både Hemnet och Booli. | Låg | Bryter mot plattformarnas villkor och riskerar intrång i databasskyddet. Avråds. |

**Rekommendation för en första version:** låt användaren ange adress eller fastighetsbeteckning och länka till annonsen i stället för att visa dess innehåll. Portalen blir då ett komplement till annonsen, inte en kopia av den.

## Detalj- och översiktsplaner

Det finns inget färdigt "nationellt detaljplaneregister hos Boverket" att hämta från. Boverket skriver föreskrifterna för hur planer ska vara digitala, medan Lantmäteriet driver den nationella plattformen där de tillgängliggörs. Kommunen är alltid informationsägare.

| Källa | Åtkomst och format | Kostnad | Juridiska begränsningar |
| --- | --- | --- | --- |
| [Nationella geodataplattformen (NGP), Lantmäteriet](https://www.lantmateriet.se/globalassets/temawebbar/ngp/datamangder/fragor-och-svar-om-detaljplaner-i-ngp-goteborg.pdf) | API:er för digitala detaljplaner enligt Boverkets föreskrift. Ingen visningstjänst, vi måste rita själva. Endast information som kan vara öppen publiceras. | Inte angivet i källan. Troligen gratis som öppna data (A) | Kommunen äger datan. Licens behöver bekräftas. |
| [Boverkets krav på digitala detaljplaner](https://www.boverket.se/sv/PBL-kunskapsbanken/detaljplan/planbestammelser/foreskrift-om-detaljplan/digital-information/) | Gäller planer som påbörjats efter 31 december 2021. Bygger på planbestämmelsekatalogen, så bestämmelser som byggrätt och höjd blir maskinläsbara. | Gratis | Specifikation, inte data. |
| [Lantmäteriets e-tjänst Detaljplaner](https://detaljplaner.lantmateriet.se) | Webbvisning av ett urval digitala planer. | Gratis | Inte NGP och inte komplett, enligt Lantmäteriet. |
| Kommunernas karttjänster (äldre planer) | Planområdesgränser som WMS/WFS eller i webbkarta, med plankarta och planbeskrivning som skannad PDF. Varierar mellan 290 kommuner (A). | Gratis att läsa. Kommunens geodata kan ha avgift (A) | Planbeslut är allmänna handlingar och myndighetsbeslut saknar upphovsrätt. Kommunens grundkarta under plankartan kan vara skyddad (A). |
| Fastighetsregistret, avdelningen planer och bestämmelser | Vilka planer och bestämmelser som berör en fastighet, via Lantmäteriets fastighetsinformation. | Avtal och avgift | Se Fastighetsdata. |
| [Boverket ÖP-katalogen](https://www.boverket.se/sv/om-boverket/oppna-data/api-for-op-katalogen/) | Stöd och katalog för digitala översiktsplaner. API-detaljer saknades på sidan. | Gratis (A) | Översiktsplaner är vägledande, inte bindande. |
| Kommunala översiktsplaner och planprogram | Oftast PDF eller webbkarta på kommunens sajt. | Gratis | Allmänna handlingar. |
| Pågående planarbete | Kommunernas listor över pågående planer och samråd, sällan maskinläsbart (A). | Gratis | Allmänna handlingar. |

För köparen är pågående planer ofta viktigast, eftersom de visar vad som kan byggas runt bostaden. De är också svårast att samla in automatiskt.

## Fastighetsdata och bygglov

Fastighetsgränser, adresser och byggnader är öppna data sedan EU:s regler om värdefulla datamängder (HVD). Allt som rör ägare och rättigheter i fastighetsregistret kräver avtal.

| Källa | Åtkomst och format | Kostnad | Juridiska begränsningar |
| --- | --- | --- | --- |
| [Lantmäteriet, öppna data (HVD)](https://lantmateriet.se/en/geodata/geodata-products/open-data/high-value-data-hvd) | Fastighetsindelning, adresser, byggnader, höjddata, ortofoto. API via Geotorget, t.ex. OGC API Features och WMS (A). | Gratis | Fri användning. Licensen troligen CC0 eller CC BY (A). Källsidan är från 2025 och kan vara inaktuell. |
| Lantmäteriet, fastighetsregistret (inskrivning, servitut, rättigheter, planer) | API eller direktåtkomst efter avtal via Geotorget (A). | Avgift per fråga eller abonnemang (A) | Innehåller personuppgifter, så GDPR gäller och ändamålet prövas i avtalet. |
| Lantmäteriet, köpeskillingar | Historiska försäljningspriser för småhus och tomter, inte bostadsrätter (A). | Avgift (A) | Personuppgifter. |
| Taxeringsvärde (Skatteverket via fastighetsregistret) | Ingår i fastighetsinformationen. | Avgift via avtal (A) | Personuppgifter. |
| [Post- och Inrikes Tidningar](https://poit.bolagsverket.se) | Kungörelser om beviljade bygglov i hela landet, per fastighet (A). | Gratis | Allmänna kungörelser. Kontrollera villkor för automatisk hämtning. |
| Kommunernas bygglovsdiarier | Några kommuner publicerar ärenden digitalt. Annars begäran om allmän handling. Inget nationellt register (A). | Gratis, kopior kan kosta | Ritningar kan vara upphovsrättsligt skyddade. Personuppgifter. |
| [Boverket, energideklarationer](https://www.boverket.se/sv/om-boverket/oppna-data/) | Energiklass per byggnad. Sökbar i Boverkets tjänst, eventuellt som öppna data (A). | Gratis (A) | Kontrollera villkor. |
| Bolagsverket, BRF:ers årsredovisningar | Ekonomi för bostadsrättsföreningar. Delvis gratis via API för värdefulla datamängder (A). | Gratis eller låg avgift (A) | Föreningsdata, få personuppgifter. |

## Miljö och risk

Nästan allt här är öppna statliga kartlager, så det är den snabbaste vägen till värde för köparen. Hela sektionen bygger på min kunskap och behöver kontrolleras mot respektive myndighets villkor (A).

| Tema | Källa | Åtkomst och format | Kostnad | Begränsningar |
| --- | --- | --- | --- | --- |
| Väg- och järnvägsbuller | Trafikverket (Lastkajen) och kommunernas bullerkartor enligt EU-direktivet | WMS/nedladdning, kommunala kartor varierar | Gratis | Kartläggningen gäller bara större vägar och städer. |
| Flygbuller | Swedavia och Försvarsmakten | Bullerkurvor som PDF eller kartor | Gratis | Ej enhetligt format. |
| Radon | Kommunernas radonriskkartor, SGU:s gammastrålningskartor | WMS hos SGU, kommunala kartor varierar | Gratis | Visar markrisk, inte husets värde. Ersätter inte mätning. |
| Översvämning | Myndigheten för civilt försvar (tidigare MSB), översvämningskarteringar; kommunala skyfallskarteringar | WMS/nedladdning | Gratis | Skyfall finns bara i vissa kommuner. |
| Skred, ras och erosion | SGI (skredrisk, stranderosion), SGU (jordarter) | WMS/WFS | Gratis | Översiktlig skala. |
| Förorenad mark | Länsstyrelserna, potentiellt förorenade områden (EBH) | WMS via Länsstyrelsernas geodatakatalog | Gratis | Vissa objekt kan vara sekretessbelagda eller utelämnade. |
| Kulturmiljö och fornlämningar | Riksantikvarieämbetet, Fornsök / Kulturmiljöregistret | API och WMS | Gratis, öppen licens | Påverkar vad man får bygga. |
| Riksintressen, strandskydd, naturreservat | Länsstyrelserna, Naturvårdsverket | WMS/WFS | Gratis | Strandskyddsgränser kan vara ofullständiga digitalt. |
| Planerad infrastruktur | Trafikverket (planerade vägar och järnvägar), Vindbrukskollen | API/WMS | Gratis | Planer kan ändras. |
| Närområde | Skolverket (skolor), Trafiklab (kollektivtrafik), SCB (statistik per område) | API | Gratis, Trafiklab kräver API-nyckel | SCB-data på områdesnivå kan kosta. |

## Juridik

Den största juridiska risken ligger i annonsdatan. Offentliga plan- och geodata är i regel fria att återanvända. Inget av detta är juridisk rådgivning, och en jurist bör granska annonsfrågan innan lansering.

- **Databasskydd:** 49 § upphovsrättslagen (katalogskyddet) och EU:s databasrätt skyddar sammanställningar som annonsportaler mot uttag av väsentliga delar, även om enskilda uppgifter inte är skyddade (A).
- **Upphovsrätt:** annonsbilder och texter ägs av mäklare och fotografer. Myndighetsbeslut som detaljplaner saknar upphovsrätt enligt 1 kap. 9 § upphovsrättslagen, men kartunderlag kan vara skyddat (A).
- **GDPR:** adress kopplad till fastighetsbeteckning och ägare är personuppgifter. Visa inte ägare, och dokumentera rättslig grund (troligen berättigat intresse) (A). Booli lutar sig på utgivningsbevis och grundlagsskydd. Det är ett alternativ för portalen också, men det kräver en ansvarig utgivare och redaktionell verksamhet (A).
- **Öppna data-lagen (2022:818) och HVD-förordningen (EU 2023/138):** ger rätt att återanvända offentliga data som redan lämnas ut och kräver att värdefulla datamängder är gratis via API (A).
- **Offentlighetsprincipen:** kommunala planer och bygglov är allmänna handlingar, men en begäran besvaras manuellt och skalar inte.

## Pilot: Göteborg, villor och bostadsrätter

Martin har valt Göteborg som pilotkommun och både villor och bostadsrätter, eftersom planerade ändringar i detaljplanerna påverkar båda lika. Det gör detaljplanerna och pågående planarbete till kärnan i piloten.

| Källa i Göteborg | Vad den ger | Åtkomst | Status |
| --- | --- | --- | --- |
| [Göteborgs Stads öppna data (goteborg.se/psidata)](http://goteborg.se/psidata) | Baskarta, adresser och höjdmodell sedan [juni 2020](https://www.mynewsdesk.com/se/goteborgsstad/pressreleases/stadsbyggnadskontoret-i-goeteborg-slaepper-fler-oeppna-grundlaeggande-geodata-nu-med-projekteringsfokus-3016588), avgiftsfritt. Också luftkvalitet och trafikbuller enligt [Trafiklab](https://www.trafiklab.se/api/other-apis/g%C3%B6teborg-stad/). | Geodatatjänster och nedladdningsbara filer | Verifierat. Adresstjänsten (WFS) ger koordinater per adress, CC0, utan nyckel. |
| NGP, digitala detaljplaner för Göteborg | Planer påbörjade efter 2021 med maskinläsbara bestämmelser. Lantmäteriet höll en [workshop i Göteborg i maj 2025](https://www.lantmateriet.se/globalassets/temawebbar/ngp/datamangder/fragor-och-svar-om-detaljplaner-i-ngp-goteborg.pdf) om just detta. | NGP:s API:er | Hur många Göteborgsplaner som finns i NGP är inte kontrollerat. |
| Stadsbyggnadskontorets planlista och planhandlingar | Pågående planer med samråd och granskning, plus handlingar som PDF i stadens e-tjänst för plan och bygg (A). | Webbsidor och PDF, troligen skrapning eller manuell insamling (A) | Behöver undersökas. Viktigaste källan för "vad som kan byggas här". |
| Göteborgs stadskarta | Gränser för gällande och pågående planer, ofta via ArcGIS-tjänster bakom webbkartan (A). | Kartjänst (A) | Behöver undersökas, och villkor för återanvändning måste kollas. |
| Skyfalls- och översvämningskartor | Göteborg har egna skyfallskarteringar och är utsatt vid Göta älv och havsnivåhöjning (A). | Kommunal karta och statliga lager | Behöver undersökas. |
| Skred och kvicklera | SGI:s karteringar längs Göta älv är särskilt relevanta i Göteborg (A). | WMS | Behöver undersökas. |

**För bostadsrätter** kopplas planen till föreningens fastighet, inte till lägenheten. Därför behöver portalen översätta adress till fastighetsbeteckning via Lantmäteriets öppna adress- och fastighetsdata, och BRF:ens årsredovisning hos Bolagsverket blir ett komplement.

### Göteborgs plantjänster, verifierade 2026-11-25

Göteborgs gällande detaljplaner finns som öppen WFS och WMS utan inloggning, med en länk till den skannade planhandlingen (PDF) för varje plan. Det är samma tjänster som stadens egen karta [karta.goteborg.se?m=planer](https://karta.goteborg.se/?m=planer) använder. De finns inte i Boverkets eller Lantmäteriets register för äldre planer.

| Tjänst | Adress | Innehåll | Villkor |
| --- | --- | --- | --- |
| Gällande planer, WFS | `https://geodata-external.sbk.goteborg.se/services/planer-v3/wfs`, lager `planer-v3:planer` | Planpolygon, typ (detaljplan, stadsplan, byggnadsplan, tomtindelning m.fl.), aktbeteckning, namn och PDF-länk. SWEREF 99 12 00 (EPSG:3007). | Öppen utan nyckel. Licens inte angiven i tjänsten (A: troligen samma CC0 som stadens övriga öppna geodata). |
| Gällande planer, WMS | `https://geodata-external.sbk.goteborg.se/services/planer-v3/wms` | Kartbild per plantyp, även ändringar och områdesbestämmelser. | Som ovan. |
| Fastighetsgränser, WMS | `https://geodata-external.sbk.goteborg.se/services/sbf-extern-fastighetsgrans-v1/wms` | Gränser och fastighetsbeteckningar som kartbild. | Öppen utan nyckel. |
| Adresser, WFS | `https://opengeodata.goteborg.se/services/adresser/wfs/v1` | Adresspunkt per adress. | CC0. |
| Planhandlingar | `https://geodata-external.sbk.goteborg.se/dokument/planer/<aktbeteckning>.pdf` | Plankarta, beskrivning och bestämmelser. Äldre planer är skannade bilder utan text, så de måste OCR-tolkas eller läsas manuellt. | Allmänna handlingar. |
| Pågående planer | [goteborg.se, plan- och byggprojekt](https://goteborg.se/wps/portal?uri=gbglnk%3agbg.page.bb7386fd-1152-47cb-9da4-d06bd7780a77) och handlingar på www5.goteborg.se | Lista och PDF:er. Ingen öppen datatjänst hittad. | Måste samlas in från webbsidor. |

Stadens fastighetssök-WFS kräver en nyckel och används inte.

### Exempel: Vildkaprifolen 5, Torslanda

Adresspunkten ligger inom stadsplan [1480K-II-3540](https://geodata-external.sbk.goteborg.se/dokument/planer/1480K-II-3540.pdf), "Småhus m m i Torslanda Bur, västra delen", upprättad augusti 1979, antagen av kommunfullmäktige 1980-03-27 och fastställd av länsstyrelsen 1980-10-02. Den ligger också inom tomtindelning [1480K-III-7933](https://geodata-external.sbk.goteborg.se/dokument/planer-III/1480K-III-7933.pdf) för kvarteret Pilvingen. Fastigheten är RÖD 138:3, verifierad mot annonsen (se nedan).

| Bestämmelse i planen (gäller F-område) | Innebörd |
| --- | --- |
| B | Endast bostäder |
| F, § 2 | Huvudbyggnader ska vara fristående |
| § 3 | Tomt får inte vara mindre än 700 m² |
| § 4 | Högst en fjärdedel av tomten får bebyggas |
| § 5 | En huvudbyggnad och, efter prövning, ett garage |
| I och 4,5 i rektangel | En våning och högst 4,5 m byggnadshöjd, med undantag om befintligt hus redan är högre |
| § 8 | Enfamiljshus, fler lägenheter bara om befintligt hus redan har det |
| X med prickar, § 10 | Befintliga hus på prickmark får byggas om för bostad efter prövning |
| Genomförandetid | Planen är från före 1987 och har ingen löpande genomförandetid. Staden kan ändra den utan ersättningsskyldighet. |

Villakvarteren längs Kongahällavägen är märkta BFI 4,5 på plankartan. Om just tomt 138:3 också har prickmark eller X har jag inte kunnat se säkert i den skannade kartan (A). Med en tomt på 1 465 m² betyder fjärdedelsregeln högst cirka 366 m² byggnadsarea.

### Fler planeringsdokument i Göteborg, verifierade 2026-11-25

Detaljplanen är sista steget i en kedja. Staden följer översiktsplan, fördjupningar, program och sist detaljplan. Innan en plan startar passerar den planbesked och stadens årliga startplan. De tidiga stegen är därför de som ger köparen förvarning, ofta flera år innan något syns i en detaljplan.

| Dokument | Vad det säger köparen | Åtkomst | Maskinläsbart? |
| --- | --- | --- | --- |
| Översiktsplan (antagen) och fördjupningar (FÖP) | Vad staden vill med marken långsiktigt: förtätning, nya vägar, kollektivtrafik, grönstråk, hänsyn som radon och buller. | WMS `https://services.sbk.goteborg.se/oversiktsplan-v4/wms`, 154 frågbara lager med stadens rekommendationstext per område | Ja, GetFeatureInfo per punkt ger text |
| Program (t.ex. Program för Torslanda centrum, 2019) | Riktning för ett större område innan detaljplaner tas fram. | PDF i nämndhandlingar på www4.goteborg.se | Nej |
| Planbesked | Att en fastighetsägare har ansökt om att få bygga och om staden sagt ja. Tidigaste signalen. | Nämndhandlingar och protokoll från stadsbyggnadsnämnden | Nej |
| Startplan (årlig) | Vilka planer staden startar nästa år, med projektlista och karta. [Startplan 2026](https://www4.goteborg.se/prod/Intraservice/Namndhandlingar/SamrumPortal.nsf/F01A844A8AEE9957C1258D5D003198EE/$File/03%20Rapport.pdf) (2025-11-18): 26 planer, cirka 2 700 bostäder. Torslanda är en av tre utpekade tyngdpunkter. | PDF med bilagor | Nej |
| Pågående detaljplaner | Samråd och granskning med alla utredningar (buller, geoteknik, trafik, MKB). | Projektsidor och PDF:er på goteborg.se och www5.goteborg.se | Nej |
| Markanvisningar | Att kommunal mark ska säljas eller upplåtas för byggande. | Lista på goteborg.se, beslut i exploateringsnämnden | Nej |
| Trafik- och infrastrukturbeslut | Nya vägar och kollektivtrafik, med tidplan och budget. | Exploaterings- och stadsmiljönämndens handlingar, Trafikverket | Nej |
| Bygglov | Vad grannar fått bygga eller sökt om. | Kungörelser i Post- och Inrikes Tidningar. Stadens diarium via begäran. Ingen öppen datatjänst hittad. | Delvis |
| Kulturmiljö, bevarandeprogram, byggnader före 1930 | Begränsningar för om- och tillbyggnad. | WMS på geodata-external.sbk.goteborg.se (sbf-kulturmiljo-v2, sbf-byggnad-nybyggnadsar-v1) | Ja |
| Riksintresse totalförsvaret, strandskydd, naturreservat | Bullerpåverkan och byggbegränsningar. | WMS från staden, Försvarsmakten och Länsstyrelsen | Ja |
| Trafikbuller (beräknat 2018, 2021, 2023) | dB(A) vid fasad och på tomt. | WMS på geoserverextern.miljoforvaltningen.goteborg.se (inte öppnad i miljön än) | Ja |

Kartlagren hittades i konfigurationen till stadens kartor på karta.goteborg.se, som också har kartor för buller, PFAS, vattenskyddsområden och historiska kartor. Nämndhandlingarna har ingen sökbar datatjänst, så portalen behöver bevaka dem och tolka PDF:erna.

### Det som berör Vildkaprifolen 5

| Dokument | Innehåll | Skede | Källa |
| --- | --- | --- | --- |
| Översiktsplan | "Ytterstadens större samhällen", blandad stadsbebyggelse. Staden ser "potential för komplettering och förtätning" och vill ha blandade boende- och upplåtelseformer. | Antagen | ÖP-tjänsten, avläst vid adresspunkten |
| Radon | Normalriskområde, berg och jord. | ÖP-underlag | ÖP-tjänsten |
| Detaljplan för Hangarvägen m.fl. | 1 000–1 200 bostäder och verksamheter i Torslanda centrum. Uppdraget utvidgades till bland annat del av Kongahällavägen (Röd 2:46, fastigheten direkt intill tomten). | Analysfas, inriktningsbeslut juni 2023, SBF-2023-00763 | [Tjänsteutlåtande 2023-06-15](https://www4.goteborg.se/prod/intraservice/namndhandlingar/samrumportal.nsf/403E4EDF3418D1B1C12589CF003C3BB3/$File/TU%20inriktning%20DP%20Hangarvagen.pdf) |
| Tvärförbindelse i Torslanda | Ny väg från Kongahällavägen till Torslandavägen för att avlasta Kongahällavägen. 234 miljoner kronor. Trafikstart tidigast 2028. | Granskning augusti–september 2024, SBF-2023-00690 | [Granskningsaffisch](https://www5.goteborg.se/prod/fastighetskontoret/etjanst/planobygg.nsf/vyFiler/Lilleby%20-%20Tv%C3%A4rf%C3%B6rbindelse%20i%20Torslanda-Plan%20ut%C3%B6kat%20f%C3%B6rfarande%20-%20granskning-Utst%C3%A4llningsaffisch/$File/Tv%C3%A4rf%C3%B6rbindelse%20Torslanda%20Granskning%20vers.2.pdf), [exploateringsnämnden 2024-10-21](https://www4.goteborg.se/prod/intraservice/namndhandlingar/samrumportal.nsf/42FD2D8FED4E436EC1258BB30024E229/$File/10_EXN241021.pdf) |
| Bostäder och handel vid Torslanda torg | 250–300 bostäder och handel, upp till 8 våningar. | Kompletterande samråd efter samråd 2024 | Planhandlingar på www5.goteborg.se |
| Program för Torslanda centrum | Ramen för Hangarvägen och torget, med ett nytt resecentrum i Amhult. | Godkänt 2019-06-18 | Nämns i tjänsteutlåtandet ovan |

Om Hangarvägsplanen har antagits, och om tvärförbindelsen vunnit laga kraft, har jag inte kunnat bekräfta. Trafikbuller för adressen är inte hämtat än.

### Koppla annons till fastighet automatiskt

För Vildkaprifolen 5 stämmer kopplingen. Adresspunkten ligger i RÖD 138:3, och fastighetens yta i stadens karta är 1 464,7 m² mot annonsens 1 464,6 m². Så här kan portalen göra samma kontroll för alla annonser:

1. Läs adress, tomtarea och boarea ur annonsen.
2. Slå upp adresspunkten i stadens adress-WFS (eller Lantmäteriets adressdata för andra kommuner).
3. Hämta fastigheten som innehåller punkten via fastighetskartans WMS (GetFeatureInfo), med beteckning och geometri.
4. Räkna fastighetens area och jämför med annonsens tomtarea. En avvikelse under 1 % ger "verifierad". Större avvikelser flaggas för manuell kontroll, t.ex. när adresspunkten ligger på gatan eller fastigheten är samfällighet.
5. För bostadsrätter jämförs i stället föreningens namn med ägaren eller med föreningens årsredovisning, eftersom tomtarea saknas.

Utanför Göteborg behövs Lantmäteriets fastighetsindelning och adresser, som är öppna data men kräver konto på Geotorget (A).

### Närservice

Avstånden är fågelvägen från adresspunkten, inte gångväg.

| Typ | Närmast | Avstånd | Källa |
| --- | --- | --- | --- |
| Grundskola F-6 | Noleredsskolan F-6, Gamla Hjuviksvägen 5 | 660 m | Skolverkets skolenhetsregister |
| Grundskola 7-9 | Torslandaskolan 7-9, Hembygdsgatan 2 | 680 m | Skolverket |
| Grundskola F-6, alternativ | Torslandaskolan F-6, Runskriftsgatan 8 | 900 m | Skolverket |
| Hållplats | Torslanda Torg (GUL, SVART, 23, 121) | 220 m | Trafikkontorets öppna data |
| Hållplats | Nordhagsvägen (samma linjer) | 320 m | Trafikkontoret |

Linjerna är matchade mot linjesträckningar nära hållplatsen, så de bör stämmas av mot Västtrafiks tidtabell (A). Närmaste förskolor enligt stadens "Hitta förskolor": Låkebergsgatan 10 (360 m), Kålhagen 3–7 (370 m), Torslanda Torg 8 (410 m) och Rödluvans förskola på Torslanda Idrottsväg 21 (590 m). Närmaste matbutiker enligt miljöförvaltningens register över livsmedelsobjekt: Merkado (310 m) och Hemköp (350 m) vid Torslanda torg, Willys Hemma (1,1 km) och ICA Maxi (1,2 km). Bad saknas än.

| Källa för närservice | Åtkomst | Kostnad |
| --- | --- | --- |
| [Skolverkets skolenhetsregister](https://api.skolverket.se/skolenhetsregistret/v2) | Öppet REST-API med koordinater, ingen nyckel. Omfattar inte förskolor. | Gratis |
| [Göteborgs Stad, Hitta förskolor](https://goteborg.se/wps/portal/start/forskola-och-utbildning/forskola-och-pedagogisk-omsorg/hitta-forskolor) | 509 förskolor, kommunala och fristående, med koordinater i sidornas schema.org-data. Ingen API, så sidorna måste läsas. | Gratis |
| Trafikkontoret Göteborg, hållplatser och linjer | WFS `https://open.geodata.tkgbg.se/wfs` (vt:hallplatsomraden, vt:alla\_linjer) | Gratis |
| Västtrafik / Trafiklab | API för avgångar och turtäthet, kräver nyckel | Gratis |
| Göteborgs öppna data-API (data.goteborg.se) | Badplatser och servicekatalog, kräver gratis app-nyckel | Gratis |
| OpenStreetMap (Overpass) | Butiker, bad, vård. ODbL-licens kräver källhänvisning. | Gratis, egen server rekommenderas i drift |

### Miljö och risk vid Vildkaprifolen 5

Värdena är beräknade eller avlästa ur myndigheternas kartdata för RÖD 138:3, inte uppmätta på platsen.

| Ämne | Uppgift | Jämförelse | Källa |
| --- | --- | --- | --- |
| Vägtrafikbuller, ekvivalent (2023) | 55–60 dBA vid gatan, 50–55 dBA mitt på tomten. Husfasaden har 59–64 dBA mot gatan och 43–48 dBA på baksidan. | Riktvärde för nya småhus: 60 dBA vid fasad, 50 dBA vid uteplats | Miljöförvaltningen, bullerberäkningar |
| Vägtrafikbuller, maxnivå (2021) | 70–75 dBA vid gatan, 65–70 dBA mitt på tomten | Riktvärde 70 dBA vid uteplats | Miljöförvaltningen |
| Flygbuller | Inget flygtillståndsområde och inget av försvarets påverkansområden inom 2 km | – | Översiktsplanen |
| Luft, kvävedioxid (2023) | 8 µg/m³ årsmedel, 19 µg/m³ dygn (98-percentil) | Miljökvalitetsnorm 40 respektive 60 | Miljöförvaltningen, Ren stadsluft |
| Luft, PM10 (2023) | 10,6 µg/m³ årsmedel | Miljökvalitetsnorm 40 | Miljöförvaltningen |
| Skyfall | Tomten ligger inte i en skyfallsled. Närmaste led ligger cirka 50 m bort. | – | Översiktsplanen |
| Översvämning och höga vattenstånd | Närmaste riskområde cirka 1 km bort | – | Översiktsplanen |
| Skred och mark | Planbeskrivningen från 1979 anger att säkerheten mot jordskred är betryggande. Villorna längs Kongahällavägen står på lera, 3–11 m djup. Området ingår inte i SGI:s skredriskkartering längs Göta älv. | – | Planbeskrivning II-3540, SGI |
| Förorenad mark | Närmaste riskområde cirka 310 m bort | – | Översiktsplanens tillägg om förorenade områden |
| Radon | Normalriskområde | – | Översiktsplanen |

Allt utom skred hämtas från öppna kartjänster utan nyckel: `services.sbk.goteborg.se/oversiktsplan-v4/wms` och `geoserverextern.miljoforvaltningen.goteborg.se/geoserver/ows`. Den senare har också PFAS-provtagning och stadens register över livsmedelsobjekt, som ger matbutiker och apotek. För skred finns ingen frågbar tjänst för Torslanda, så portalen får läsa planens geotekniska avsnitt eller använda SGU:s jordartskarta (A).

## Grannkommuner (kartlagt 2026-11-27)

| Kommun | Öppen datatjänst | Vad som finns |
| --- | --- | --- |
| Partille | ArcGIS REST, `https://geodata.partille.se/arcgis/rest/services` (EPSG:3007, ingen nyckel) | Adresser, gällande detaljplaner med länk till plankarta och planbeskrivning, fastighetsgränser, förskolor, skolor, geotekniska utredningar, samhällsbyggnadsprojekt, kommungräns. Inte buller, luft, skyfall, radon, översiktsplan eller pågående detaljplaner. |
| Mölndal | Ingen. Webbkartan `karta.molndal.se` (Spatial Suite) har lager för adresser, gällande och pågående detaljplaner, skyfall, hållplatser och skolor, men inga öppna WMS-frågor, WFS eller nedladdningar. Skyfallskarteringen 2023 finns på dataportal.se. | Kräver att kommunen öppnar en tjänst eller lämnar ut data. |
| Kungälv | Ingen hittad. Webbkartan `kartor.kungalv.se` är också Spatial Suite. | Samma som Mölndal. |
| Hela landet | Lantmäteriets öppna data (adresser, fastighetsindelning, byggnader) via `api.lantmateriet.se` kräver ett gratis konto och nyckel. Västtrafiks hållplatser via Trafiklab kräver gratis nyckel. | Skulle ge adresser, fastigheter och hållplatser för alla kommuner på samma sätt. |

## Öppna frågor

- [ ] Ska portalen börja med en eller några pilotkommuner? Svar: Göteborg.
- [ ] Bostadsrätter, villor eller båda? Svar: båda, eftersom planändringar påverkar båda lika.
- [ ] Är det okej att första versionen inte visar annonsinnehåll, bara länkar till annonsen?
- [ ] Ska portalen vara gratis för köpare? Det påverkar vilka avtal och avgifter hos Lantmäteriet som är rimliga.
- [ ] Finns det kontakter hos mäklare eller mäklarsystem som kan ge annonsdata via avtal?

## Nästa steg i kartläggningen

- [ ] Läsa Hemnets användarvillkor (sidan gick inte att hämta nu).
- [ ] Bekräfta licens, API-format och kostnad för NGP och Lantmäteriets öppna data på Geotorget.
- [ ] Kontrollera alla rader markerade (A) mot myndigheternas egna sidor.

## Källor

Lästa sidor:

- [Booli, användarvillkor (version 4, 30 juni 2026)](https://www.booli.se/integritet/anvandarvillkor)
- [Booli, utgivaransvar](https://www.booli.se/integritet/utgivaransvar)
- [Boverket, digital detaljplaneinformation](https://www.boverket.se/sv/PBL-kunskapsbanken/detaljplan/planbestammelser/foreskrift-om-detaljplan/digital-information/)
- [Boverket, ÖP-katalogen](https://www.boverket.se/sv/om-boverket/oppna-data/api-for-op-katalogen/)
- [Lantmäteriet, High Value Data](https://lantmateriet.se/en/geodata/geodata-products/open-data/high-value-data-hvd)
- [Lantmäteriet, frågor och svar om detaljplaner i NGP (maj 2025)](https://www.lantmateriet.se/globalassets/temawebbar/ngp/datamangder/fragor-och-svar-om-detaljplaner-i-ngp-goteborg.pdf)
