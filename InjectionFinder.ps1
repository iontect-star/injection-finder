$ErrorActionPreference = 'Stop'

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Red
    Write-Host '           INJECTION FINDER' -ForegroundColor Red
    Write-Host '             made by 1ect' -ForegroundColor Red
    Write-Host '========================================' -ForegroundColor Red
    Write-Host ''
}

Write-Banner
Write-Host 'Checks visible native module names and paths for the terms Doomsday and Prestige.'
Write-Host 'A name match is unverified and does not prove an injection.'
Write-Host ''

try {
    $javaProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'javaw.exe' OR Name = 'java.exe'")
}
catch {
    Write-Host "Could not enumerate Java processes: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$minecraftProcesses = @(
    $javaProcesses | Where-Object {
        $_.CommandLine -match '(?i)minecraft|net\.minecraft|--gameDir|fabric|forge|quilt|launchwrapper'
    }
)

$scanTime = Get-Date
$namePatterns = '(?i)Doomsday|Prestige'
$matches = @()
$inspectionErrors = @()

foreach ($minecraftProcess in $minecraftProcesses) {
    try {
        $modules = @(Get-Process -Id $minecraftProcess.ProcessId -ErrorAction Stop |
            Select-Object -ExpandProperty Modules -ErrorAction Stop |
            Where-Object {
                $_.ModuleName -match $namePatterns -or $_.FileName -match $namePatterns
            })

        foreach ($module in $modules) {
            $matches += [PSCustomObject]@{
                ProcessId = $minecraftProcess.ProcessId
                ModuleName = $module.ModuleName
                FileName = $module.FileName
            }
        }
    }
    catch {
        $inspectionErrors += "PID $($minecraftProcess.ProcessId): $($_.Exception.Message)"
    }
}

Write-Host ''
if ($matches.Count -gt 0) {
    Write-Host 'POSSIBLE NAME MATCHES (UNVERIFIED)' -ForegroundColor Yellow
    Write-Host "Scan observed at: $($scanTime.ToString('yyyy-MM-dd HH:mm:ss zzz'))"
    foreach ($match in $matches) {
        Write-Host ''
        Write-Host "Process ID: $($match.ProcessId)"
        Write-Host "Module: $($match.ModuleName)"
        Write-Host "Path: $($match.FileName)"
        Write-Host "Observed by this scan at: $($scanTime.ToString('yyyy-MM-dd HH:mm:ss zzz'))"
    }
}
else {
    Write-Host ''
    Write-Host '##  ##  ##  ##  ##  ##' -ForegroundColor Blue
    Write-Host '### ##  ##  ##  ### ##' -ForegroundColor Blue
    Write-Host '## ###  ##  ##  ## ###' -ForegroundColor Blue
    Write-Host '##  ##  ##  ##  ##  ##' -ForegroundColor Blue
    Write-Host '##  ##  ######  ##  ##' -ForegroundColor Blue
    Write-Host '          hmmm nothing here....' -ForegroundColor Blue
}

if ($minecraftProcesses.Count -eq 0) {
    Write-Host 'No running Java process with recognizable Minecraft launch arguments was found.' -ForegroundColor Yellow
}

if ($inspectionErrors.Count -gt 0) {
    Write-Host ''
    Write-Host 'Some processes could not be inspected; this scan is incomplete:' -ForegroundColor Red
    foreach ($inspectionError in $inspectionErrors) {
        Write-Host "  $inspectionError" -ForegroundColor Red
    }
    Write-Host 'Try running PowerShell as the same user that started Minecraft.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host "No name match does not prove the game is clean. Renamed or hidden modules, Java-agent mods,"
Write-Host 'and other injection methods may not appear in this list. The scan cannot determine injection time.' -ForegroundColor Yellow
