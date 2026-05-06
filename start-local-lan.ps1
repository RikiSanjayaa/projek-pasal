param(
    [string]$Ip = "",
    [int]$ApiPort = 8000,
    [int]$AdminPort = 5173,
    [int]$DatabasePort = 55432,
    [switch]$SkipDatabase
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$BackendDir = Join-Path $Root "backend-laravel"
$AdminDir = Join-Path $Root "admin-dashboard"
$LogDir = Join-Path $Root ".local-logs"

function Write-Step($Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Command '$Name' tidak ditemukan. Install dulu lalu jalankan ulang script ini."
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
        throw "Tidak menemukan IP LAN. Jalankan dengan parameter manual, contoh: .\start-local-lan.ps1 -Ip 192.168.1.15"
    }

    return $candidates[0].IPAddress
}

function Test-PortFree($Port) {
    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    return -not $listener
}

function Test-DockerReady {
    try {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        docker info *> $null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Start-DockerDesktop {
    if (Test-DockerReady) {
        return
    }

    $dockerDesktop = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"

    if (-not (Test-Path $dockerDesktop)) {
        throw "Docker Desktop belum berjalan dan executable tidak ditemukan. Jalankan Docker Desktop dulu, lalu ulangi script."
    }

    Write-Step "Menyalakan Docker Desktop"
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden

    $deadline = (Get-Date).AddMinutes(3)

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5

        if (Test-DockerReady) {
            return
        }

        Write-Host "Menunggu Docker siap..."
    }

    throw "Docker Desktop belum siap setelah 3 menit. Buka Docker Desktop manual, tunggu status running, lalu ulangi script."
}

function Start-LocalDatabase {
    Start-DockerDesktop

    Write-Step "Menyalakan PostgreSQL lokal"
    Push-Location $Root
    docker compose -f docker-compose.local.yml up -d postgres
    Pop-Location

    $deadline = (Get-Date).AddMinutes(2)

    while ((Get-Date) -lt $deadline) {
        docker exec caripasal-postgres-local pg_isready -U caripasal_user -d caripasal *> $null

        if ($LASTEXITCODE -eq 0) {
            return
        }

        Start-Sleep -Seconds 2
    }

    throw "PostgreSQL lokal belum siap. Cek dengan: docker logs caripasal-postgres-local"
}

function Set-EnvValue($Path, $Key, $Value) {
    if (-not (Test-Path $Path)) {
        throw "File env tidak ditemukan: $Path"
    }

    $lines = Get-Content $Path
    $escapedValue = "$Value"
    $found = $false

    $updated = $lines | ForEach-Object {
        if ($_ -match "^$([regex]::Escape($Key))=") {
            $found = $true
            "$Key=$escapedValue"
        } else {
            $_
        }
    }

    if (-not $found) {
        $updated += "$Key=$escapedValue"
    }

    $updated | Set-Content -Path $Path -Encoding UTF8
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

if (-not (Test-Path $BackendDir)) {
    throw "Folder backend-laravel tidak ditemukan di $BackendDir"
}

if (-not (Test-Path $AdminDir)) {
    throw "Folder admin-dashboard tidak ditemukan di $AdminDir"
}

Require-Command php
Require-Command npm
Require-Command node

if (-not $SkipDatabase) {
    Require-Command docker
}

if ([string]::IsNullOrWhiteSpace($Ip)) {
    $Ip = Get-LanIp
}

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

Write-Step "Menyiapkan env admin untuk akses HP"
@"
VITE_APP_NAME=CariPasal Admin
VITE_API_BASE_URL=http://$($Ip):$ApiPort/api
"@ | Set-Content -Path (Join-Path $AdminDir ".env") -Encoding UTF8

if (-not $SkipDatabase) {
    Start-LocalDatabase

    Write-Step "Menyiapkan env Laravel untuk PostgreSQL lokal"
    $backendEnv = Join-Path $BackendDir ".env"
    Set-EnvValue -Path $backendEnv -Key "DB_CONNECTION" -Value "pgsql"
    Set-EnvValue -Path $backendEnv -Key "DB_HOST" -Value "127.0.0.1"
    Set-EnvValue -Path $backendEnv -Key "DB_PORT" -Value $DatabasePort
    Set-EnvValue -Path $backendEnv -Key "DB_DATABASE" -Value "caripasal"
    Set-EnvValue -Path $backendEnv -Key "DB_USERNAME" -Value "caripasal_user"
    Set-EnvValue -Path $backendEnv -Key "DB_PASSWORD" -Value "caripasal_local_password"
}

if (-not (Test-Path (Join-Path $BackendDir "vendor\autoload.php"))) {
    Write-Step "Install dependency Laravel"
    Push-Location $BackendDir
    composer install
    Pop-Location
}

if (-not (Test-Path (Join-Path $AdminDir "node_modules"))) {
    Write-Step "Install dependency admin dashboard"
    Push-Location $AdminDir
    npm install
    Pop-Location
}

if (-not $SkipDatabase) {
    Write-Step "Menjalankan migration dan seeder Laravel"
    Push-Location $BackendDir
    php artisan migrate --force
    php artisan db:seed --force
    Pop-Location
}

Write-Step "Menjalankan server"

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
Write-Host "Laptop: http://127.0.0.1:$AdminPort/admin"
Write-Host "HP satu Wi-Fi: http://$($Ip):$AdminPort/admin" -ForegroundColor Green
Write-Host "API health: http://$($Ip):$ApiPort/api/health"
Write-Host ""
Write-Host "Log Laravel: $LogDir\laravel-api.log"
Write-Host "Log Admin:   $LogDir\admin-dashboard.log"
Write-Host "Stop server: .\stop-local-lan.ps1"
