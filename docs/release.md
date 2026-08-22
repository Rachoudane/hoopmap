# Publishing a release

## Prerequisites

- Flutter (stable channel; CI uses the version defined in `.github/workflows/ci.yml`).
- A production Android keystore. **No keystore ships with this repo** — see [Generating the keystore](#generating-the-keystore-once) below.
- The four environment variables listed below, set in the terminal that launches the build (never committed).

## Expected environment variables

| Variable | Contents |
|---|---|
| `HOOPMAP_KEYSTORE_PATH` | Absolute path to the keystore's `.jks` file |
| `HOOPMAP_KEYSTORE_PASSWORD` | Keystore password |
| `HOOPMAP_KEY_ALIAS` | Alias of the signing key inside the keystore |
| `HOOPMAP_KEY_PASSWORD` | That key's password (often the same as the keystore password) |

`tool/build_release.ps1` reads these four variables and generates `android/key.properties` from them before running the build. That file (like the keystore itself) is ignored by git (`.gitignore` and `android/.gitignore`) — never commit it.

To set them in a PowerShell session:

```powershell
$env:HOOPMAP_KEYSTORE_PATH = "C:\path\to\hoopmap-upload.jks"
$env:HOOPMAP_KEYSTORE_PASSWORD = "..."
$env:HOOPMAP_KEY_ALIAS = "upload"
$env:HOOPMAP_KEY_PASSWORD = "..."
```

## Generating the keystore (once)

A keystore isn't tied to a single app — the same one can sign several apps. If you already have a valid upload keystore for another Rachou Corp app, you can reuse it instead of generating a new one.

If no keystore exists yet:

```bash
keytool -genkey -v -keystore hoopmap-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Answer the prompts (name, organization, etc.) and choose a strong password. **Keep this file and its password somewhere safe and backed up** (a secrets manager, for instance): without it, publishing an update to the app already live on the Play Store is impossible — it would have to be republished under a new application ID.

## Running the build

```powershell
.\tool\build_release.ps1
```

The script stops at the first failure and runs, in order:

1. generating `android/key.properties` from the environment variables (if all four are set — otherwise any existing file is left as-is);
2. `dart format --output=none --set-exit-if-changed .`;
3. `flutter analyze --fatal-infos`;
4. `flutter test` (full suite);
5. `flutter build appbundle --release` — the format the Play Store expects;
6. `flutter build apk --release` — for direct installation (internal testing, distribution outside the Play Store).

Without a valid keystore, steps 1 through 4 succeed normally but steps 5 and 6 fail at signing time — verified by running the script without the environment variables set:

- `flutter build appbundle --release` fails on `signReleaseBundle` with an unmessaged `NullPointerException` (a known bundletool quirk when the signing properties are null);
- `flutter build apk --release` fails more clearly on `packageRelease`: `SigningConfig "release" is missing required property "storeFile"`.

Both are expected, not a bug in the script.

## Outputs

- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

## What's left to do by hand to publish on the Play Store

This repo and this script produce the signed App Bundle; everything after that happens in the Play Console, outside this repo:

1. Create the app in the [Play Console](https://play.google.com/console) if not already done, with the application ID `com.rachoucorp.hoopmap`.
2. Fill in the Play Store listing: short/long description, category, 512×512 icon (derivable from `assets/icon/icon.png`), screenshots (at least 2, phone format), privacy policy (mandatory: the app requests location and writes to Firestore).
3. Answer the content questionnaire (age rating) and the Data safety declaration — in particular, disclose location collection and its use (showing nearby courts, never shared). A pre-filled draft of the whole listing, including the Data safety mapping, is in `design/play-store/listing.md`.
4. Upload `app-release.aab` to an internal testing track, verify install and the full user journey on at least one real device, then promote to production.
5. For every following release: bump `version` in `pubspec.yaml` (the `+N` must always increase — it's the Android `versionCode`) before rerunning `tool/build_release.ps1`.

## v1.0.0 release log

Built 2026-08-22 end to end via `tool/build_release.ps1`, no script changes
needed:

- **Signing**: reused an existing Rachou Corp upload keystore (already used
  for another app on this machine) rather than generating a new one — see
  the top-level report for exactly which one and where; the password is
  not recorded anywhere in this repo. `android/build.gradle.kts` already
  had the `signingConfigs`/`key.properties` wiring from earlier work, so no
  Gradle changes were needed either.
- **Gate**: `dart format`, `flutter analyze --fatal-infos`, and the full
  `flutter test` suite (111 tests, run three times in a row) all passed
  clean before this build ran.
- **Outputs**: `app-release.aab` (46.6 MB) and `app-release.apk` (55.2 MB),
  both signed with APK Signature Scheme v2. Certificate SHA-256:
  `6a:08:19:62:56:0b:85:f8:b4:3a:3d:18:e7:d0:24:4a:35:cf:99:89:89:a8:97:9e:f7:7b:08:97:95:8b:0a:82`.
  Verified with `apksigner verify --print-certs`. Neither size is
  unusual for a Flutter + Firebase app; the AAB is what the Play Store
  actually serves, split and shrunk per device at install time.
- **On-device verification (real Android device, release build)**: fresh
  install (previous debug build uninstalled first — debug and release use
  different signing keys, so `adb install -r` alone would have been
  rejected), onboarding, the location permission prompt, the populated
  nearby-courts list (a live Overpass query), a court detail page without
  a photo, a court detail page with a Wikimedia Commons photo (exercises
  the Commons attribution API + image loading), submitting the add-court
  form (a real Firestore write through the anonymous-auth session), and
  the `hoopmap://courts/<id>` deep link — all worked, and none behaved
  differently from the debug build. One deep-linked court transiently
  showed "Court not found" on a single attempt; a direct Overpass query
  for the same element reproduced the same "server too busy" response
  outside the app, and the same link succeeded moments later — this was
  the public Overpass instance under load (a documented limitation, see
  "Known limitations" in `docs/architecture.md`), not a build defect.
- **Debug vs. release**: no ProGuard/R8-specific crash or behavior
  difference was found. The one bug this pass did surface — a
  10px `RenderFlex` overflow on the court detail page when a photo has an
  attribution line — reproduced identically in debug and was unrelated to
  R8; it's fixed in `lib/features/courts/presentation/widgets/court_photo.dart`
  (see that commit for the layout explanation) and covered by the existing
  `court_photo_test.dart` suite.
- Artifacts copied to `build/release/hoopmap-1.0.0.{aab,apk}` for this
  release; that directory is gitignored, so pull them from wherever this
  build actually ran, or rerun `tool/build_release.ps1`, to get them again.
