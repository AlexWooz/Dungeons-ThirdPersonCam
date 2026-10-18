# Technical notes

How the mod works, what we learned about Minecraft Dungeons' internals (v1.17.0.0, UE 4.22, Steam), and what didn't work.

## Constraints
- Mods are Blueprints cooked with **UE 4.22.x** and shipped as a `.pak` in `Dungeons\Content\Paks\~mods`. No C++ can ship.
- **Dungeons Blueprint Loader 1.0** streams in any level placed in `/Game/BPLoader/Ingame` (missions), `/Game/BPLoader/Lobby` (camp) or `/Game/BPLoader/Menu`, at the world origin. Our levels only contain one `BP_ThirdPersonCam` actor.
- The Steam paks are AES-encrypted. FModel with the key (UE version `GAME_UE4_22`) mounts all 51 paks.
- `PrintString` is stripped in shipping builds, so debug output uses a UMG widget (`W_TPCDebug`).
- UE4SS v3.0.1 doesn't run: the Steam exe is packed (sections `.dungeon`/`.boot`, no `.text`), and UE4SS crashes before the code is unpacked.

## Assets
| Asset | Role |
|---|---|
| `BPLoader/InGame/TPC_Ingame`, `BPLoader/Lobby/TPC_Lobby` | Loader levels containing the camera actor |
| `Mods/ThirdPersonCam/BP_ThirdPersonCam` | All runtime logic |
| `Mods/ThirdPersonCam/SG_TPCSettings` | SaveGame, slot `ThirdPersonCam`: `Enabled`, `Distance`, `FOV`, `LookSpeed`, `InvertY` |
| `Mods/ThirdPersonCam/W_TPCMenu` | F7 settings panel (Border + `MenuText`) |
| `Mods/ThirdPersonCam/W_TPCDebug` | Debug text, used only when `ShowDebug` is on |
| `Source/Dungeons/BasePlayerController.h` | Editor-only stub of the game's native class (see below) |

## BP_ThirdPersonCam
**Components:** `DefaultSceneRoot` → `SpringArm` (socket offset 0/50/40, location lag 10, rotation lag 10, built-in collision test **off**, no pawn-control rotation, no inherited rotation) → `Camera`. The actor ticks in **Post Update Work**.

**BeginPlay**
1. `PC = GetPlayerController(0)`, then `EnableInput(PC)`.
2. Load slot `ThirdPersonCam` (or create a fresh `SG_TPCSettings`) into `Settings`.
3. `ApplySettings`: arm length ← Distance, Camera FOV ← FOV, `LookSpeed` ← LookSpeed.
4. Create `W_TPCMenu` (not shown yet).
5. If `Settings.Enabled`, wait 0.5 s, then `TurnOn`.

**Toggle (F6)**
- **On** (`TurnOn` event or F6 while off): cache `OriginalViewTarget = PC.GetViewTarget()` (the hero, `BP_AlexCharacter_C_0`), `Recenter`, `SetViewTargetWithBlend(self, 0.3)`, `Active = true`, `SetStickRoll(false)`, save `Enabled = true`.
- **Off:** `SetViewTargetWithBlend(OriginalViewTarget, 0.3)`, `Active = false`, `SetStickRoll(true)`, save `Enabled = false`.
- **EndPlay** while active: `SetStickRoll(true)`, so the next level starts clean.

**Tick (while Active)**
- `Yaw += StickX × LookSpeed × dt`; `Pitch = clamp(Pitch − StickY × LookSpeed × dt × InvSign, −70, 10)`, where `InvSign = InvertY ? −1 : 1`. The stick values come from `Gamepad Right Thumbstick X/Y-Axis` key events.
- Actor location = pawn location + (0, 0, 60). SpringArm world rotation = (Pitch, Yaw, 0).
- Cast PC → `BasePlayerController`, set `RightStickDodgingEnabled = false` (every frame, because the game rewrites it).
- **Wall collision:** `SphereTraceForObjects` (radius 12, WorldStatic + WorldDynamic, ignore `TraceIgnore`) from the pivot to `pivot − Forward(Pitch, Yaw) × Distance`. A hit without `Initial Overlap` sets the arm length to `max(hit distance, 40)`; otherwise it uses `Settings.Distance`. Any actor the trace starts inside is added to `TraceIgnore`, and the pawn is always added.

**R3** (`Gamepad Right Thumbstick Button`, only while Active) → `Recenter`: Yaw = pawn yaw, Pitch = −10.

**F7 panel:** F7 toggles `MenuOpen` (`AddToViewport` / `RemoveFromParent`). Up/Down: `MenuRow = (MenuRow ± 1) mod 4`. Left/Right: `AdjustSettings(±1)`, which then runs `ApplySettings → SaveSettings → RefreshMenu`.

