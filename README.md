# TrackIT Mobile (Flutter)

Companion **Android/iOS** app for the existing Ionic + Angular TrackIT web application.

The web app in the repo root is **unchanged**. This folder is a separate Flutter project.

## Bottom navigation (reference-style)

| Position | Student | Officer |
|----------|---------|---------|
| Far left | Dashboard | Dashboard |
| Inner left | Events | Events |
| **Center (+)** | **QR scanner** | **QR scanner** |
| Inner right | Organization officers | Message |
| Far right | Profile | Profile |

The center **+** button opens the event QR scanner (`TRACKIT-EVENT-{id}`), matching the web attendance flow.

## Phase 1 (current)

- Flutter project scaffold under `/mobile`
- Student & officer login (no admin mobile features)
- Role-based route guards
- Student dashboard (mirrors `/home`)
- Officer dashboard (mirrors `/dashboard` officer view)
- Local data layer using the same storage keys and seed data as the web app

## Not in Phase 1

Events list, QR attendance, voting, messages, reports, profile settings screens — planned for later phases.

## Run

```bash
cd mobile
flutter pub get
flutter run -d chrome
```

Other targets:

```bash
flutter run              # Default device (phone/emulator if connected)
flutter run -d windows   # Windows desktop
flutter devices          # List available devices
```

**Chrome (web)** is supported for development and testing. The app uses the same student/officer flows; QR scanning uses the browser camera when you allow permission.

### Troubleshooting Chrome / `build\flutter_assets` locked

If you see `Flutter failed to delete a directory at build\flutter_assets`:

1. Close any Chrome tab opened by a previous `flutter run`
2. From the `mobile` folder, run:
   ```powershell
   .\run-chrome.ps1
   ```
   Or manually:
   ```powershell
   cmd /c "rmdir /s /q build"
   flutter run -d chrome
   ```
3. **OneDrive** often locks the `build` folder because this project is under `OneDrive\Desktop`. Pause OneDrive sync while developing, or copy the project to a non-synced path (e.g. `C:\dev\TrackIT`).

Always run Flutter commands from the **`mobile`** folder (where `pubspec.yaml` is), not the repo root.

## Demo accounts

| Role | Login | Password |
|------|-------|----------|
| Student | `DEMO202601` | `DemoAttendee1` |
| Officer | `demo.officer@trackit.local` | `DemoOfficer1` |
| Officer (President) | `john.delacruz@trackit.local` | `Faithturtogo01` |
| Officer (Vice President) | `renazmi29@gmail.com` | `Lanceenri29` |

## Architecture

```
lib/
├── config/          # Theme, storage keys, role access (from role-access.config.ts)
├── data/            # Seed data (from Angular services)
├── models/          # Dart models mapped from TypeScript interfaces
├── services/        # Auth, storage, API stub, events, dashboard
├── routes/          # go_router + guards
├── screens/         # student/ and officer/ feature screens
└── widgets/         # Reusable UI components
```

## Backend readiness

`ApiService` currently reads/writes via `SharedPreferences` using the same keys as browser `localStorage`. Replace method bodies with HTTP calls when Firebase/Node backend is connected.

## Web app mapping

| Web | Mobile Phase 1 |
|-----|----------------|
| `StudentAuthService` | `student_auth_service.dart` |
| `OfficersService` (login) | `officer_auth_service.dart` |
| `AccessControlService` | `role_service.dart` + `permission_service.dart` |
| `role-access.config.ts` | `config/role_access.dart` |
| `/home` | `/student/dashboard` |
| `/dashboard` (officer) | `/officer/dashboard` |
