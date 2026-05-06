param(
    [int[]]$Ports = @(8000, 5173),
    [switch]$StopDatabase
)

$ErrorActionPreference = "Stop"

foreach ($Port in $Ports) {
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue

    if (-not $listeners) {
        Write-Host "Port $Port tidak sedang listen."
        continue
    }

    $processIds = $listeners | Select-Object -ExpandProperty OwningProcess -Unique

    foreach ($ProcessId in $processIds) {
        $idsToStop = New-Object System.Collections.Generic.List[int]
        $currentId = [int]$ProcessId

        for ($i = 0; $i -lt 4 -and $currentId -gt 0; $i++) {
            if (-not $idsToStop.Contains($currentId)) {
                $idsToStop.Add($currentId)
            }

            $cimProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$currentId" -ErrorAction SilentlyContinue

            if (-not $cimProcess -or -not $cimProcess.ParentProcessId) {
                break
            }

            $currentId = [int]$cimProcess.ParentProcessId
        }

        foreach ($idToStop in $idsToStop) {
            if ($idToStop -eq $PID) {
                continue
            }

            $process = Get-Process -Id $idToStop -ErrorAction SilentlyContinue

            if ($process) {
                Write-Host "Stop port ${Port}: $($process.ProcessName) PID $idToStop"
                Stop-Process -Id $idToStop -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

if ($StopDatabase) {
    Push-Location $PSScriptRoot
    docker compose -f docker-compose.local.yml stop postgres
    Pop-Location
}
