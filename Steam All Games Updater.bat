@echo off
setlocal EnableExtensions DisableDelayedExpansion

chcp 65001 >nul 2>&1
for /f %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "RESET=%ESC%[0m"
set "BATCH_ROOT=%~dp0"
if "%BATCH_ROOT:~-1%"=="\" set "BATCH_ROOT=%BATCH_ROOT:~0,-1%"

title Steam High Priority Updater
cls

echo %GREEN%==============================================================%RESET%
echo %GREEN% Steam High Priority Updater                                  %RESET%
echo %GREEN%==============================================================%RESET%
echo.
echo %GREEN%This tool will:%RESET%
echo %GREEN%  1. Close Steam and All Related Processes.%RESET%
echo %GREEN%  2. Read Every Configured Steam Library Folder.%RESET%
echo %GREEN%  3. Find All Steam Installed Game Files.%RESET%
echo %GREEN%  4. Set All Games To Instantly Update Once Updates Are Released.%RESET%
echo %GREEN%  5. Relaunch Steam.%RESET%
echo.

call :ConfirmSteamShutdown
if errorlevel 1 (
    echo.
    echo %GREEN%Aborting Without Making Any Changes. Press Any Key To Close This Window...%RESET%
    call :CloseOnAnyKey
    exit /b 0
)

set "EMBEDDED_HELPER=%TEMP%\SteamHighPriorityUpdater_%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$lines = Get-Content -LiteralPath '%~f0'; " ^
  "$content = $lines | Where-Object { $_.StartsWith('::PS1::') } | ForEach-Object { $_.Substring(7) }; " ^
  "if(-not $content -or $content.Count -eq 0){ exit 1 } " ^
  "[System.IO.File]::WriteAllLines('%EMBEDDED_HELPER%', $content); " ^
  "if(-not (Test-Path '%EMBEDDED_HELPER%')){ exit 1 }"
if errorlevel 1 (
    if exist "%EMBEDDED_HELPER%" del /q "%EMBEDDED_HELPER%" >nul 2>&1
    echo.
    echo %RED%Could not prepare the built-in updater helper.%RESET%
    echo %RED%PROCESS NOT FINISHED.%RESET%
    call :HoldWindow
    exit /b 1
)

echo %GREEN%Closing Steam and all related processes...%RESET%
if defined STEAM_ROOT_OVERRIDE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%EMBEDDED_HELPER%" -Mode CloseProcesses -SteamRootOverride "%STEAM_ROOT_OVERRIDE%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%EMBEDDED_HELPER%" -Mode CloseProcesses
)
timeout /t 2 /nobreak >nul

echo %GREEN%Reading installed Steam manifests and applying updates...%RESET%
if defined STEAM_ROOT_OVERRIDE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%EMBEDDED_HELPER%" -Mode Update -BatchRoot "%BATCH_ROOT%" -SteamRootOverride "%STEAM_ROOT_OVERRIDE%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%EMBEDDED_HELPER%" -Mode Update -BatchRoot "%BATCH_ROOT%"
)
set "RC=%ERRORLEVEL%"

set "UPDATE_WARNING="
if "%RC%"=="3" set "UPDATE_WARNING=1"

if not "%RC%"=="0" if not "%RC%"=="3" (
    if exist "%EMBEDDED_HELPER%" del /q "%EMBEDDED_HELPER%" >nul 2>&1
    echo.
    echo %RED%PROCESS NOT FINISHED. Error code: %RC%%RESET%
    echo %GREEN%Fix the reported issue and run this file again.%RESET%
    call :HoldWindow
    exit /b %RC%
)
if exist "%EMBEDDED_HELPER%" del /q "%EMBEDDED_HELPER%" >nul 2>&1

call :ConfirmLaunchSteam
if errorlevel 1 goto SkipLaunchSteam

set "LAUNCH_HELPER=%TEMP%\SteamHighPriorityLauncher_%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$lines = Get-Content -LiteralPath '%~f0'; " ^
  "$content = $lines | Where-Object { $_.StartsWith('::PS1::') } | ForEach-Object { $_.Substring(7) }; " ^
  "if(-not $content -or $content.Count -eq 0){ exit 1 } " ^
  "[System.IO.File]::WriteAllLines('%LAUNCH_HELPER%', $content); " ^
  "if(-not (Test-Path '%LAUNCH_HELPER%')){ exit 1 }"
if errorlevel 1 (
    echo.
    echo %YELLOW%The manifests were updated, but Steam could not be prepared for relaunch.%RESET%
    echo %YELLOW%PROCESS FINISHED WITH WARNING.%RESET%
    echo.
    call :PrintBanner
    echo.
    call :HoldWindow
    exit /b 2
)

