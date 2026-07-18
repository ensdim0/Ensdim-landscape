# Play Store Release Guide (Flutter - Android)

This project is now configured with Android application ID:

- `com.bustanamari.app`

Use this guide each time you prepare a production release.

## 1) Bump app version

Update `version` in `pubspec.yaml` before every upload.

Example:

```yaml
version: 1.0.1+2
```

Rules:
- `1.0.1` is `versionName` (user-visible).
- `+2` is `versionCode` (must always increase).

## 2) Create upload keystore (one-time)

Run this once on your machine (adjust paths and values):

```powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\upload-keystore.jks" -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Keep this file private and backed up.

## 3) Configure `android/key.properties` (local only)

Create `android/key.properties` with:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:/Users/ElSaedy/upload-keystore.jks
```

Notes:
- Use forward slashes in `storeFile`.
- Do not commit this file.
- `android/.gitignore` already excludes it.

## 4) Install dependencies

```powershell
flutter pub get
```

## 5) Build release AAB

Use production Supabase values at build time:

```powershell
flutter build appbundle --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Output:

- `build/app/outputs/bundle/release/app-release.aab`

## 6) Verify before upload

- App launches with production backend.
- Login and role-based flows work.
- Camera/photo upload works.
- Location-dependent flows work.
- No debug banners/logging leaks in release.

## 7) Upload to Play Console

- Go to `Production` or `Internal testing`.
- Create new release.
- Upload `app-release.aab`.
- Add release notes.
- Review policy warnings and submit.

## 8) Play Console metadata checklist

Prepare these in advance:
- App name and short description.
- Full description.
- App icon (512x512).
- Feature graphic (1024x500).
- Phone screenshots.
- Privacy Policy URL.
- Data safety form.
- Content rating questionnaire.

## 9) Common release commands

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```
