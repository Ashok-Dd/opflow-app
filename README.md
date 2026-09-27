# OPflow app (Flutter)

Patient + doctor app. Two modes, chosen when building:

| Mode | Command | Data |
|---|---|---|
| Demo (default) | `flutter run` | Built-in sample doctors and bookings; nothing leaves the phone. Used by the widget tests and `deploy.bat`. |
| Real server | `flutter run --dart-define=BACKEND=api` | The OPflow API (`../backend`). |

API address: the Android emulator reaches the laptop at `http://10.0.2.2:3000` (the default). A real phone on the same
Wi-Fi needs the laptop's address, and a **debug** build (release builds only allow https):

```bash
flutter run --dart-define=BACKEND=api --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

With a local server (`APP_ENV=local`), the stand-ins are used:
- **Patient login:** any phone number and any 6-digit code (Firebase is not set up yet).
- **Payment:** the app's payment sheet ("make it fail" works too) uses the server's stand-in Checkout.

The real Cashfree checkout opens automatically once the server has Cashfree keys.
Demo doctor (after `npm run seed:demo` in `backend/`): **OPD-10234 / demo1234**, which asks for a new password.

## How it connects (screens unchanged)

- `lib/data/api.dart`: the HTTP client. Tokens are kept in secure storage, a 401 triggers one shared refresh,
  writes carry an idempotency key, and every error becomes simple English.
- `lib/data/remote.dart`: loads the catalog, hospitals and doctors into the lists the screens already read
  (`MockData`), and the hours of each day.
- `lib/state/*_api.dart`: the patient and doctor stores on the server (same methods as the demo stores):
  - bookings, payments and change of time;
  - the doctor console, with stale-screen protection;
  - timings, leave, emergency status, Pause bookings, earnings, and photo upload.
- Live line: checked every 10–15 seconds.

## Tests

```bash
flutter test                                    # 12 screen tests (demo mode)
flutter test test/api_connection_test.dart --dart-define=API_TEST=http://localhost:3000
                                                # the app's stores against a real local API (seeded demo data)
```

## Test build for a phone (small, talks to the laptop server)

```bash
flutter build apk --profile --dart-define=BACKEND=api --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

About 33 MB; a debug build is about 150 MB and often drops over USB. The laptop server's address is `devServer` in
`lib/data/config.dart`.

## Push notifications (Android + iPhone)

Firebase project `chat-fe0b8`. The files are `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
(already added to the Xcode project). The code is `lib/data/push.dart`, API mode only. After login it asks permission,
sends the phone's token to the server (`POST /v1/me/devices`), and opens the booking when a notification is tapped.
Logging out stops pushes to that phone.

iPhone also needs:
- an APNs key (`.p8`) from the Apple Developer account, uploaded in Firebase → Project settings → Cloud Messaging;
- a Mac with Xcode to build. Push capability, background mode and iOS 15 are already set.

## Still to do before the stores

- Firebase phone login: send the Firebase token instead of the local stand-in (needs Firebase's Blaze plan).
- WebSocket live updates (polling works meanwhile).
