# Detaljplaner från Lantmäteriets geodataplattform (NGP)

NGP samlar kommunernas digitala detaljplaner. Den 1 januari 2026 fanns planer från 246 kommuner, cirka 15 000 planer, mest sådana som påbörjats från 2022. Datan är gratis och har licensen CC0, även för kommersiellt bruk.

`scripts/ngp/hamta_ngp.py` hämtar planerna per kommun och skriver `tackning.csv`, som visar hur många planer varje kommun har i NGP och hur många av dem som vann laga kraft före 2022. Det är måttet på hur stor luckan av äldre planer är.

## Konto

1. Skapa ett konto som privatperson på [Geotorget](https://geotorget.lantmateriet.se/). Användarnamnet är din e-postadress.
2. Logga in, välj Nationella geodataplattformen och klicka Ansök under Bli konsument. Godkänn användningsvillkoren.
3. Klart. Som privatperson används samma användarnamn och lösenord mot API:et (Basic auth). OAuth-nycklar från [API-portalen](https://apimanager.lantmateriet.se/store/) fungerar också.

Instruktionerna finns hos [Lantmäteriet](https://www.lantmateriet.se/sv/nationella-geodataplattformen/konsument/bli-konsument-som-privatperson/).

## Köra

NGP svarar bara på anrop inom EU/EES. Skriptet går därför inte att köra i molnmiljön eller på GitHubs vanliga körare, utan på en dator i Sverige. Det behöver bara Python, inga extra paket.

```powershell
$env:LM_ANVANDARE = "din@epost.se"
$env:LM_LOSENORD = "ditt lösenord"
python scripts\ngp\hamta_ngp.py
```

Resultatet hamnar i `ngp-data/` (ignoreras av git). Tester mot en låtsasserver: `python -m unittest discover scripts/ngp`.
