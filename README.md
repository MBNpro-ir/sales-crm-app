# Sales CRM Windows App

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
$release = Get-Content .\release-version.json -Raw | ConvertFrom-Json
$buildName = $release.version -replace '-.*$', ''
flutter build windows --release --build-name=$buildName --dart-define=APP_VERSION=$release.version --dart-define=API_BASE_URL=https://crm-api.example.com/api/v1
```

`release-version.json` is the single release-version source. Change its one
`version` value; the workflow derives the numeric build name, matching tag,
Windows build metadata, package name, update manifest, Git tag, and release
title from it. The server workflow reads this same file from this repository.

## Automated alpha pre-release

`.github/workflows/prerelease.yml` runs on every push to `main` (or from the
Actions **Run workflow** button). It analyzes, tests, and builds the Windows
application and bundles a small PowerShell update launcher, then refreshes the
GitHub pre-release tag declared in `release-version.json` with the latest ZIP,
launcher, update manifest, and SHA-256 checksums. The CRM downloads the ZIP,
shows progress, verifies it, closes, installs, and relaunches automatically. It
pins Flutter `3.44.6` and uses the official
Flutter Action SDK/Pub cache keys, so the existing Windows cache is restored
until the SDK version or `pubspec.lock` changes.

The application contains no pre-seeded CRM records or sample account. Its first
login requires an administrator created by the server installer.

## Unified CRM workspace

Operational lists use the same configurable data grid with per-user saved
column order, visibility, width, frozen columns, multi-step sorting, advanced
filters, row selection, copying, pagination, and reusable filters. Reports open
in a configurable preview before printing and support summary or detailed
views, reusable personal/shared templates, and PDF, Excel, and CSV exports.
Customers also expose a chronological activity timeline. Customers, calls,
opportunities, quotes, orders, and invoices support synchronized attachments,
while important changes are recorded in the visible audit history.

## User preferences

Settings include light/dark/system mode, five accent colors, collapsible left
navigation, text scaling, high contrast, bold text, large touch targets,
reduced motion, and automatic update checks. The app downloads a verified
release package with progress only after the user confirms installation.
