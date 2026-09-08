# Builds TrackIT mobile release APK to releases/TrackIT.apk
$ErrorActionPreference = "Stop"
$mobileRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $mobileRoot
$releasesApk = Join-Path $projectRoot "releases\TrackIT.apk"
Set-Location $mobileRoot

Write-Host "Fetching dependencies..."
flutter clean
flutter pub get

$androidBuildTemp = Join-Path $env:LOCALAPPDATA "Temp\trackit-android-build"
if (Test-Path $androidBuildTemp) {
    Write-Host "Clearing cached Android build output..."
    Remove-Item -Recurse -Force $androidBuildTemp -ErrorAction SilentlyContinue
}

$registrantPath = Join-Path $mobileRoot "android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"
if (Test-Path $registrantPath) {
    $content = Get-Content $registrantPath -Raw
    $content = $content -replace '(?ms)\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test[^"]*", e\);\s*\}', ''
    Set-Content -Path $registrantPath -Value $content -NoNewline
}

Write-Host "Building release APK..."
Set-Location (Join-Path $mobileRoot "android")
& ./gradlew.bat clean :app:exportTrackITApk
if ($LASTEXITCODE -ne 0) {
    throw "Gradle APK release build failed with exit code $LASTEXITCODE"
}

Write-Host "Building release AAB..."
& ./gradlew.bat :app:exportTrackITAab
if ($LASTEXITCODE -ne 0) {
    throw "Gradle AAB release build failed with exit code $LASTEXITCODE"
}

$releasesAab = Join-Path $projectRoot "releases\TrackIT.aab"
if (-not (Test-Path $releasesApk)) {
    throw "Release APK was not produced at $releasesApk"
}
if (-not (Test-Path $releasesAab)) {
    throw "Release AAB was not produced at $releasesAab"
}

$apkItem = Get-Item $releasesApk
$aabItem = Get-Item $releasesAab
Write-Host ""
Write-Host "Done:"
Write-Host "  APK: $($apkItem.FullName) ($([math]::Round($apkItem.Length / 1MB, 2)) MB)"
Write-Host "  AAB: $($aabItem.FullName) ($([math]::Round($aabItem.Length / 1MB, 2)) MB)"