| Setting | Step | Range |
|---|---|---|
| Distance | 25 | 150–1000 |
| FOV | 5 | 60–120 |
| Sensitivity | 10 | 30–400 |
| Invert Y | toggle | |

`RefreshMenu` builds the text with one Format Text node; each line's `>` marker is chosen by `Select String (MenuRow == n)`.

## Game internals (findings)
- **Base template:** UE TopDown. Redirects map `TP_TopDownPlayerController` → `DungeonsPlayerController` and `TP_TopDownGameMode` → `DungeonsGameMode` (native, `/Script/Dungeons`).
- **Game modes:**
  - `BP_IngameGameMode` (missions) and `BP_LobbyGameMode` (camp) both use `PlayerControllerClass = BP_PlayerController`, `DefaultPawnClass = BP_AlexCharacter` and `HUD = DungeonHUD`.
  - The iso camera is native on `DungeonsCharacter` (`FixedCameraPitch = −45`, `FixedCameraDistance = 1500` in `DefaultGame.ini`).
  - `BP_AlexCharacter` has no camera component in Blueprint.
- **Camera manager:** `BP_DungeonsCameraManager` (→ native `DungeonsPlayerCameraManager`) has no Blueprint logic and **honors `SetViewTarget`**. Its modifiers (camera shake, night post-process) apply to our camera too.
- **Movement:** the game already steers relative to the active view, so the left stick follows our camera with no extra work.
- **Input names** (`DefaultInput.ini`):
  - Right stick → `RollForward/Backward/Left/RightGamepad`; left stick → `Move*Gamepad`, all at scale +1.
  - R3 → `RightStickClick`.
  - F1–F5, F9 (`DeleteCharacter`) and F11 are taken; F6 and F7 are free.
- **Stick dodge:** controlled by the native `bool RightStickDodgingEnabled` (with `RightStickHasReset`) on `/Script/Dungeons.BasePlayerController`.
  - `BP_PlayerController` turns it off while the quick-chat wheel is open, so it's Blueprint-writable.
  - The cvar `Dungeons.Experimental.EnableDodge` (read in `IsDodgeEnabled`) gates the Dodge *action* instead, so it isn't the stick dodge.
- **Camp level:** contains a level-wide brush volume (`AV10_Lobby_S3`, `BrushComponent0`) that object traces start inside. That's why the trace ignores initial overlaps.
- **Collision profile `HideableMesh`:** terrain the game fades for its iso camera. It ignores the Camera and Visibility channels, which is why the wall trace uses object types instead.

## The BasePlayerController stub
To set `RightStickDodgingEnabled` from Blueprint, the editor needs a class with that property, so `BasePlayerController.h` declares `ABasePlayerController : APlayerController` in the Mod Kit's `Dungeons` module, with the two bools as `BlueprintReadWrite`. The cooked Blueprint references `/Script/Dungeons.BasePlayerController:RightStickDodgingEnabled` by name, and at runtime that resolves to the game's real class. The module DLL is editor-only and never packaged.

Building it needs VS 2019 Build Tools. The Mod Kit ships a stale hot-reload `UE4Editor-Dungeons-8663.dll` that the editor loads instead of a fresh build, so delete it.

## What didn't work
- **Consume Input** on the right-stick key events doesn't stop the dodge. The game reads the stick outside the input-component stack.
- **Removing the `Roll*Gamepad` axis mappings** at runtime (`InputSettings.RemoveAxisMapping` + rebuild) doesn't stop it either. Re-adding them from EndPlay also **crashed the game on quit**, so never touch InputSettings during teardown.
- **`set BasePlayerController RightStickDodgingEnabled False`** via `ExecuteConsoleCommand` had no effect, either because it's blocked in shipping or because it got overwritten.
- **SpringArm's built-in collision test** collapses the arm into the hero, because the probe starts inside the pawn. It's replaced by the custom trace.
- **An editable config file** isn't possible: stock Blueprints can't read files, and the C++ module doesn't ship. Settings live in the SaveGame and the F7 panel.

## Known issues / ideas
- The wall collision snaps in instantly; it could be smoothed. The shoulder socket offset can still poke into walls.
- The game's terrain fading follows its own iso camera, not ours, so some low angles see through or behind geometry built for a top-down view.
- Mouse click-to-move still works and isn't camera-aware.
- The mod only affects the local player's view in multiplayer.
- Possible additions: lock-on (nearest enemy on attack), and a cutscene check that pauses if the view target changes to something other than self or the hero.
