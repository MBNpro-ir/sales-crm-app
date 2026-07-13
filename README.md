# Sales CRM Windows App — 0.0.3-alpha

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

## Automated alpha pre-release

`.github/workflows/prerelease.yml` runs on every push to `main` (or from the
Actions **Run workflow** button). It analyzes, tests, and builds the Windows
application and the standalone Windows updater, then refreshes the GitHub
pre-release `v0.0.3-alpha` with the latest ZIP, updater executable, update
manifest, and SHA-256 checksums. The workflow caches the Flutter SDK and Dart
Pub cache, keyed by the platform, Flutter channel, and `pubspec.lock`.

The application contains no pre-seeded CRM records or sample account. Its first
login requires an administrator created by the server installer.

## User preferences

Settings include light/dark/system mode, five accent colors, collapsible left
navigation, text scaling, high contrast, bold text, large touch targets,
reduced motion, and automatic update checks. The app downloads a verified
release package only after the user confirms installation.
