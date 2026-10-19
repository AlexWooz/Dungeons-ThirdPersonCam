# Packs only ThirdPersonCam's cooked assets into a .pak. The Mod Kit's own package.bat
# packs everything under Dungeons\, which would also include AnalogMove
# when both mods share one Mod Kit.
# Run the Mod Kit's cook_assets.bat first.
#   .\tools\package.ps1                      # dev build straight into ~mods
#   .\tools\package.ps1 -Out .\ThirdPersonCam.pak -Compress
param(
    [string]$ModKit = (Join-Path $PSScriptRoot '..\..\Dungeons-Mod-Kit'),
    [string]$Out = 'C:\Program Files (x86)\Steam\steamapps\common\MinecraftDungeons\Dungeons\Content\Paks\~mods\ThirdPersonCam.pak',
    [switch]$Compress
)

$ModKit = (Resolve-Path $ModKit).Path
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$cooked = Join-Path $ModKit 'Dungeons\Content'
$stage = Join-Path $PSScriptRoot '..\build\Dungeons'
$include = @(
    'Mods\ThirdPersonCam',
    'BPLoader\InGame\TPC_Ingame.*',
    'BPLoader\Lobby\TPC_Lobby.*'
)

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
foreach ($p in $include) {
    $items = Get-Item (Join-Path $cooked $p) -ErrorAction SilentlyContinue
    if (-not $items) { throw "Not cooked: $p (run cook_assets.bat)" }
    foreach ($i in $items) {
        $rel = $i.FullName.Substring($cooked.Length + 1)
        $dst = Join-Path $stage "Content\$rel"
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        Copy-Item $i.FullName $dst -Recurse -Force
    }
}

$stageRoot = Split-Path $stage
$pyArgs = @((Join-Path $ModKit 'Tools\py\u4pak.py'), 'pack', $Out, 'Dungeons', '-p')
if ($Compress) { $pyArgs += '-z' }
Push-Location $stageRoot
try { python @pyArgs } finally { Pop-Location }
Write-Host "Packed $Out"
