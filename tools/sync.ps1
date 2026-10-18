# Copies the mod's own files between this repo and a Dungeons Mod Kit checkout.
#   .\tools\sync.ps1 -FromModKit   # after editing in Unreal: pull changes into the repo
#   .\tools\sync.ps1 -ToModKit     # on a fresh Mod Kit clone: install the mod's files into it
param(
    [switch]$FromModKit,
    [switch]$ToModKit,
    [string]$ModKit = (Join-Path $PSScriptRoot '..\..\Dungeons-Mod-Kit')
)

if ($FromModKit -eq $ToModKit) { throw 'Pass exactly one of -FromModKit or -ToModKit.' }

$repo = Join-Path $PSScriptRoot '..\ModKit'
$paths = @(
    'UE4Project\Content\Mods\ThirdPersonCam',
    'UE4Project\Content\BPLoader\InGame',
    'UE4Project\Content\BPLoader\Lobby',
    'UE4Project\Source\Dungeons\BasePlayerController.h',
    'open_editor.bat'
)

foreach ($p in $paths) {
    $src = if ($FromModKit) { Join-Path $ModKit $p } else { Join-Path $repo $p }
    $dst = if ($FromModKit) { Join-Path $repo $p } else { Join-Path $ModKit $p }
    if (-not (Test-Path $src)) { Write-Warning "Missing: $src"; continue }
    if ((Get-Item $src).PSIsContainer) {
        New-Item -ItemType Directory -Force $dst | Out-Null
        Copy-Item (Join-Path $src '*') $dst -Recurse -Force
    } else {
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        Copy-Item $src $dst -Force
    }
    Write-Host "Copied $p"
}