echo.
echo %GREEN%Relaunching Steam...%RESET%
if defined STEAM_ROOT_OVERRIDE (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCH_HELPER%" -Mode LaunchSteam -SteamRootOverride "%STEAM_ROOT_OVERRIDE%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCH_HELPER%" -Mode LaunchSteam
)
set "LAUNCH_RC=%ERRORLEVEL%"
if exist "%LAUNCH_HELPER%" del /q "%LAUNCH_HELPER%" >nul 2>&1

if not "%LAUNCH_RC%"=="0" (
    echo.
    echo %YELLOW%The manifests were updated, but Steam could not be relaunched automatically.%RESET%
    echo %YELLOW%PROCESS FINISHED WITH WARNING.%RESET%
    if defined UPDATE_WARNING echo %YELLOW%Some game manifest files were also skipped or failed during the update.%RESET%
    echo.
    call :PrintBanner
    echo.
    call :HoldWindow
    exit /b 2
)

:SkipLaunchSteamDone
echo.
if not "%LAUNCH_RC%"=="" if "%LAUNCH_RC%"=="0" echo %GREEN%Steam launch was queued. It may take a few seconds to appear.%RESET%
if defined UPDATE_WARNING (
    echo %YELLOW%Some game manifest files were skipped or failed, but the updater continued.%RESET%
    echo %YELLOW%PROCESS FINISHED WITH WARNING.%RESET%
) else (
    echo %GREEN%PROCESS FINISHED SUCCESSFULLY.%RESET%
)
echo.
call :PrintBanner
echo.
call :HoldWindow
exit /b 0

:SkipLaunchSteam
if exist "%EMBEDDED_HELPER%" del /q "%EMBEDDED_HELPER%" >nul 2>&1
if exist "%LAUNCH_HELPER%" del /q "%LAUNCH_HELPER%" >nul 2>&1
echo.
echo %GREEN%Steam launch was skipped.%RESET%
goto SkipLaunchSteamDone

:ConfirmSteamShutdown
if /I "%STEAM_UPDATER_AUTO_YES%"=="1" exit /b 0
if /I "%STEAM_UPDATER_AUTO_NO%"=="1" exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Sta -Command ^
  "Add-Type -AssemblyName System.Windows.Forms; " ^
  "$message = 'Steam and All Its Related Processes and Games Will Close.'; " ^
  "$title = 'Steam High Priority Updater'; " ^
  "$result = [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2); " ^
  "if($result -eq [System.Windows.Forms.DialogResult]::Yes){ exit 0 } else { exit 1 }"
exit /b %ERRORLEVEL%

:ConfirmLaunchSteam
if /I "%STEAM_UPDATER_LAUNCH_YES%"=="1" exit /b 0
if /I "%STEAM_UPDATER_LAUNCH_NO%"=="1" exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Sta -Command ^
  "Add-Type -AssemblyName System.Windows.Forms; " ^
  "$message = 'Would you like to launch Steam now?'; " ^
  "$title = 'Steam High Priority Updater'; " ^
  "$result = [System.Windows.Forms.MessageBox]::Show($message, $title, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question, [System.Windows.Forms.MessageBoxDefaultButton]::Button1); " ^
  "if($result -eq [System.Windows.Forms.DialogResult]::Yes){ exit 0 } else { exit 1 }"
exit /b %ERRORLEVEL%

:HoldWindow
echo %GREEN%Press Any Key To Close This Window...%RESET%
if /I "%STEAM_UPDATER_TEST_MODE%"=="1" goto :eof
pause >nul
goto :eof

:CloseOnAnyKey
if /I "%STEAM_UPDATER_TEST_MODE%"=="1" goto :eof
pause >nul
goto :eof

