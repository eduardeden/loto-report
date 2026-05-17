# Loto Report

Aplicatie iOS (SwiftUI + WidgetKit) pentru monitorizarea valorii NETE in EUR a reportului pentru:
- Loto 6/49
- Joker

## Ce include proiectul

- `automation/`:
  - scraping `loto.ro` (Loto 6/49 + Joker)
  - curs EUR/RON din BNR XML
  - calcul impozit progresiv + NET
  - generare `docs/report.json`
- `.github/workflows/`:
  - `jackpot-update.yml` (joi + duminica 22:07 ora Romaniei)
  - `fx-daily.yml` (zilnic 13:17 ora Romaniei)
- `ios/`:
  - app SwiftUI
  - widget configurabil pe joc (6/49 sau Joker)
  - cache App Group + ETag
- `LotoReport.xcodeproj`:
  - proiect Xcode generat (gata de build/archive)

## Build status local

Verificat local cu succes:
- `xcodebuild ... build` (iOS Simulator) -> succes
- `xcodebuild ... archive` (generic iOS device, fara semnare) -> succes
- `python -m pytest automation/tests` -> toate testele trecute

## Nume aplicatie si icon

- Nume app: `Loto Report`
- Icon app: generat din `unnamed.png` in `ios/LotoReport/Assets.xcassets/AppIcon.appiconset`

## Cerinte pentru IPA final

Pentru export IPA semnat, trebuie configurat in Xcode:
1. `DEVELOPMENT_TEAM` valid (Apple Developer Team).
2. Signing automatic/manual pentru:
   - `LotoReport`
   - `LotoReportWidget`
3. Bundle IDs (daca vrei altele decat cele implicite):
   - `com.eduardcramaroc.LotoReport`
   - `com.eduardcramaroc.LotoReport.Widget`
4. App Group activ pentru ambele target-uri:
   - `group.com.eduardcramaroc.LotoReport`

## Endpoint JSON productie

In `ios/Shared/ReportConfig.swift` seteaza URL-ul real pentru GitHub Pages:
- `https://<username>.github.io/<repo>/report.json`

Pana la setarea URL-ului de productie, app-ul foloseste fallback local:
- `ios/Shared/Resources/BootstrapReport.json`

## Comenzi utile

### Regenerare proiect Xcode (daca modifici `project.yml`)
```bash
cd '/Users/eduardcramaroc/Edi Loto'
xcodegen generate
```

### Build simulator
```bash
cd '/Users/eduardcramaroc/Edi Loto'
xcodebuild -project LotoReport.xcodeproj -scheme 'Loto Report' -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

### Archive release (fara semnare)
```bash
cd '/Users/eduardcramaroc/Edi Loto'
xcodebuild -project LotoReport.xcodeproj -scheme 'Loto Report' -configuration Release -destination 'generic/platform=iOS' -archivePath '/Users/eduardcramaroc/Edi Loto/build/LotoReport.xcarchive' archive CODE_SIGNING_ALLOWED=NO
```
