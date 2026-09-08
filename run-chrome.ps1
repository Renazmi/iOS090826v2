# Run TrackIT Flutter app in Chrome (clears locked build folder first).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (Test-Path "build") {
  Write-Host "Removing old build folder..."
  cmd /c "rmdir /s /q build" 2>$null
  if (Test-Path "build") {
    Write-Host "Could not delete build/. Close Chrome and any flutter/dart processes, then retry."
    Write-Host "Tip: OneDrive can lock this folder — pause OneDrive sync or move the project outside OneDrive."
    exit 1
  }
}

flutter pub get
flutter run -d chrome @args
