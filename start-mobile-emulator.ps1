param(
    [string]$DeviceId = "emulator-5554"
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$MobileDir = Join-Path $Root "pasal_mobile_app"

if (-not (Test-Path $MobileDir)) {
    throw "Folder pasal_mobile_app tidak ditemukan di $MobileDir"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Command 'flutter' tidak ditemukan."
}

Write-Host "Menjalankan Flutter mobile di $DeviceId" -ForegroundColor Cyan
Write-Host "API Android emulator memakai http://10.0.2.2:8000/api"

Push-Location $MobileDir
flutter pub get
flutter run -d $DeviceId
Pop-Location
