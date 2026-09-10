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
$dllSrc = "E:\Dev\DIM2\CrabeLoader\build\Release\bink2w32.dll"
if (Test-Path $dllSrc) {
    Copy-Item -Path $dllSrc -Destination "$gameDir\bink2w32.dll" -Force
    Write-Host "[OK] bink2w32.dll -> $gameDir" -ForegroundColor Green
}

# 1. Sync mods
if (!(Test-Path $modsTarget)) { New-Item -ItemType Directory -Force -Path $modsTarget | Out-Null }
Copy-Item -Path "E:\Dev\DIM2\CrabeMenu\mods\crabemenu.lua" -Destination "$modsTarget\crabemenu.lua" -Force
Write-Host "[OK] crabemenu.lua -> $modsTarget" -ForegroundColor Green

# 2. Sync API files
if (!(Test-Path $apiTarget)) { New-Item -ItemType Directory -Force -Path $apiTarget | Out-Null }
if (Test-Path $apiTarget) {
    Remove-Item -Path "$apiTarget\*.lua" -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Force -Path $apiTarget | Out-Null
}
if (Test-Path $loaderApiSrc) {
    Copy-Item -Path "$loaderApiSrc\*.lua" -Destination $apiTarget -Force
    Write-Host "[OK] Synced all API modules -> $apiTarget" -ForegroundColor Green
}

# 3. Sync Characters
if (!(Test-Path $charsTarget)) { New-Item -ItemType Directory -Force -Path $charsTarget | Out-Null }
if (Test-Path $loaderCharsSrc) {
    Copy-Item -Path "$loaderCharsSrc\*.lua" -Destination $charsTarget -Force
    Write-Host "[OK] Synced character modules -> $charsTarget" -ForegroundColor Green
}

# 4. Strip BOM from all deployed Lua files
python -c "
from pathlib import Path
game_dir = Path(r'$gameDir')
for sub in ['api', 'mods', 'characters']:
    p = game_dir / sub
    if not p.exists(): continue
    for f in p.rglob('*.lua'):
        data = f.read_bytes()
        if data.startswith(b'\xef\xbb\xbf'):
            f.write_bytes(data[3:])
"

Write-Host "Deployment complete! Pure UTF-8 without BOM." -ForegroundColor Cyan
