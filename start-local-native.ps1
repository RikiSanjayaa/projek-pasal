param(
    [string]$Ip = "",
    [int]$ApiPort = 8000,
    [int]$AdminPort = 5173
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$BackendDir = Join-Path $Root "backend-laravel"
$AdminDir = Join-Path $Root "admin-dashboard"
$LogDir = Join-Path $Root ".local-logs"

function Write-Step($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Command '$Name' tidak ditemukan. Jalankan setup-local-native.ps1 setelah dependency terinstall."
    }
}

function Get-LanIp {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike "127.*" `
                -and $_.AddressState -eq "Preferred" `
                -and $_.InterfaceAlias -notmatch "vEthernet|VirtualBox|VMware|Loopback|Tailscale|Docker"
        } |
        Sort-Object @{
            Expression = {
                if ($_.InterfaceAlias -match "Wi-Fi|Wifi|Wireless|WLAN") { 0 }
                elseif ($_.InterfaceAlias -match "Ethernet") { 1 }
                else { 2 }
            }
        }

    if (-not $candidates) {
        return "127.0.0.1"
    }

    return $candidates[0].IPAddress
}

function Test-PortFree($Port) {
    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    return -not $listener
}

function Start-Background($Name, $WorkingDirectory, $Command, $LogFile) {
    $process = Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            "cd '$WorkingDirectory'; $Command *> '$LogFile'"
        ) `
        -WindowStyle Hidden `
        -PassThru

    Write-Host "$Name PID: $($process.Id)"
}

function Set-AdminEnv {
    $AdminEnv = Join-Path $AdminDir ".env"
    @"
VITE_APP_NAME=CariPasal Admin
VITE_API_BASE_URL=/api
VITE_API_PROXY_TARGET=http://127.0.0.1:$ApiPort
VITE_APP_BASE_PATH=/admin
"@ | Set-Content -Path $AdminEnv -Encoding UTF8
}

if (-not (Test-Path $BackendDir)) {
    throw "Folder backend-laravel tidak ditemukan di $BackendDir"
}

if (-not (Test-Path $AdminDir)) {
    throw "Folder admin-dashboard tidak ditemukan di $AdminDir"
}

Require-Command php
Require-Command npm
Require-Command node

if (-not (Test-Path (Join-Path $BackendDir "vendor\autoload.php"))) {
    throw "Dependency Laravel belum ada. Jalankan: .\setup-local-native.ps1"
}

if (-not (Test-Path (Join-Path $AdminDir "node_modules"))) {
    throw "Dependency admin dashboard belum ada. Jalankan: .\setup-local-native.ps1"
}

if ([string]::IsNullOrWhiteSpace($Ip)) {
    $Ip = Get-LanIp
}

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
Set-AdminEnv

Write-Step "Cek koneksi database Laravel"
Push-Location $BackendDir
try {
    php artisan migrate:status *> (Join-Path $LogDir "laravel-db-check.log")
    if ($LASTEXITCODE -ne 0) {
        throw "php artisan migrate:status gagal."
    }
} catch {
    throw "Database belum siap. Pastikan PostgreSQL native berjalan, lalu jalankan .\setup-local-native.ps1. Detail: $LogDir\laravel-db-check.log"
} finally {
    Pop-Location
}

Write-Step "Menjalankan server tanpa Docker"

if (Test-PortFree $ApiPort) {
    Start-Background `
        -Name "Laravel API" `
        -WorkingDirectory $BackendDir `
        -Command "php artisan serve --host=0.0.0.0 --port=$ApiPort" `
        -LogFile (Join-Path $LogDir "laravel-api.log")
} else {
    Write-Host "Port $ApiPort sudah dipakai, Laravel API tidak distart ulang." -ForegroundColor Yellow
}

if (Test-PortFree $AdminPort) {
    Start-Background `
        -Name "Admin dashboard" `
        -WorkingDirectory $AdminDir `
        -Command "npm run dev -- --host 0.0.0.0 --port $AdminPort" `
        -LogFile (Join-Path $LogDir "admin-dashboard.log")
} else {
    Write-Host "Port $AdminPort sudah dipakai, admin dashboard tidak distart ulang." -ForegroundColor Yellow
}

Start-Sleep -Seconds 3

Write-Step "Alamat akses"
Write-Host "Laptop: http://127.0.0.1:$AdminPort/admin" -ForegroundColor Green
Write-Host "HP satu Wi-Fi: http://$($Ip):$AdminPort/admin" -ForegroundColor Green
Write-Host "API health: http://127.0.0.1:$ApiPort/api/health"
Write-Host "Android emulator API: http://10.0.2.2:$ApiPort/api"
Write-Host ""
Write-Host "Log Laravel: $LogDir\laravel-api.log"
Write-Host "Log Admin:   $LogDir\admin-dashboard.log"
Write-Host "Stop server: .\stop-local-lan.ps1"
