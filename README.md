# Sales CRM Windows App — 0.0.1-alpha

Private Flutter desktop application for Persian sales teams. The interface is
RTL, uses bundled Vazirmatn Farsi-Digits, presents Jalali dates, and keeps
changes locally until they are synchronized with the CRM API.

## Run in Windows debug mode

```powershell
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Start the API and web administration panel first with the repository-root
`scripts/windows/manage-local.ps1` manager.

## Build a release

```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://crm-api.example.com/api/v1
```

The application contains no pre-seeded CRM records or sample account. Its first
login requires an administrator created by the server installer.

## User preferences

Settings include light/dark/system mode, five accent colors, collapsible left
navigation, text scaling, high contrast, bold text, large touch targets, and
reduced motion.