:PrintBanner
echo %RED%  GGGGGG   L          H   H   FFFFFF%RESET%
echo %RED% G         L          H   H   F%RESET%
echo %RED% G   GGG   L          HHHHH   FFFF%RESET%
echo %RED% G     G   L          H   H   F%RESET%
echo %RED% G     G   L          H   H   F%RESET%
echo %RED%  GGGGGG   LLLLLL     H   H   F%RESET%
echo %RED%%RESET%
echo %RED%  ****   *   *                  ***    ****  *             *   *              %RESET%
echo %RED%  *   *  *   *          ***    *   *  *      *       ***   *   *   ***   * ** %RESET%
echo %RED%  *   *  *   *         *   *   *   *  *      *          *  *   *  *   *  **  *%RESET%
echo %RED%  ****    ****         *   *    ***    ***   *       ****   ****  *****  *    %RESET%
echo %RED%  *   *      *         *   *   *   *      *  *      *   *      *  *      *    %RESET%
echo %RED%  *   *  *   *          ****   *   *      *  *      *   *  *   *  *   *  *    %RESET%
echo %RED%  ****    ***              *    ***   ****   ****    ****   ***    ***   *    %RESET%
echo %RED%                           *  *                                               %RESET%
echo %RED%                           * *                                                %RESET%
echo %RED%                           *                                                  %RESET%
echo %RED%                                                                              %RESET%
echo %RED%                                                                              %RESET%
echo %RED% Steam Profile:  https://steamcommunity.com/id/q8Slayer/                      %RESET%
echo %RED%                                                                              %RESET%
echo %RED%                                                                              %RESET%
echo %RED%                                                                              %RESET%
echo %RED% Discord Server: https://discord.gg/ce3d3NkpU5                                %RESET%
goto :eof
::PS1::param(
::PS1::    [string]$Mode = "Update",
::PS1::    [string]$BatchRoot,
::PS1::    [string]$SteamRootOverride
::PS1::)
::PS1::
::PS1::$ErrorActionPreference = "Stop"
::PS1::
::PS1::function Write-Green {
::PS1::    param([string]$Message)
::PS1::    Write-Host $Message -ForegroundColor Green
::PS1::}
::PS1::
::PS1::function Write-Aqua {
::PS1::    param([string]$Message)
::PS1::    Write-Host $Message -ForegroundColor Cyan
::PS1::}
::PS1::
::PS1::function Write-Yellow {
::PS1::    param([string]$Message)
::PS1::    Write-Host $Message -ForegroundColor Yellow
::PS1::}
::PS1::
::PS1::function Write-Red {
::PS1::    param([string]$Message)
::PS1::    Write-Host $Message -ForegroundColor Red
::PS1::}
::PS1::
::PS1::function Get-SteamRoot {
::PS1::    $candidates = New-Object System.Collections.Generic.List[string]
::PS1::
::PS1::    try {
::PS1::        $reg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction Stop
::PS1::        if ($reg.SteamPath) {
::PS1::            $candidates.Add($reg.SteamPath)
::PS1::        }
::PS1::    } catch {
::PS1::    }
::PS1::
::PS1::    try {
::PS1::        $reg2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction Stop
::PS1::        if ($reg2.InstallPath) {
::PS1::            $candidates.Add($reg2.InstallPath)
::PS1::        }
::PS1::    } catch {
::PS1::    }
::PS1::
::PS1::    if (${env:ProgramFiles(x86)}) {
::PS1::        $candidates.Add((Join-Path ${env:ProgramFiles(x86)} "Steam"))
::PS1::    }
::PS1::
::PS1::    foreach ($candidate in ($candidates | Select-Object -Unique)) {
::PS1::        if ($candidate -and (Test-Path (Join-Path $candidate "steam.exe"))) {
::PS1::            return $candidate
::PS1::        }
::PS1::    }
::PS1::
::PS1::    return $null
::PS1::}
::PS1::
::PS1::function Get-SteamExeCandidates {
::PS1::    param([string]$SteamRoot)
::PS1::
::PS1::    $candidates = New-Object System.Collections.Generic.List[string]
::PS1::
::PS1::    if ($SteamRoot) {
::PS1::        $candidates.Add((Join-Path $SteamRoot "steam.exe")) | Out-Null
::PS1::    }
::PS1::
::PS1::    try {
::PS1::        $reg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction Stop
::PS1::        if ($reg.SteamExe) {
::PS1::            $candidates.Add($reg.SteamExe) | Out-Null
::PS1::        }
::PS1::    } catch {
::PS1::    }
::PS1::
::PS1::    try {
::PS1::        $reg2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction Stop
::PS1::        if ($reg2.InstallPath) {
::PS1::            $candidates.Add((Join-Path $reg2.InstallPath "steam.exe")) | Out-Null
::PS1::        }
::PS1::    } catch {
::PS1::    }
::PS1::
::PS1::    return @($candidates | Where-Object { $_ } | Select-Object -Unique)
::PS1::}
::PS1::
::PS1::function Get-LibraryPaths {
::PS1::    param([string]$SteamRoot)
::PS1::
::PS1::    $libraryFile = Join-Path $SteamRoot "steamapps\libraryfolders.vdf"
::PS1::    if (-not (Test-Path $libraryFile)) {
::PS1::        throw "Steam libraryfolders.vdf was not found at: $libraryFile"
::PS1::    }
::PS1::
::PS1::    $raw = Get-Content $libraryFile -Raw
::PS1::    $paths = [regex]::Matches($raw, '"path"\s*"([^"]+)"') | ForEach-Object {
::PS1::        $_.Groups[1].Value -replace '\\\\', '\'
::PS1::    }
::PS1::
::PS1::    $paths = @($paths | Where-Object { $_ } | Select-Object -Unique)
::PS1::    if ($paths.Count -eq 0) {
::PS1::        $paths = @($SteamRoot)
::PS1::    }
::PS1::
::PS1::    return $paths
::PS1::}
::PS1::
::PS1::function Invoke-WithRetry {
::PS1::    param(
::PS1::        [scriptblock]$Action,
::PS1::        [int]$Attempts = 8,
::PS1::        [int]$DelayMilliseconds = 500
::PS1::    )
::PS1::
::PS1::    $lastError = $null
::PS1::    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
::PS1::        try {
::PS1::            return & $Action
::PS1::        } catch {
::PS1::            $lastError = $_
::PS1::            if ($attempt -ge $Attempts) {
::PS1::                throw
::PS1::            }
::PS1::
::PS1::            Start-Sleep -Milliseconds $DelayMilliseconds
::PS1::        }
::PS1::    }
::PS1::
::PS1::    if ($lastError) {
::PS1::        throw $lastError.Exception
::PS1::    }
::PS1::}
::PS1::
::PS1::function Get-BackupSearchRoots {
::PS1::    param([string]$BatchRoot)
::PS1::
::PS1::    $roots = New-Object System.Collections.Generic.List[string]
::PS1::    if ($BatchRoot) {
::PS1::        $roots.Add((Join-Path $BatchRoot "steam_manifest_backups")) | Out-Null
::PS1::    }
::PS1::
::PS1::    if ($env:USERPROFILE) {
::PS1::        $roots.Add((Join-Path $env:USERPROFILE "Downloads\steam_manifest_backups")) | Out-Null
::PS1::    }
::PS1::
::PS1::    return @($roots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
::PS1::}
::PS1::
::PS1::function Get-LatestGoodManifestBackup {
::PS1::    param(
::PS1::        [string]$ManifestPath,
::PS1::        [string[]]$BackupSearchRoots
::PS1::    )
::PS1::
::PS1::    $fileName = [System.IO.Path]::GetFileName($ManifestPath)
::PS1::    foreach ($backupSearchRoot in @($BackupSearchRoots)) {
::PS1::        if (-not $backupSearchRoot -or -not (Test-Path $backupSearchRoot)) {
::PS1::            continue
::PS1::        }
::PS1::
::PS1::        $candidate = Get-ChildItem -LiteralPath $backupSearchRoot -Directory -ErrorAction SilentlyContinue |
::PS1::            Sort-Object Name -Descending |
::PS1::            ForEach-Object { Join-Path $_.FullName $fileName } |
::PS1::            Where-Object {
::PS1::                if (-not (Test-Path $_)) {
::PS1::                    return $false
::PS1::                }
::PS1::
::PS1::                $item = Get-Item -LiteralPath $_ -ErrorAction SilentlyContinue
::PS1::                return $item -and $item.Length -gt 0
::PS1::            } |
::PS1::            Select-Object -First 1
::PS1::
::PS1::        if ($candidate) {
::PS1::            return $candidate
::PS1::        }
::PS1::    }
::PS1::
::PS1::    return $null
::PS1::}
::PS1::
::PS1::function Get-ProcessRoots {
::PS1::    param([string]$SteamRoot)
::PS1::
::PS1::    $roots = New-Object System.Collections.Generic.List[string]
::PS1::    if ($SteamRoot) {
::PS1::        try {
::PS1::            $roots.Add((Resolve-Path $SteamRoot).Path) | Out-Null
::PS1::        } catch {
::PS1::            $roots.Add($SteamRoot) | Out-Null
::PS1::        }
::PS1::    }
::PS1::
::PS1::    $libraryFile = if ($SteamRoot) { Join-Path $SteamRoot "steamapps\libraryfolders.vdf" } else { $null }
::PS1::    if ($libraryFile -and (Test-Path $libraryFile)) {
::PS1::        $raw = Get-Content $libraryFile -Raw
::PS1::        [regex]::Matches($raw, '"path"\s*"([^"]+)"') | ForEach-Object {
::PS1::            $path = $_.Groups[1].Value -replace '\\\\', '\'
::PS1::            if ($path) {
::PS1::                try {
::PS1::                    $roots.Add((Resolve-Path $path).Path) | Out-Null
::PS1::                } catch {
::PS1::                    $roots.Add($path) | Out-Null
::PS1::                }
::PS1::            }
::PS1::        }
::PS1::    }
::PS1::
::PS1::    return @($roots | Select-Object -Unique)
::PS1::}
::PS1::
::PS1::function Close-SteamProcesses {
::PS1::    param([string]$SteamRoot)
::PS1::
::PS1::    $roots = Get-ProcessRoots -SteamRoot $SteamRoot
::PS1::    $steamNames = @('steam', 'steamwebhelper', 'steamservice', 'gameoverlayui')
::PS1::    $waitForExit = {
::PS1::        param([int]$Seconds = 30)
::PS1::        $deadline = (Get-Date).AddSeconds($Seconds)
::PS1::        do {
::PS1::            $remaining = Get-Process -ErrorAction SilentlyContinue | Where-Object {
::PS1::                $proc = $_
::PS1::                if ($steamNames -contains $proc.Name) { return $true }
::PS1::                if (-not $proc.Path) { return $false }
::PS1::                foreach ($root in $roots) {
::PS1::                    if (-not $root) { continue }
::PS1::                    $prefix = $root.TrimEnd('\') + '\'
::PS1::                    if ($proc.Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or $proc.Path.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) {
::PS1::                        return $true
::PS1::                    }
::PS1::                }
::PS1::                return $false
::PS1::            }
::PS1::
::PS1::            if (-not $remaining) {
::PS1::                return $true
::PS1::            }
::PS1::
::PS1::            Start-Sleep -Seconds 1
::PS1::        } while ((Get-Date) -lt $deadline)
::PS1::
::PS1::        return $false
::PS1::    }
::PS1::    $targets = Get-Process -ErrorAction SilentlyContinue | Where-Object {
::PS1::        $proc = $_
::PS1::        if ($steamNames -contains $proc.Name) { return $true }
::PS1::        if (-not $proc.Path) { return $false }
::PS1::        foreach ($root in $roots) {
::PS1::            if (-not $root) { continue }
::PS1::            $prefix = $root.TrimEnd('\') + '\'
::PS1::            if ($proc.Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -or $proc.Path.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)) {
::PS1::                return $true
::PS1::            }
::PS1::        }
::PS1::        return $false
::PS1::    }
::PS1::
::PS1::    $targets | Sort-Object Id -Unique | Stop-Process -Force -ErrorAction SilentlyContinue
::PS1::    & $waitForExit 30 | Out-Null
::PS1::}
::PS1::
::PS1::function Wait-ForMainSteamProcess {
::PS1::    param(
::PS1::        [string]$SteamRoot,
::PS1::        [int]$Seconds = 20
::PS1::    )
::PS1::
::PS1::    $deadline = (Get-Date).AddSeconds($Seconds)
::PS1::    $expectedPath = if ($SteamRoot) { Join-Path $SteamRoot "steam.exe" } else { $null }
::PS1::
::PS1::    do {
::PS1::        $steamProcess = Get-Process -Name "steam" -ErrorAction SilentlyContinue | Where-Object {
::PS1::            if (-not $expectedPath) {
::PS1::                return $true
::PS1::            }
::PS1::
::PS1::            if (-not $_.Path) {
::PS1::                return $false
::PS1::            }
::PS1::
::PS1::            return $_.Path.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)
::PS1::        } | Select-Object -First 1
::PS1::
::PS1::        if ($steamProcess) {
::PS1::            return $true
::PS1::        }
::PS1::
::PS1::        Start-Sleep -Seconds 1
::PS1::    } while ((Get-Date) -lt $deadline)
::PS1::
::PS1::    return $false
::PS1::}
::PS1::
::PS1::function Start-Steam {
::PS1::    param([string]$SteamRoot)
::PS1::
::PS1::    $steamExeCandidates = Get-SteamExeCandidates -SteamRoot $SteamRoot
::PS1::    Start-Sleep -Seconds 3
::PS1::
::PS1::    foreach ($steamExe in $steamExeCandidates) {
::PS1::        if (-not (Test-Path $steamExe)) {
::PS1::            continue
::PS1::        }
::PS1::
::PS1::        $steamDir = Split-Path -Parent $steamExe
::PS1::
::PS1::        try {
::PS1::            Start-Process -FilePath $steamExe -WorkingDirectory $steamDir | Out-Null
::PS1::            if (Wait-ForMainSteamProcess -SteamRoot $SteamRoot -Seconds 15) {
::PS1::                return $true
::PS1::            }
::PS1::        } catch {
::PS1::        }
::PS1::
::PS1::        try {
::PS1::            $escapedExe = $steamExe.Replace("'", "''")
::PS1::            $escapedDir = $steamDir.Replace("'", "''")
::PS1::            $launchCommand = "Start-Sleep -Seconds 5; Start-Process -FilePath '{0}' -WorkingDirectory '{1}'" -f $escapedExe, $escapedDir
::PS1::            Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-Command", $launchCommand) -WindowStyle Hidden | Out-Null
::PS1::            if (Wait-ForMainSteamProcess -SteamRoot $SteamRoot -Seconds 20) {
::PS1::                return $true
::PS1::            }
::PS1::        } catch {
::PS1::        }
::PS1::    }
::PS1::
::PS1::    try {
::PS1::        Start-Process -FilePath "explorer.exe" -ArgumentList "steam://open/main" | Out-Null
::PS1::        if (Wait-ForMainSteamProcess -SteamRoot $SteamRoot -Seconds 20) {
::PS1::            return $true
::PS1::        }
::PS1::    } catch {
::PS1::    }
::PS1::
::PS1::    return $false
::PS1::}
::PS1::
::PS1::function Set-HighPriorityUpdate {
::PS1::    param(
::PS1::        [string]$ManifestPath,
::PS1::        [string]$BackupRoot,
::PS1::        [string[]]$BackupSearchRoots
::PS1::    )
::PS1::
::PS1::    $backupFile = Join-Path $BackupRoot ([System.IO.Path]::GetFileName($ManifestPath))
::PS1::    Invoke-WithRetry -Action {
::PS1::        Copy-Item -LiteralPath $ManifestPath -Destination $backupFile -Force
::PS1::    } | Out-Null
::PS1::    $tempFile = $ManifestPath + ".codex_tmp"
::PS1::
::PS1::    $raw = Invoke-WithRetry -Action {
::PS1::        Get-Content -LiteralPath $ManifestPath -Raw
::PS1::    }
::PS1::    $recoveredFrom = $null
::PS1::    if ([string]::IsNullOrWhiteSpace($raw)) {
::PS1::        $recoveredFrom = Get-LatestGoodManifestBackup -ManifestPath $ManifestPath -BackupSearchRoots $BackupSearchRoots
::PS1::        if (-not $recoveredFrom) {
::PS1::            return [pscustomobject]@{
::PS1::                Name   = [System.IO.Path]::GetFileName($ManifestPath)
::PS1::                Status = "SkippedEmpty"
::PS1::                Path   = $ManifestPath
::PS1::                Reason = "Manifest is empty and no non-empty backup was available."
::PS1::            }
::PS1::        }
::PS1::
::PS1::        $raw = Get-Content -LiteralPath $recoveredFrom -Raw
::PS1::        if ([string]::IsNullOrWhiteSpace($raw)) {
::PS1::            return [pscustomobject]@{
::PS1::                Name   = [System.IO.Path]::GetFileName($ManifestPath)
::PS1::                Status = "SkippedEmpty"
::PS1::                Path   = $ManifestPath
::PS1::                Reason = "Manifest is empty and the latest backup was also empty."
::PS1::            }
::PS1::        }
::PS1::    }
::PS1::
::PS1::    $name = if ($raw -match '"name"\s*"([^"]+)"') { $matches[1] } else { [System.IO.Path]::GetFileNameWithoutExtension($ManifestPath) }
::PS1::
::PS1::    if (-not $recoveredFrom -and $raw -match '"AutoUpdateBehavior"\s*"2"') {
::PS1::        return [pscustomobject]@{
::PS1::            Name   = $name
::PS1::            Status = "AlreadySet"
::PS1::            Path   = $ManifestPath
::PS1::        }
::PS1::    }
::PS1::
::PS1::    $updated = $raw
::PS1::    $status = if ($recoveredFrom) { "Recovered" } else { "Updated" }
::PS1::    if ($raw -match '"AutoUpdateBehavior"\s*"2"') {
::PS1::        $updated = $raw
::PS1::    } elseif ($raw -match '"AutoUpdateBehavior"\s*"[^"]+"') {
::PS1::        $updated = [regex]::Replace($raw, '"AutoUpdateBehavior"\s*"[^"]+"', "`"AutoUpdateBehavior`"`t`t`"2`"", 1)
::PS1::        if ($recoveredFrom) {
::PS1::            $status = "RecoveredAndUpdated"
::PS1::        }
::PS1::    } elseif ($raw -match '"TargetBuildID"\s*"[^"]+"') {
::PS1::        $updated = [regex]::Replace($raw, '("TargetBuildID"\s*"[^"]+")', "`$1`r`n`t`"AutoUpdateBehavior`"`t`t`"2`"", 1)
::PS1::        if ($recoveredFrom) {
::PS1::            $status = "RecoveredAndUpdated"
::PS1::        }
::PS1::    } elseif ($raw -match '"ScheduledAutoUpdate"\s*"[^"]+"') {
::PS1::        $updated = [regex]::Replace($raw, '("ScheduledAutoUpdate"\s*"[^"]+")', "`$1`r`n`t`"AutoUpdateBehavior`"`t`t`"2`"", 1)
::PS1::        if ($recoveredFrom) {
::PS1::            $status = "RecoveredAndUpdated"
::PS1::        }
::PS1::    } elseif ($raw -match '"UpdateResult"\s*"[^"]+"') {
::PS1::        $updated = [regex]::Replace($raw, '("UpdateResult"\s*"[^"]+")', "`$1`r`n`t`"AutoUpdateBehavior`"`t`t`"2`"", 1)
::PS1::        if ($recoveredFrom) {
::PS1::            $status = "RecoveredAndUpdated"
::PS1::        }
::PS1::    } else {
::PS1::        throw "Could not find a safe insertion point for AutoUpdateBehavior."
::PS1::    }
::PS1::
::PS1::    try {
::PS1::        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
::PS1::        Invoke-WithRetry -Action {
::PS1::            [System.IO.File]::WriteAllText($tempFile, $updated, $utf8NoBom)
::PS1::        } | Out-Null
::PS1::        $verifyTemp = Get-Content -LiteralPath $tempFile -Raw
::PS1::        if ($verifyTemp -notmatch '"AutoUpdateBehavior"\s*"2"') {
::PS1::            throw "Verification failed after writing the temporary manifest."
::PS1::        }
::PS1::
::PS1::        Invoke-WithRetry -Action {
::PS1::            Move-Item -LiteralPath $tempFile -Destination $ManifestPath -Force
::PS1::        } | Out-Null
::PS1::    } catch {
::PS1::        if (Test-Path $tempFile) {
::PS1::            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
::PS1::        }
::PS1::
::PS1::        throw
::PS1::    }
::PS1::
::PS1::    $verify = Get-Content -LiteralPath $ManifestPath -Raw
::PS1::    if ($verify -notmatch '"AutoUpdateBehavior"\s*"2"') {
::PS1::        throw "Verification failed after writing the updated manifest."
::PS1::    }
::PS1::
::PS1::    return [pscustomobject]@{
::PS1::        Name   = $name
::PS1::        Status = $status
::PS1::        Path   = $ManifestPath
::PS1::        RecoverySource = $recoveredFrom
::PS1::    }
::PS1::}
::PS1::
::PS1::$steamRoot = if ($SteamRootOverride) { $SteamRootOverride } else { Get-SteamRoot }
::PS1::if (-not $steamRoot) {
::PS1::    throw "Steam installation path could not be found."
::PS1::}
::PS1::
::PS1::switch ($Mode) {
::PS1::    "CloseProcesses" {
::PS1::        Close-SteamProcesses -SteamRoot $steamRoot
::PS1::        exit 0
::PS1::    }
::PS1::    "LaunchSteam" {
::PS1::        if (Start-Steam -SteamRoot $steamRoot) {
::PS1::            exit 0
::PS1::        }
::PS1::
::PS1::        exit 1
::PS1::    }
::PS1::    "Update" {
::PS1::        Write-Green ("Steam root: " + $steamRoot)
::PS1::
::PS1::        $libraryPaths = Get-LibraryPaths -SteamRoot $steamRoot
::PS1::        Write-Green ("Detected library folders: " + $libraryPaths.Count)
::PS1::        foreach ($path in $libraryPaths) {
::PS1::            Write-Green ("  - " + $path)
::PS1::        }
::PS1::
::PS1::        $manifests = foreach ($libraryPath in $libraryPaths) {
::PS1::            $steamAppsPath = Join-Path $libraryPath "steamapps"
::PS1::            if (Test-Path $steamAppsPath) {
::PS1::                Get-ChildItem -LiteralPath $steamAppsPath -Filter "appmanifest_*.acf" -File -ErrorAction SilentlyContinue
::PS1::            }
::PS1::        }
::PS1::
::PS1::        $manifests = @($manifests | Sort-Object FullName -Unique)
::PS1::        if ($manifests.Count -eq 0) {
::PS1::            throw "No installed Steam app manifests were found."
::PS1::        }
::PS1::
::PS1::        $backupBase = if ($BatchRoot) { $BatchRoot } elseif ($env:TEMP) { $env:TEMP } else { $PWD.Path }
::PS1::        $backupSearchRoots = Get-BackupSearchRoots -BatchRoot $backupBase
::PS1::        $backupRoot = Join-Path $backupBase ("steam_manifest_backups\" + (Get-Date -Format "yyyyMMdd_HHmmss"))
::PS1::        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
::PS1::        Write-Green ("Backup folder: " + $backupRoot)
::PS1::        Write-Green ("Installed manifests found: " + $manifests.Count)
::PS1::        Write-Host ""
::PS1::
::PS1::        $updatedCount = 0
::PS1::        $recoveredCount = 0
::PS1::        $alreadySetCount = 0
::PS1::        $warningCount = 0
::PS1::        $failed = New-Object System.Collections.Generic.List[string]
::PS1::
::PS1::        foreach ($manifest in $manifests) {
::PS1::            try {
::PS1::                $result = Set-HighPriorityUpdate -ManifestPath $manifest.FullName -BackupRoot $backupRoot -BackupSearchRoots $backupSearchRoots
::PS1::                if ($result.Status -eq "Updated") {
::PS1::                    $updatedCount++
::PS1::                    Write-Green ("Updated: " + $result.Name)
::PS1::                } elseif ($result.Status -eq "Recovered") {
::PS1::                    $recoveredCount++
::PS1::                    Write-Green ("Recovered From Backup: " + $result.Name)
::PS1::                } elseif ($result.Status -eq "RecoveredAndUpdated") {
::PS1::                    $recoveredCount++
::PS1::                    Write-Green ("Recovered And Updated: " + $result.Name)
::PS1::                } elseif ($result.Status -eq "SkippedEmpty") {
::PS1::                    $warningCount++
::PS1::                    $failed.Add(($result.Path + " :: " + $result.Reason)) | Out-Null
::PS1::                    Write-Yellow ("Skipped Empty Manifest: " + $result.Name)
::PS1::                } else {
::PS1::                    $alreadySetCount++
::PS1::                    Write-Aqua ("Already Set: " + $result.Name)
::PS1::                }
::PS1::            } catch {
::PS1::                $warningCount++
::PS1::                $failed.Add(($manifest.FullName + " :: " + $_.Exception.Message)) | Out-Null
::PS1::                Write-Red ("Failed: " + $manifest.FullName)
::PS1::                Write-Red ("  " + $_.Exception.Message)
::PS1::            }
::PS1::        }
::PS1::
::PS1::        $summaryFile = Join-Path $backupRoot "summary.txt"
::PS1::        $summary = @(
::PS1::            "Steam root: $steamRoot"
::PS1::            "Library folders: $($libraryPaths.Count)"
::PS1::            "Manifest count: $($manifests.Count)"
::PS1::            "Updated count: $updatedCount"
::PS1::            "Recovered count: $recoveredCount"
::PS1::            "Already set count: $alreadySetCount"
::PS1::            "Warning count: $warningCount"
::PS1::            "Failed count: $($failed.Count)"
::PS1::        )
::PS1::        $summary | Set-Content -LiteralPath $summaryFile
::PS1::
::PS1::        if ($failed.Count -gt 0) {
::PS1::            $failedFile = Join-Path $backupRoot "failed.txt"
::PS1::            $failed | Set-Content -LiteralPath $failedFile
::PS1::            Write-Host ""
::PS1::            Write-Yellow ("Warnings were logged to: " + $failedFile)
::PS1::        }
::PS1::
::PS1::        Write-Host ""
::PS1::        Write-Green ("Updated count: " + $updatedCount)
::PS1::        Write-Green ("Recovered count: " + $recoveredCount)
::PS1::        Write-Green ("Already set count: " + $alreadySetCount)
::PS1::        Write-Green ("Warning count: " + $warningCount)
::PS1::        Write-Green ("Failed count: " + $failed.Count)
::PS1::        Write-Green ("Summary written to: " + $summaryFile)
::PS1::        if ($warningCount -gt 0) {
::PS1::            Write-Yellow ("PROCESS FINISHED WITH WARNING.")
::PS1::            exit 3
::PS1::        }
::PS1::
::PS1::        Write-Green ("PROCESS FINISHED.")
::PS1::        exit 0
::PS1::    }
::PS1::    default {
::PS1::        throw "Unknown mode: $Mode"
::PS1::    }
::PS1::}
