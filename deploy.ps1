$ErrorActionPreference = "Stop"

$gameDir = "D:\SteamLibrary\steamapps\common\Disney Infinity 3.0 Gold Edition"
$modsTarget = Join-Path $gameDir "mods"
$apiTarget = Join-Path $gameDir "api"
$charsTarget = Join-Path $gameDir "characters"
$loaderApiSrc = "E:\Dev\DIM2\CrabeLoader\src\api"
$loaderCharsSrc = "E:\Dev\DIM2\CrabeLoader\characters"

if (!(Test-Path $gameDir)) {
    Write-Error "Game folder not found: $gameDir"
    exit 1
}

# 0. Sync C++ Proxy DLL
$dllCandidates = @(
    "E:\Dev\DIM2\CrabeLoader\build\vs2022-dll\Release\bink2w32.dll",
    "E:\Dev\DIM2\CrabeLoader\Release\bink2w32.dll",
    "E:\Dev\DIM2\CrabeLoader\build\Release\bink2w32.dll"
)
$dllSrc = $dllCandidates | Where-Object { Test-Path $_ } | Sort-Object { (Get-Item $_).LastWriteTime } -Descending | Select-Object -First 1
if ($dllSrc) {
    Copy-Item -Path $dllSrc -Destination "$gameDir\bink2w32.dll" -Force
    Write-Host "[OK] bink2w32.dll ($dllSrc) -> $gameDir" -ForegroundColor Green
} else {
    Write-Warning "No bink2w32.dll found to deploy!"
}

# 1. Sync mods
if (!(Test-Path $modsTarget)) { New-Item -ItemType Directory -Force -Path $modsTarget | Out-Null }
Copy-Item -Path "E:\Dev\DIM2\CrabeMenu\mods\crabemenu.lua" -Destination "$modsTarget\crabemenu.lua" -Force
Write-Host "[OK] crabemenu.lua -> $modsTarget" -ForegroundColor Green
if (Test-Path "E:\Dev\DIM2\CrabeLoader\mods\window_mode.lua") {
    Copy-Item -Path "E:\Dev\DIM2\CrabeLoader\mods\window_mode.lua" -Destination "$modsTarget\window_mode.lua" -Force
    Write-Host "[OK] window_mode.lua -> $modsTarget" -ForegroundColor Green
}

# 2. Clean obsolete api folder (API is now directly embedded into bink2w32.dll)
if (Test-Path $apiTarget) {
    Remove-Item -Path $apiTarget -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Removed obsolete $apiTarget (API is embedded in bink2w32.dll)" -ForegroundColor Green
}

# 3. Clean obsolete root folders (characters and skilltrees now live strictly inside mods/)
if (Test-Path $charsTarget) {
    Remove-Item -Path $charsTarget -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Cleaned obsolete root $charsTarget" -ForegroundColor Green
}
$skilltreesTarget = Join-Path $gameDir "skilltrees"
if (Test-Path $skilltreesTarget) {
    Remove-Item -Path $skilltreesTarget -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Cleaned obsolete root $skilltreesTarget" -ForegroundColor Green
}

# 4. Sync modular character pack under mods/crabe_heroes/
$heroModDir = Join-Path $modsTarget "crabe_heroes"
$heroModChars = Join-Path $heroModDir "characters"
if (!(Test-Path $heroModChars)) { New-Item -ItemType Directory -Force -Path $heroModChars | Out-Null }
if (Test-Path $loaderCharsSrc) {
    Copy-Item -Path "$loaderCharsSrc\*.lua" -Destination $heroModChars -Force
    Write-Host "[OK] Synced characters -> $heroModChars" -ForegroundColor Green
}

# 4. Strip BOM from all deployed Lua files
python -c "
from pathlib import Path
game_dir = Path(r'$gameDir')
for sub in ['mods', 'characters']:
    p = game_dir / sub
    if not p.exists(): continue
    for f in p.rglob('*.lua'):
        data = f.read_bytes()
        if data.startswith(b'\xef\xbb\xbf'):
            f.write_bytes(data[3:])
"

Write-Host "Deployment complete! Pure UTF-8 without BOM." -ForegroundColor Cyan
