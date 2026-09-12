# Jolshiri Smart City — Flutter Frontend

A Flutter frontend for the Jolshiri Smart City Mobile Application, built from
the finalized features, ER diagram, UI page list, and API list in the
CSE 464 SDP-II report.

## Requirements

- Flutter 3.27 or newer (uses `Color.withValues`, `CardThemeData`, Material 3)
- Dart 3.x (bundled with Flutter)

## Getting started

```bash
cd jolshiri_app
flutter pub get
flutter run
```

No API keys or backend are required to run the app in offline demo mode —
all screens fall back to `lib/data/mock_data.dart` when the backend is
unreachable.

## Completed features

### 1. Google Sign-In (SSO)
`lib/screens/auth/login_screen.dart` + `lib/services/google_auth_service.dart`

The login screen has a **Continue with Google** button that:
1. Calls `GoogleAuthService.signInAndGetFirebaseIdToken()` — gets a Firebase ID token via `google_sign_in` + `firebase_auth`.
2. POSTs it to `POST /api/auth/sso/google` on the backend, which verifies it with the Firebase Admin SDK.
3. Returns a Jolshiri JWT and navigates to the correct role dashboard.

**Setup required** (see `README.md` → "Google Sign-In setup" section below for full steps):
- Enable Google auth in the Firebase console (`jolshiri-49197` project).
- Add SHA-1/SHA-256 fingerprints → re-download `google-services.json`.
- Set `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` in backend `.env`.

### 2. Signup OTP Email Verification
`lib/screens/auth/signup_screen.dart` + `lib/screens/auth/verify_signup_otp_screen.dart`

When a new user signs up, the backend creates the account as **unverified** and emails a 6-digit OTP.
The app immediately navigates to `VerifySignupOtpScreen`:
- Six individual digit boxes with auto-focus on each entry.
- Auto-submits when the 6th digit is entered.
- **Resend code** button with a 30-second cooldown.
- In dev mode (no Gmail configured), the OTP is shown in a snackbar for testing.

### 3. Forgot Password / Email Verification / Password Reset
`lib/screens/auth/forgot_password_screen.dart`

Three-step flow:
1. **Enter email** → `POST /api/auth/forgot-password` → OTP sent via Gmail (or printed to console in dev).
2. **Enter 6-digit OTP** — same UI as signup verification.
3. **Set new password** → `POST /api/auth/reset-password`.

### 4. Army Oversight — Security Heatmap (OpenStreetMap + coloured circles)
`lib/screens/admin/army_oversight_dashboard.dart`

The **Security Heatmap** tab uses `flutter_map` with free OpenStreetMap tiles —
no API key needed. Incident clusters are displayed as coloured filled circles:
- **Red circles** — Severe blocks (≥ 70 % of max incident count).
- **Orange/brass circles** — Moderate blocks (40–69 %).
- **Green/teal circles** — Mild blocks (< 40 %).

Circle radius scales with incident count. Tapping a circle or a block row in
the summary list below the map highlights it and shows a detail card with an
**Open in Maps** deeplink (launches Google Maps externally via `url_launcher`).
Backend data is loaded from `GET /api/security-reports/heatmap`; falls back to
static mock clusters when the server is unreachable.

### 5. AI Chatbot
`lib/screens/chatbot/chatbot_screen.dart`

The chatbot POSTs to `POST /api/chatbot/query` with the user message plus a
live context summary (recent notices, available providers, current listings).
The backend tries AI providers in this order:
- **Google Gemini** (fastest/cheapest) — set `GEMINI_API_KEY` in backend `.env`.
- **OpenAI GPT-4o-mini** — set `OPENAI_API_KEY`.
- **Anthropic Claude Haiku** — set `ANTHROPIC_API_KEY`.
- **Keyword fallback** — no key needed; handles common Jolshiri queries locally.

### 6. Soil Testing Full Flow
`lib/screens/resident/construction_lifecycle_screen.dart` +
`lib/screens/admin/jolshiri_management_dashboard.dart`

