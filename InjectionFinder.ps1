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
Write-Host 'This snapshot lists native modules loaded by detected Minecraft Java processes.'
Write-Host 'It cannot confirm that a module is an injection or determine when it was injected.'
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

if ($minecraftProcesses.Count -eq 0) {
    Write-Host 'No running Java process with recognizable Minecraft launch arguments was found.' -ForegroundColor Yellow
    Write-Host 'If Minecraft is open, its launch arguments may not identify it as Minecraft.'
    exit 0
}

$scanTime = Get-Date
Write-Host "Scan observed at: $($scanTime.ToString('yyyy-MM-dd HH:mm:ss zzz'))"
Write-Host "Minecraft-like Java processes found: $($minecraftProcesses.Count)"

foreach ($minecraftProcess in $minecraftProcesses) {
    Write-Host ''
    Write-Host "Process ID: $($minecraftProcess.ProcessId)  |  Executable: $($minecraftProcess.ExecutablePath)"
    Write-Host 'Loaded native modules (inventory only):'

    try {
        $modules = @(Get-Process -Id $minecraftProcess.ProcessId -ErrorAction Stop |
            Select-Object -ExpandProperty Modules -ErrorAction Stop |
            Sort-Object ModuleName)

        if ($modules.Count -eq 0) {
            Write-Host '  No modules were returned.'
            continue
        }

        foreach ($module in $modules) {
            Write-Host "  $($module.ModuleName) -- $($module.FileName)"
        }
    }
    catch {
        Write-Host "  Could not read this process's modules: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '  Try running PowerShell as the same user that started Minecraft.'
    }
}

Write-Host ''
Write-Host 'A module name or path alone is not proof of cheating or injection.' -ForegroundColor Yellow
Write-Host 'The displayed time is when this scan observed the modules, not when they were loaded.'
