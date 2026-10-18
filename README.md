# Third-Person Camera for Minecraft Dungeons

A Blueprint mod for **Minecraft Dungeons** (Steam, v1.17.0.0, UE 4.22) that replaces the isometric camera with an over-the-shoulder camera you orbit with the right stick.

## Features
- **F6** toggles the third-person camera. The on/off state is remembered across levels and restarts.
- **Right stick** orbits the camera. Right-stick dodging is disabled while the camera is on, but the dodge button still works.
- The left stick moves the hero relative to the camera.
- **R3** recenters the camera behind the hero.
- Wall collision pulls the camera in front of walls and cliffs.
- **F7** opens a settings panel. Use Up/Down to select and Left/Right to change Distance, FOV, Sensitivity and Invert Y. Settings are saved automatically.

## Install
1. Install Dungeons Blueprint Loader 1.0 (`Blueprint-Loader.pak`) in your `~mods` folder.
2. Download `ThirdPersonCam.pak` from [Releases](../../releases) and put it in
   `<Steam>\steamapps\common\MinecraftDungeons\Dungeons\Content\Paks\~mods\`.

Settings are stored in `%LOCALAPPDATA%\Dungeons\Saved\SaveGames\ThirdPersonCam.sav`.

## Building from source
This repo contains only the mod's own files. The build uses Dokucraft's [Dungeons Mod Kit](https://github.com/Dokucraft/Dungeons-Mod-Kit).

Requirements: Unreal Engine 4.22, Python 3.8+, and Build Tools for Visual Studio 2019 (C++ workload, needed to compile the `BasePlayerController` stub).

1. Clone the Mod Kit next to this repo (`..\Dungeons-Mod-Kit`) and set up `Tools/user_settings` per its README.
2. Copy the mod into it: `.\tools\sync.ps1 -ToModKit` (use `-ModKit <path>` for another location).
3. Compile the editor module:
   `"<UE_4.22>\Engine\Build\BatchFiles\Build.bat" DungeonsEditor Win64 Development -Project="<ModKit>\UE4Project\Dungeons.uproject" -WaitMutex`
   If `UE4Project\Binaries\Win64` contains a `UE4Editor-Dungeons-NNNN.dll`, remove it; otherwise the editor loads that stale copy.
4. Open the project with `open_editor.bat`, which skips the Project Browser's compiler check.
5. Close the editor, then run `cook_assets.bat` and `package.bat` (dev build into `~mods`) or `Tools\pack_compressed.bat` (release).

After editing in Unreal, run `.\tools\sync.ps1 -FromModKit` to copy the changes back into this repo before committing.

### Layout
| Path | Contents |
|---|---|
| `ModKit/UE4Project/Content/Mods/ThirdPersonCam/` | `BP_ThirdPersonCam` (all logic), `SG_TPCSettings` (save), `W_TPCMenu` (F7 panel), `W_TPCDebug` |
| `ModKit/UE4Project/Content/BPLoader/{InGame,Lobby}/` | Loader levels that spawn the camera actor in missions and camp |
| `ModKit/UE4Project/Source/Dungeons/BasePlayerController.h` | Editor-only stub of the game's native class, exposing `RightStickDodgingEnabled` |
| `docs/TECHNICAL.md` | How the Blueprint works, game internals we found, and what didn't work |
| `tools/sync.ps1` | Copies the mod's files between this repo and a Mod Kit checkout |
| `release/README.txt` | The readme shipped alongside the `.pak` in releases |

## How it works (short)
The Blueprint Loader streams in a level containing `BP_ThirdPersonCam`. That actor switches the view target to its own spring-arm camera and reads the right stick directly. It disables the game's stick-dodge by setting the native `BasePlayerController.RightStickDodgingEnabled` every frame while active. See [docs/TECHNICAL.md](docs/TECHNICAL.md) for the details.
