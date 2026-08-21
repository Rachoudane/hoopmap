# build_release.ps1
# Usage: .\tool\build_release.ps1
#
# Reproducible release pipeline, stopping at the first failure: generates
# android/key.properties from environment variables (see docs/release.md),
# then runs format, analyze, the full test suite, and both release
# artifacts (App Bundle and APK). Run from the repo root.
#
# Modeled on moto/wingman's build_release.ps1 (version-bump + build), with
# the checks those two scripts assume have already passed by hand added
# in explicitly, plus the key.properties generation step neither of them
# needs (their keystores are already set up on disk).

$ErrorActionPreference = "Stop"

function Stop-OnFailure([string]$step) {
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$step failed (exit code $LASTEXITCODE). Stopping."
        exit $LASTEXITCODE
    }
}

$keystorePath = $env:HOOPMAP_KEYSTORE_PATH
$keystorePassword = $env:HOOPMAP_KEYSTORE_PASSWORD
$keyAlias = $env:HOOPMAP_KEY_ALIAS
$keyPassword = $env:HOOPMAP_KEY_PASSWORD

if ($keystorePath -and $keystorePassword -and $keyAlias -and $keyPassword) {
    if (-not (Test-Path $keystorePath)) {
        Write-Error "HOOPMAP_KEYSTORE_PATH is set to '$keystorePath', which does not exist."
        exit 1
    }
    $resolvedKeystorePath = (Resolve-Path $keystorePath).Path -replace '\\', '\\\\'
    $keyPropertiesContent = @"
storePassword=$keystorePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=$resolvedKeystorePath
"@
    [System.IO.File]::WriteAllText(
        (Join-Path (Get-Location) "android\key.properties"),
        $keyPropertiesContent,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Wrote android/key.properties from environment variables."
} else {
    Write-Host "HOOPMAP_KEYSTORE_PATH/HOOPMAP_KEYSTORE_PASSWORD/HOOPMAP_KEY_ALIAS/HOOPMAP_KEY_PASSWORD"
    Write-Host "are not all set: leaving android/key.properties untouched. See docs/release.md."
    Write-Host "The release builds below will fail without a valid key.properties already in place."
}

Write-Host "`n=== dart format ==="
dart format --output=none --set-exit-if-changed .
Stop-OnFailure "dart format"

Write-Host "`n=== flutter analyze ==="
flutter analyze --fatal-infos
Stop-OnFailure "flutter analyze"

Write-Host "`n=== flutter test ==="
flutter test
Stop-OnFailure "flutter test"

Write-Host "`n=== flutter build appbundle --release ==="
flutter build appbundle --release
Stop-OnFailure "flutter build appbundle --release"

Write-Host "`n=== flutter build apk --release ==="
flutter build apk --release
Stop-OnFailure "flutter build apk --release"

Write-Host "`nRelease build pipeline complete."
Write-Host "App Bundle: build\app\outputs\bundle\release\app-release.aab"
Write-Host "APK:        build\app\outputs\flutter-apk\app-release.apk"
