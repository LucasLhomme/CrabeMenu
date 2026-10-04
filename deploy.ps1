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

if (Test-Path $menuTarget) { Remove-Item -Path $menuTarget -Recurse -Force }
New-Item -ItemType Directory -Force -Path $menuTarget | Out-Null
foreach ($item in $menuItems) {
    Copy-Item -Path (Join-Path $PSScriptRoot $item) -Destination $menuTarget -Recurse -Force
}
Remove-Bom $menuTarget
Write-Host "[OK] CrabeMenu -> $menuTarget" -ForegroundColor Green

$legacyMenu = Join-Path $modsTarget "crabemenu.lua"
if (Test-Path $legacyMenu) {
    Remove-Item -Path $legacyMenu -Force
    Write-Host "[OK] Removed legacy $legacyMenu (it would load the menu twice)" -ForegroundColor Green
}

if (-not $Full) {
    Write-Host "Deployment complete. Use -Full to also sync the loader DLL and companion mods." -ForegroundColor Cyan
    exit 0
}

$loaderRoot = "E:\Dev\DIM2\CrabeLoader"
$dllCandidates = @(
    "$loaderRoot\build\vs2022-dll\Release\bink2w32.dll",
    "$loaderRoot\Release\bink2w32.dll",
    "$loaderRoot\build\Release\bink2w32.dll"
)
$dllSource = $dllCandidates | Where-Object { Test-Path $_ } |
    Sort-Object { (Get-Item $_).LastWriteTime } -Descending | Select-Object -First 1
if ($dllSource) {
    try {
        Copy-Item -Path $dllSource -Destination "$gameDir\bink2w32.dll" -Force -ErrorAction Stop
        Write-Host "[OK] bink2w32.dll ($dllSource) -> $gameDir" -ForegroundColor Green
    } catch {
        Write-Warning "bink2w32.dll is in use by the running game (DLL sync skipped)."
    }
} else {
    Write-Warning "No bink2w32.dll found to deploy."
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
