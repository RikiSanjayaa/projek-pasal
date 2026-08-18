param(
  [string]$ApiBaseUrl = "https://ubgpasal.ubg.ac.id/api",
  [string]$WebAppUrl = "https://ubgpasal.ubg.ac.id",
  [string]$BaseHref = "/mobile/"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$MobileAppDir = Join-Path $RepoRoot "pasal_mobile_app"
$OutputDir = Join-Path $RepoRoot "mobile-web-dist"

Write-Host ""
Write-Host "== Building CariPasal Flutter Web =="
Write-Host "API_BASE_URL: $ApiBaseUrl"
Write-Host "WEB_APP_URL:  $WebAppUrl"
Write-Host "BASE_HREF:    $BaseHref"
Write-Host ""

Push-Location $MobileAppDir
try {
  flutter pub get
  flutter build web --release `
    --base-href=$BaseHref `
    --dart-define=API_BASE_URL=$ApiBaseUrl `
    --dart-define=WEB_APP_URL=$WebAppUrl
}
finally {
  Pop-Location
}

if (Test-Path -LiteralPath $OutputDir) {
  Remove-Item -LiteralPath $OutputDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Copy-Item -Path (Join-Path $MobileAppDir "build\web\*") -Destination $OutputDir -Recurse -Force

$BuildIdPath = Join-Path $OutputDir ".last_build_id"
$BuildId = if (Test-Path -LiteralPath $BuildIdPath) {
  (Get-Content -LiteralPath $BuildIdPath -Raw).Trim()
} else {
  [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
}

$IndexPath = Join-Path $OutputDir "index.html"
if (Test-Path -LiteralPath $IndexPath) {
  $IndexHtml = Get-Content -LiteralPath $IndexPath -Raw
  $IndexHtml = $IndexHtml -replace 'src="flutter_bootstrap\.js"', "src=`"flutter_bootstrap.js?v=$BuildId`""
  Set-Content -LiteralPath $IndexPath -Value $IndexHtml -NoNewline
}

$BootstrapPath = Join-Path $OutputDir "flutter_bootstrap.js"
if (Test-Path -LiteralPath $BootstrapPath) {
  $BootstrapJs = Get-Content -LiteralPath $BootstrapPath -Raw
  $BootstrapJs = $BootstrapJs -replace '"main\.dart\.js"', "`"main.dart.js?v=$BuildId`""
  Set-Content -LiteralPath $BootstrapPath -Value $BootstrapJs -NoNewline
}

Write-Host ""
Write-Host "Build copied to:"
Write-Host $OutputDir
Write-Host ""
Write-Host "Next:"
Write-Host "git add mobile-web-dist build-mobile-web.ps1 deploy/aapanel-publish-mobile-web.sh docs/MOBILE_WEB_AAPANEL.md README.md"
Write-Host "git commit -m `"docs: tambah panduan deploy mobile web kampus`""
Write-Host "git push origin main"
