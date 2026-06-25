param(
    [string]$DbHost = "127.0.0.1",
    [int]$DbPort = 5432,
    [string]$DbName = "caripasal",
    [string]$DbUser = "caripasal_user",
    [string]$DbPassword = "caripasal_local_password",
    [string]$PostgresAdminUser = "postgres",
    [string]$PostgresAdminDatabase = "postgres",
    [string]$PostgresAdminPassword = "",
    [int]$ApiPort = 8000,
    [int]$AdminPort = 5173,
    [switch]$SkipDatabaseCreate,
    [switch]$SkipInstall,
    [switch]$SkipMigrate,
    [switch]$Fresh
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$BackendDir = Join-Path $Root "backend-laravel"
$AdminDir = Join-Path $Root "admin-dashboard"

function Write-Step($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Command '$Name' tidak ditemukan. Install dulu lalu jalankan ulang script ini."
    }
}

function Resolve-Psql {
    $fromPath = Get-Command psql -ErrorAction SilentlyContinue
    if ($fromPath) {
        return $fromPath.Source
    }

    $candidates = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending

    if ($candidates) {
        return $candidates[0].FullName
    }

    throw "psql tidak ditemukan. Install PostgreSQL Windows dulu, lalu centang opsi Command Line Tools atau tambahkan folder bin PostgreSQL ke PATH."
}

function Assert-PhpExtension($Name) {
    $modules = php -m
    if ($modules -notcontains $Name) {
        throw "PHP extension '$Name' belum aktif. Aktifkan di php.ini lokal sebelum menjalankan Laravel."
    }
}

function Assert-SafeIdentifier($Value, $Label) {
    if ($Value -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        throw "$Label hanya boleh huruf, angka, dan underscore, serta tidak boleh diawali angka. Nilai sekarang: $Value"
    }
}

function Escape-SqlLiteral($Value) {
    return "$Value".Replace("'", "''")
}

function Set-EnvValue($Path, $Key, $Value) {
    if (-not (Test-Path $Path)) {
        throw "File env tidak ditemukan: $Path"
    }

    $lines = Get-Content $Path
    $found = $false

    $updated = $lines | ForEach-Object {
        if ($_ -match "^$([regex]::Escape($Key))=") {
            $found = $true
            "$Key=$Value"
        } else {
            $_
        }
    }

    if (-not $found) {
        $updated += "$Key=$Value"
    }

    $updated | Set-Content -Path $Path -Encoding UTF8
}

function Ensure-EnvFile($Path, $ExamplePath) {
    if (-not (Test-Path $Path)) {
        if (-not (Test-Path $ExamplePath)) {
            throw "File contoh env tidak ditemukan: $ExamplePath"
        }

        Copy-Item $ExamplePath $Path
    }
}

