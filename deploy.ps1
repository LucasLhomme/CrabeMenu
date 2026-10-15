param(
    [switch]$Full
)

$ErrorActionPreference = "Stop"

$gameDir = "D:\SteamLibrary\steamapps\common\Disney Infinity 3.0 Gold Edition"
$modsTarget = Join-Path $gameDir "mods"
$menuTarget = Join-Path $modsTarget "crabemenu"
$menuItems = @("mod.json", "main.lua", "core", "ui", "modules")

function Remove-Bom([string]$root) {
    Get-ChildItem -Path $root -Recurse -Filter *.lua | ForEach-Object {
        $bytes = [IO.File]::ReadAllBytes($_.FullName)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            [IO.File]::WriteAllBytes($_.FullName, $bytes[3..($bytes.Length - 1)])
        }
    }
}

if (!(Test-Path $gameDir)) {
    Write-Error "Game folder not found: $gameDir"
    exit 1
}

if (!(Test-Path $modsTarget)) { New-Item -ItemType Directory -Force -Path $modsTarget | Out-Null }

if (Test-Path $menuTarget) {
    Get-ChildItem -Path $menuTarget -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Force -Path $menuTarget | Out-Null
}
foreach ($item in $menuItems) {
    Copy-Item -Path (Join-Path $PSScriptRoot $item) -Destination $menuTarget -Recurse -Force
}
Remove-Bom $menuTarget
Write-Host "[OK] CrabeMenu -> $menuTarget" -ForegroundColor Green

$legacyMods = @("crabemenu.lua", "playable_anywhere")
foreach ($old in $legacyMods) {
    $path = Join-Path $modsTarget $old
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force
        Write-Host "[OK] Removed legacy $path (feature is built into CrabeMenu)" -ForegroundColor Green
    }
}

if (-not $Full) {
    Write-Host "Deployment complete. Use -Full to also sync the loader DLL and companion mods." -ForegroundColor Cyan
    exit 0
}

$loaderRoot = "E:\Dev\DIM2\CrabeLoader"

# A 1.0 loader left as bink2w32.dll outranks CrabeLoader.asi, so the game's own Bink DLL goes back first.
function Restore-LegacyBink([string]$dir) {
    $legacyProxy = Join-Path $dir "bink2w32.dll"
    $legacyBackup = Join-Path $dir "bink2w32_orig.dll"
    if (Test-Path $legacyBackup) {
        try {
            Move-Item -Path $legacyBackup -Destination $legacyProxy -Force -ErrorAction Stop
            Write-Host "[OK] Game bink2w32.dll restored (CrabeLoader is CrabeLoader.asi since 1.1)" -ForegroundColor Green
        } catch {
            Write-Warning "bink2w32.dll is in use by the running game (legacy restore skipped)."
        }
        return
    }
    if ((Test-Path $legacyProxy) -and
        [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($legacyProxy)).Contains("CrabeLoader Proxy DLL")) {
        Write-Warning "bink2w32.dll is an old CrabeLoader and no bink2w32_orig.dll exists: run CrabeInstaller or Steam's file check."
    }
}

Restore-LegacyBink $gameDir
$buildCandidates = @(
    "$loaderRoot\build\vs2022-dll\Release",
    "$loaderRoot\Release",
    "$loaderRoot\build\Release"
)
$buildFolder = $buildCandidates | Where-Object { (Test-Path "$_\CrabeLoader.asi") -and (Test-Path "$_\dinput8.dll") } |
    Sort-Object { (Get-Item "$_\CrabeLoader.asi").LastWriteTime } -Descending | Select-Object -First 1
if ($buildFolder) {
    foreach ($file in @("CrabeLoader.asi", "dinput8.dll")) {
        try {
            Copy-Item -Path "$buildFolder\$file" -Destination "$gameDir\$file" -Force -ErrorAction Stop
            Write-Host "[OK] $file ($buildFolder) -> $gameDir" -ForegroundColor Green
        } catch {
            Write-Warning "$file is in use by the running game (sync skipped)."
        }
    }
} else {
    Write-Warning "No CrabeLoader.asi + dinput8.dll build found to deploy (build CrabeLoader 1.1 first)."
}

$windowMode = "$loaderRoot\mods\window_mode.lua"
if (Test-Path $windowMode) {
    Copy-Item -Path $windowMode -Destination "$modsTarget\window_mode.lua" -Force
    Write-Host "[OK] window_mode.lua -> $modsTarget" -ForegroundColor Green
}

$heroChars = Join-Path $modsTarget "crabe_heroes\characters"
if (!(Test-Path $heroChars)) { New-Item -ItemType Directory -Force -Path $heroChars | Out-Null }
if (Test-Path "$loaderRoot\characters") {
    Copy-Item -Path "$loaderRoot\characters\*.lua" -Destination $heroChars -Force
    Write-Host "[OK] Characters -> $heroChars" -ForegroundColor Green
}

foreach ($obsolete in @("api", "characters", "skilltrees")) {
    $path = Join-Path $gameDir $obsolete
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Removed obsolete $path" -ForegroundColor Green
    }
}

Remove-Bom $modsTarget
Write-Host "Full deployment complete (UTF-8 without BOM)." -ForegroundColor Cyan