The complete soil testing workflow:

| Step | Who | What happens |
|------|-----|--------------|
| 1 | Resident | Taps **Apply for soil testing** inside Build Track → Permits section |
| 2 | Backend | Creates `SoilTestApplication` with status `REQUESTED` |
| 3 | Authority | Sees request in Permits tab → taps **Grant permit** |
| 4 | Backend | Moves status to `PERMIT_GRANTED`, raises a `PaymentRecord` (৳ 2,000) |
| 5 | Resident | Sees **Permit granted** badge + **Pay now** button → tapped → goes to Payments screen |
| 6 | Resident | Pays from Payments screen → `POST /api/payments/:id/pay` |
| 7 | Backend | Settles payment as `PAID`, auto-moves soil test to `PAYMENT_DONE`, notifies all Authority admins |
| 8 | Authority | Sees **Testing completed** button in Permits tab |
| 9 | Authority | Taps **Testing completed** → status moves to `COMPLETED` |
| 10 | Resident | Receives push notification: *"Your soil testing document is ready to be received"* |

## Design identity

Jolshiri is an Army-run cantonment township built around parkland, a lake,
and a golf course, so the UI leans on parade-ground green and brass-insignia
gold on a warm, plan-drawing cream background. Tokens live in
`lib/theme/app_theme.dart`.

## Project structure

```
lib/
  main.dart                     App entry point
  theme/app_theme.dart          Color, type, and component tokens
  models/app_models.dart        Data models mirroring the ER diagram
  data/mock_data.dart           In-memory mock data (swap for API calls)
  widgets/common.dart           Shared UI pieces (badges, pills, cards)
  services/
    api_client.dart             HTTP client (auth headers, error handling)
    api_config.dart             Base URL + AuthSession
    backend_repository.dart     All backend API calls mapped to Dart types
    google_auth_service.dart    Google Sign-In → Firebase ID token
    fcm_service.dart            Firebase Cloud Messaging push setup
    sync_service.dart           Post-login data sync (MockData ← backend)
  screens/
    auth/                       Login, Sign-up, OTP verify, Forgot password
    admin/                      Army oversight (heatmap), Jolshiri Mgmt, Moderator
    resident/                   Complaints, Construction/Build track, Meetings,
                                Payments, Soil testing, Reviews
    chatbot/                    AI chatbot screen
    ...
```

## Google Sign-In setup

The code path is correct: `google_sign_in` gets a Google account, then
`GoogleAuthService` exchanges it for a **Firebase** ID token via `firebase_auth`,
and that token is sent to `POST /api/auth/sso/google`, which the backend
verifies with the Firebase Admin SDK. What's still needed is Firebase-console
configuration — without it you'll see `PlatformException(sign_in_failed,
ApiException: 10)` on Android or a silent failure on iOS:

1. In the [Firebase console](https://console.firebase.google.com/), open
   the `jolshiri-49197` project → **Authentication → Sign-in method** →
   enable **Google**.
2. **Android** — Project settings → your Android app
   (`com.example.jolshiri_smart_city`) → add your **SHA-1** (and SHA-256)
   signing fingerprints for both the debug keystore
   (`./gradlew signingReport` from `android/`) and your release keystore.
   Re-download `google-services.json` afterwards and replace
   `android/app/google-services.json` — the current one has an empty
   `oauth_client` array, which is exactly what triggers `ApiException: 10`.
3. **iOS** — add an iOS app in the same Firebase project with bundle ID
   `com.example.jolshiriSmartCity`, download `GoogleService-Info.plist`,
   and add it to `ios/Runner/` (via Xcode so it's included in the target).
   Then add its `REVERSED_CLIENT_ID` as a URL scheme in
   `ios/Runner/Info.plist` under `CFBundleURLTypes`.
4. Set `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and
   `FIREBASE_PRIVATE_KEY` in the backend's `.env` (a service-account key
   from Project settings → Service accounts → Generate new private key) —
   without these the backend returns 503 "Google Sign-In is not configured".