function Invoke-PsqlScript($PsqlPath, $Database, $Sql) {
    $Sql | & $PsqlPath `
        -h $DbHost `
        -p $DbPort `
        -U $PostgresAdminUser `
        -d $Database `
        -v ON_ERROR_STOP=1

    if ($LASTEXITCODE -ne 0) {
        throw "psql gagal menjalankan script database."
    }
}

if (-not (Test-Path $BackendDir)) {
    throw "Folder backend-laravel tidak ditemukan di $BackendDir"
}

if (-not (Test-Path $AdminDir)) {
    throw "Folder admin-dashboard tidak ditemukan di $AdminDir"
}

Write-Step "Cek runtime"
Require-Command php
Require-Command composer
Require-Command node
Require-Command npm

php -v | Select-Object -First 1
composer -V
node -v
npm -v

Write-Step "Cek PHP extension"
@("pdo_pgsql", "pgsql", "fileinfo", "mbstring", "openssl", "curl", "zip", "xml", "gd") |
    ForEach-Object {
        Assert-PhpExtension $_
        Write-Host "[OK] $_"
    }

Assert-SafeIdentifier $DbName "DB name"
Assert-SafeIdentifier $DbUser "DB user"

$BackendEnv = Join-Path $BackendDir ".env"
$AdminEnv = Join-Path $AdminDir ".env"

Write-Step "Menyiapkan env lokal"
Ensure-EnvFile $BackendEnv (Join-Path $BackendDir ".env.example")

Set-EnvValue $BackendEnv "APP_ENV" "local"
Set-EnvValue $BackendEnv "APP_DEBUG" "true"
Set-EnvValue $BackendEnv "APP_URL" "http://127.0.0.1:$ApiPort"
Set-EnvValue $BackendEnv "DB_CONNECTION" "pgsql"
Set-EnvValue $BackendEnv "DB_HOST" $DbHost
Set-EnvValue $BackendEnv "DB_PORT" $DbPort
Set-EnvValue $BackendEnv "DB_DATABASE" $DbName
Set-EnvValue $BackendEnv "DB_USERNAME" $DbUser
Set-EnvValue $BackendEnv "DB_PASSWORD" $DbPassword
Set-EnvValue $BackendEnv "CORS_ALLOWED_ORIGINS" "http://127.0.0.1:$AdminPort,http://localhost:$AdminPort"
Set-EnvValue $BackendEnv "MAIL_MAILER" "log"

@"
VITE_APP_NAME=CariPasal Admin
VITE_API_BASE_URL=/api
VITE_API_PROXY_TARGET=http://127.0.0.1:$ApiPort
VITE_APP_BASE_PATH=/admin
"@ | Set-Content -Path $AdminEnv -Encoding UTF8

if (-not $SkipDatabaseCreate) {
    Write-Step "Menyiapkan database PostgreSQL native"
    $PsqlPath = Resolve-Psql
    Write-Host "psql: $PsqlPath"

    if ([string]::IsNullOrWhiteSpace($PostgresAdminPassword)) {
        $secure = Read-Host "Password PostgreSQL admin user '$PostgresAdminUser'" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $PostgresAdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }

    $previousPgPassword = $env:PGPASSWORD
    $env:PGPASSWORD = $PostgresAdminPassword

    try {
        $escapedDbPassword = Escape-SqlLiteral $DbPassword
        $createSql = @"
DO `$`$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DbUser') THEN
        CREATE ROLE $DbUser LOGIN PASSWORD '$escapedDbPassword';
    ELSE
        ALTER ROLE $DbUser WITH LOGIN PASSWORD '$escapedDbPassword';
    END IF;
END
`$`$;

SELECT 'CREATE DATABASE $DbName OWNER $DbUser'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DbName')\gexec

GRANT ALL PRIVILEGES ON DATABASE $DbName TO $DbUser;
"@

        Invoke-PsqlScript $PsqlPath $PostgresAdminDatabase $createSql

        $grantSql = @"
GRANT USAGE, CREATE ON SCHEMA public TO $DbUser;
ALTER SCHEMA public OWNER TO $DbUser;
"@
        Invoke-PsqlScript $PsqlPath $DbName $grantSql
    } finally {
        if ($null -eq $previousPgPassword) {
            Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
        } else {
            $env:PGPASSWORD = $previousPgPassword
        }
    }
}

if (-not $SkipInstall) {
    if (-not (Test-Path (Join-Path $BackendDir "vendor\autoload.php"))) {
        Write-Step "Install dependency Laravel"
        Push-Location $BackendDir
        composer install
        if ($LASTEXITCODE -ne 0) {
            throw "composer install gagal."
        }
        Pop-Location
    }

    if (-not (Test-Path (Join-Path $AdminDir "node_modules"))) {
        Write-Step "Install dependency admin dashboard"
        Push-Location $AdminDir
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "npm install gagal."
        }
        Pop-Location
    }
}

Write-Step "Menyiapkan Laravel"
Push-Location $BackendDir

$appKeyLine = Get-Content ".env" | Where-Object { $_ -match '^APP_KEY=' } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($appKeyLine) -or $appKeyLine -eq "APP_KEY=") {
    php artisan key:generate
    if ($LASTEXITCODE -ne 0) {
        throw "php artisan key:generate gagal."
    }
}

if (-not $SkipMigrate) {
    if ($Fresh) {
        php artisan migrate:fresh --seed --force
        if ($LASTEXITCODE -ne 0) {
            throw "php artisan migrate:fresh --seed gagal."
        }
    } else {
        php artisan migrate --force
        if ($LASTEXITCODE -ne 0) {
            throw "php artisan migrate gagal."
        }
        php artisan db:seed --force
        if ($LASTEXITCODE -ne 0) {
            throw "php artisan db:seed gagal."
        }
    }
}

Pop-Location

Write-Step "Selesai"
Write-Host "Jalankan web lokal:"
Write-Host ".\start-local-native.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "Login admin awal:"
Write-Host "Email:    superadmin@caripasal.local"
Write-Host "Password: ChangeMe123!"
