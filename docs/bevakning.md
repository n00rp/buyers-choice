# Bevakning av adresser

Köparen kan bevaka en adress och få veta när något nytt händer i närheten: ett nytt planarbete, när ett planarbete går till samråd, granskning, antagande eller laga kraft, när det går att lämna synpunkter, eller när en ny plan börjar gälla.

## Så fungerar det

```
GitHub Actions, varje morgon 06.30
  └─ scripts/bevakning/hamta.py   hämtar läget, jämför med gårdagen
       ├─ bevakning/lage.json               senaste läget
       ├─ portal/bevakning/planarbete.json  pågående och avslutat planarbete med läge
       └─ portal/bevakning/handelser.json   händelser det senaste året
  └─ scripts/bevakning/skicka.py  mejlar nya händelser inom vald radie
       └─ bevakning/skickat.json            vad som redan skickats (bara kontrollsummor)
  └─ committar ändrade filer till repot
```

Portalen har inget eget serverstöd. Under **Inför köpet › Bevakning** visas pågående planarbete och händelser runt adressen. Knappen **Bevaka adressen** sparar adressen i webbläsaren, och nya händelser markeras nästa gång köparen öppnar sidan.

## Källor

| Data | Källa |
| --- | --- |
| Planarbete: namn, skede (processteg), koordinat, tider för synpunkter, stadens uppdateringsnotiser | Göteborgs Stads databas för plan- och byggprojekt, `www5.goteborg.se/prod/fastighetskontoret/etjanst/planobygg.nsf`. Det är samma uppgifter som visas på projektsidorna på goteborg.se. Vyerna läses som XML med `?ReadViewEntries`. |
| Gällande planer | Stadsbyggnadskontorets WFS `planer-v3` |

Databasen är inte dokumenterad som öppen datatjänst, men den är öppen utan inloggning och används av stadens egna webbsidor. Om staden ändrar den kan skriptet sluta fungera, och då syns det som ett fel i Actions.

Cirka 5 procent av planarbetena saknar koordinat hos staden. För dem letas gatunamnet i projektets namn upp i adressregistret ("… vid Karl Johansgatan 130"). De märks "cirka" i portalen.

**Bygglov ingår inte.** Göteborg publicerar inte beviljade bygglov som öppna data, och Post- och Inrikes Tidningar har inget öppet API.

## Sätta igång mejlen

Mejlen skickas med vanlig SMTP. Lägg in följande under **Settings › Secrets and variables › Actions** i repot:

| Namn | Typ | Exempel |
| --- | --- | --- |
| `BEVAKNINGAR` | Secret | `[{"mejl": "kopare@example.se", "adress": "Vildkaprifolen 5", "radie": 1000}]` |
| `SMTP_HOST` | Secret | `smtp.gmail.com` |
| `SMTP_PORT` | Secret | `465` |
| `SMTP_USER` | Secret | ditt Gmail-konto |
| `SMTP_PASSWORD` | Secret | ett appösenord från Google-kontot (Säkerhet › Appösenord, kräver tvåstegsverifiering) |
| `MAIL_FROM` | Secret | t.ex. `Buyers Choice <ditt.konto@gmail.com>` |
| `PORTAL_URL` | Variable (valfri) | adressen där portalen ligger, för länkar i mejlet |

Mejladresserna ligger bara i hemligheten, aldrig i repot. Utan `SMTP_HOST` skickas inget.

Första gången en bevakning körs får köparen ett välkomstmejl med pågående planarbete i närheten. Därefter kommer ett mejl bara när något nytt har hänt. Mejlet avslutas med att man svarar för att sluta bevaka. Ta då bort raden ur `BEVAKNINGAR`.

## Prova

```bash
python3 scripts/bevakning/hamta.py
echo '[{"mejl":"test@example.se","adress":"Kungsportsavenyen 10","radie":1500}]' > /tmp/bev.json
python3 scripts/bevakning/skicka.py --bevakningar /tmp/bev.json --torrkorning
# mejlen hamnar i utskick/ som .html och .txt
```

I GitHub kan arbetsflödet **Bevakning** köras för hand (Actions › Bevakning › Run workflow). Kryssa i *torrkörning* för att få mejlen som en nedladdningsbar fil i stället för att skicka dem.

## Nästa steg

- Självanmälan i portalen, med bekräftelse och avanmälan via länk. Kräver en liten backend.
- Bygglov, om staden eller PoIT öppnar en källa.
