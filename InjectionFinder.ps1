$ErrorActionPreference = 'Stop'

Clear-Host
Write-Host ''
Write-Host '  IIIII  N   N  JJJJJ  EEEEE  CCCCC  TTTTT  IIIII  OOOO  N   N' -ForegroundColor Red
Write-Host '    I    NN  N    J    E      C        T      I   O    O NN  N' -ForegroundColor Red
Write-Host '    I    N N N    J    EEEE   C        T      I   O    O N N N' -ForegroundColor Red
Write-Host '    I    N  NN J  J    E      C        T      I   O    O N  NN' -ForegroundColor Red
Write-Host '  IIIII  N   N  JJ    EEEEE  CCCCC    T    IIIII  OOOO  N   N' -ForegroundColor Red
Write-Host '                         F I N D E R - by 1ect :D' -ForegroundColor Red
Write-Host ''
Write-Host 'Minecraft-only snapshot: Java process module names and Minecraft logs.'
Write-Host 'Any hit is an unverified indicator, not proof of cheating or injection.'
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
    Write-Host 'Open Minecraft and try again. This scan does not search unrelated PC processes or files.'
    exit 0
}

$scanTime = Get-Date
$modulePattern = '(?i)inject|cheat|hack|agent'
$launchPattern = '(?i)-javaagent(?:[:=]|\s)|-agentlib(?::|\s)|-agentpath(?::|\s)|-Xbootclasspath'
$logPattern = '(?i)-javaagent|-agentlib|-agentpath|java.?agent|instrumentation.?agent|inject(or|ed|ion)?'
$findings = @()
$scanErrors = @()

foreach ($minecraftProcess in $minecraftProcesses) {
    $processId = $minecraftProcess.ProcessId
    $gameDirectories = @()

    if ($minecraftProcess.CommandLine -match $launchPattern) {
        $findings += [PSCustomObject]@{
            Kind = 'Possible Java agent launch option (unverified)'
            ProcessId = $processId
            Name = 'Java process command line'
            Detail = $Matches[0]
        }
    }

    if ($minecraftProcess.CommandLine -match '(?i)--gameDir\s+"([^"]+)"') {
        $gameDirectories += $Matches[1]
    }
    elseif ($minecraftProcess.CommandLine -match '(?i)--gameDir\s+(\S+)') {
        $gameDirectories += $Matches[1]
    }

    $gameDirectories += (Join-Path $env:APPDATA '.minecraft')
    $logPaths = @(
        $gameDirectories |
            Where-Object { $_ } |
            ForEach-Object { Join-Path $_ 'logs\latest.log' } |
            Select-Object -Unique
    )

    try {
        $moduleHits = @(
            Get-Process -Id $processId -ErrorAction Stop |
                Select-Object -ExpandProperty Modules -ErrorAction Stop |
                Where-Object {
                    $_.ModuleName -match $modulePattern -or
                    [System.IO.Path]::GetFileName($_.FileName) -match $modulePattern
                }
        )

        foreach ($module in $moduleHits) {
            $findings += [PSCustomObject]@{
                Kind = 'Possible module-name indicator (unverified)'
                ProcessId = $processId
                Name = $module.ModuleName
                Detail = $module.FileName
            }
        }
    }
    catch {
        $scanErrors += "Could not inspect modules for PID ${processId}: $($_.Exception.Message)"
    }

    foreach ($logPath in $logPaths) {
        if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
            continue
        }

        try {
            $lineNumber = 0
            foreach ($line in Get-Content -LiteralPath $logPath -ErrorAction Stop) {
                $lineNumber++
                if ($line -match $logPattern) {
                    $findings += [PSCustomObject]@{
                        Kind = 'Possible log indicator (unverified)'
                        ProcessId = $processId
                        Name = $logPath
                        Detail = "Line ${lineNumber}: $line"
                    }
                }
            }
        }
        catch {
            $scanErrors += "Could not read log ${logPath}: $($_.Exception.Message)"
        }
    }
}

Write-Host "Scan observed at: $($scanTime.ToString('yyyy-MM-dd HH:mm:ss zzz'))"
Write-Host "Minecraft-like Java processes checked: $($minecraftProcesses.Count)"
Write-Host ''

if ($findings.Count -gt 0) {
    Write-Host 'POSSIBLE INDICATORS - REVIEW THESE MANUALLY' -ForegroundColor Yellow
    foreach ($finding in $findings) {
        Write-Host ''
        Write-Host $finding.Kind -ForegroundColor Yellow
        Write-Host "Process ID: $($finding.ProcessId)"
        Write-Host "Name/file: $($finding.Name)"
        Write-Host "Details: $($finding.Detail)"
        Write-Host "Observed by this scan at: $($scanTime.ToString('yyyy-MM-dd HH:mm:ss zzz'))"
    }
}
else {
    Write-Host '##  ##  ##  ##  ##  ##' -ForegroundColor Blue
    Write-Host '### ##  ##  ##  ### ##' -ForegroundColor Blue
    Write-Host '## ###  ##  ##  ## ###' -ForegroundColor Blue
    Write-Host '##  ##  ##  ##  ##  ##' -ForegroundColor Blue
    Write-Host '##  ##  ######  ##  ##' -ForegroundColor Blue
    Write-Host '          hmmm nothing here....' -ForegroundColor Blue
}

if ($scanErrors.Count -gt 0) {
    Write-Host ''
    Write-Host 'Some checks could not be completed:' -ForegroundColor Red
    foreach ($scanError in $scanErrors) {
        Write-Host "  $scanError" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host 'This checks only visible module names and matching text in latest.log files.'
Write-Host 'Legitimate software may match; renamed/hidden cheats or Java mods may be missed.'
Write-Host 'Times shown are scan times. Logs may include their own event time, not a verified injection time.' -ForegroundColor Yellow
