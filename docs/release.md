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
3. Answer the content questionnaire (age rating) and the Data safety declaration — in particular, disclose location collection and its use (showing nearby courts, never shared).
4. Upload `app-release.aab` to an internal testing track, verify install and the full user journey on at least one real device, then promote to production.
5. For every following release: bump `version` in `pubspec.yaml` (the `+N` must always increase — it's the Android `versionCode`) before rerunning `tool/build_release.ps1`.
