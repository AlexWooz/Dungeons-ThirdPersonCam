# Third-person camera mod for Minecraft Dungeons (1)

## Context
20fpsguy's "third person mod (WIP)" for **Minecraft Dungeons II** (Nexus mods/15) replaces the isometric camera with an over-the-shoulder camera. It's built as Blueprints loaded by *that* game's Blueprint Loader 2.0 (ewanhowell5195), and it was built with Claude Code. Its features: right-stick orbit with the right-stick dodge disabled (dash moves to LB), R3 recenter, movement relative to the camera, lock-on, spring-arm wall collision, the normal camera during cutscenes, and an F6 toggle.

We want the same thing for **Minecraft Dungeons 1** (Unreal Engine 4.22, Steam copy, built on a Windows PC/VM):
- It ships as a `.pak` file in `Dungeons\Content\Paks\~mods`.
- The right stick controls the camera, and the stick roll is turned off while the mod is on.
- F6 turns it on and off.

### Key facts found
- **Dungeons 1 Blueprint Loader 1.0** (CCCode, Nexus mods/111) is itself just a `.pak`. It streams in any level placed in `/Game/BPLoader/Ingame` (when a mission starts), `/Game/BPLoader/Lobby` (camp) or `/Game/BPLoader/Menu`, at the world origin. So our mod is one level plus one Blueprint actor in those folders. It ships as one `.pak` that depends on the loader's `.pak`, which meets the "pure pak" goal. The loader has no settings UI, unlike Dungeons II's v2.0.
- Mods can't contain C++. Everything must be Blueprints cooked with **UE 4.22.x**, because other versions break.
- The **Steam paks are encrypted**, so we need the AES key for the final game version (1.17.x). Sources: FModel's `Unreal-Game-Keys` repo, or extract it ourselves (Steamless, then an AES key finder).

## Tools
| Tool | Purpose |
|---|---|
| UE 4.22.x (Epic launcher) | Create and cook the Blueprints |
| Dokucraft **Dungeons-Mod-Kit** (GitHub) + Python 3.8+ | Preconfigured `Dungeons.uproject`, `cook_assets.bat`, `package.bat` / `pack_compressed.bat` |
| **FModel** + AES key | Browse game paks: find `Config/DefaultInput.ini` action/axis names, and the player pawn, controller and camera classes |
| ~~UE4SS~~ | **Doesn't work.** v3.0.1 crashes on launch: an access violation in UE4SS.dll before it writes its log. The Steam exe is packed (its only code sections are `.dungeon` and `.boot`, with no `.text`), so UE4SS scans memory before the code is unpacked. It's disabled by renaming `Win64\dwmapi.dll` → `dwmapi.dll.disabled`. |
| Blueprint Loader 1.0 | Runtime injection |
| Camera Coordinates Overlay mod | Reference example of a loader-based mod |

## Discovery phase (must happen first, against real game files)
1. Get the AES key and open the paks in FModel. Read `DefaultInput.ini`, and note the axis and action names bound to `Gamepad_RightX/RightY` (roll direction), `Gamepad_LeftX/LeftY` (move), and the roll button.
2. ~~Use the UE4SS object dump~~ UE4SS can't run here (see Tools). Instead, inspect the hero, player controller and camera Blueprints in FModel (component lists and default properties), then confirm at runtime with a debug Blueprint loaded through the Blueprint Loader that calls `PrintString`. Things to find:
   - the hero's class (expected: a `Character` subclass with `CharacterMovementComponent`)
   - how the iso camera is built (a camera component on the pawn, a separate camera actor, or a custom `PlayerCameraManager`)
   - whether movement input is applied relative to the camera or in world space with a fixed yaw.
3. Check the cutscene path: does the game call `SetViewTarget` to a cine camera? We'll detect that change and hand control back.

### Discovery results so far
**AES key:** works. FModel mounts all 51 paks, with UE version `GAME_UE4_22`.

**`Dungeons/Config/DefaultInput.ini`** (exported from `pakchunk0`):
| Stick / button | Axis or action names | Notes |
|---|---|---|
| Right stick Y (`Gamepad_RightY`) | `RollForwardGamepad`, `RollBackwardGamepad` | Both use Scale +1, so the game splits the sign in code. |
| Right stick X (`Gamepad_RightX`) | `RollLeftGamepad`, `RollRightGamepad` | Same as above. |
| Left stick Y (`Gamepad_LeftY`) | `MoveForwardGamepad`, `MoveBackwardGamepad` | Same split pattern. |
| Left stick X (`Gamepad_LeftX`) | `MoveLeftGamepad`, `MoveRightGamepad` | |
| R3 | action `RightStickClick` | We can bind it for recenter. |
| L3 | action `LeftStickClick` | |
- The gamepad face buttons and shoulders only appear as generic actions (`GamepadLeftShoulder`, `GamepadRightTrigger`, …), and the gamepad roll button isn't listed. The game probably maps those in code or through its controls settings. We don't touch the roll button, so this doesn't block us.
- Function keys already used: F1–F5 (menus and ender pearls, plus Ctrl+F1–F5 debug view modes), **F9 (`DeleteCharacter`)** and F11 (fullscreen). **F6 is free** for the toggle. The discovery script uses F7 and F8.
**`DefaultEngine.ini`:**
- The game is built on UE's **TopDown template**. The class redirects map `TP_TopDownPlayerController` → `DungeonsPlayerController` and `TP_TopDownGameMode` → `DungeonsGameMode`, both native C++ (`/Script/Dungeons`). In that template the camera is a `CameraBoom` spring arm plus a camera on the *character*, so the iso camera is probably a component on the hero pawn (still to confirm).
- `GlobalDefaultGameMode=/Game/GameModes/Ingame/BP_IngameGameMode`. There's also `/Game/GameModes/Lobby/BP_LobbyGameMode` (camp) and `Menu/BP_MenuGameMode`. `GameInstanceClass=/Game/GameModes/BP_GameInstance`.
- **Game mode defaults** (`BP_IngameGameMode` → native `DungeonsGameMode`; `BP_LobbyGameMode` → native `LobbyGameMode`). Both modes use the same classes:
  - `PlayerControllerClass = /Game/Actors/Characters/Player/BP_PlayerController`
  - `DefaultPawnClass = /Game/Actors/Characters/Player/Alex/BP_AlexCharacter` (the hero in camp *and* missions)
  - `HUDClass = DungeonHUD` (native)
  - Neither game mode Blueprint overrides the camera manager. If the game uses a custom one, it's set on `BP_PlayerController` or in native code.
- **`BP_AlexCharacter`** → parent `BP_PlayerCharacter` (Blueprint) → native `DungeonsCharacter`:
  - **There's no `CameraComponent` in the Blueprint layer.** The only arms are the game's own `LovikaSpringArmComponent` (`/Script/Dungeons`, probably a subclass of `SpringArmComponent`; "Lovika" looks like the game's internal codename):
    - `LovikaSpringArm`, inherited from `BP_PlayerCharacter`, overridden to `RelativeLocation Z=-90`. What's attached to it is defined in `BP_PlayerCharacter`.
    - `LovikaSpringArm1_0`, on the capsule: `Z=+60`, no collision test, camera lag 9. Its only child is `PointLight_0`, the hidden "flashlight" light, so it's a light rig, not the camera.
  - So the iso camera is either native (created in `DungeonsCharacter`'s C++ from `FixedCameraPitch` and `FixedCameraDistance`) or attached to `LovikaSpringArm` in `BP_PlayerCharacter`. Either way, `SetViewTarget` to our own actor avoids it. What matters is whether a custom camera manager overrides the view target (check `BP_PlayerController`).
  - Capsule half-height is 110 and the mesh sits at Z −110, so the pawn origin is about at hip height. Our pivot offset of (0, 0, 60) puts the camera target near chest/shoulder height.
- **`BP_PlayerController`** → parent native `BasePlayerController`:
  - **`PlayerCameraManagerClass = /Game/Actors/BP_DungeonsCameraManager`.** The game has a custom camera manager (a Blueprint). If it overrides `BlueprintUpdateCamera` it may ignore the view target, so check it before relying on `SetViewTarget`.
  - The Blueprint's input bindings are all *actions* (Dodge, DodgeForward, Pause, Inventory, ToggleMap, …, mostly `bConsumeInput=true`). **There are no axis bindings here, so `Move*Gamepad` and `Roll*Gamepad` are bound in native code** (on the controller or the pawn). In UE 4.22, input components pushed via `EnableInput` sit *above* the controller's and pawn's own components in the input stack, so consuming those axis names from our actor should still block them. If the native code reads raw key state instead, use the `DefaultInput.ini` fallback.
  - `IsDodgeEnabled()` checks `GetConsoleVariableIntValue(<cvar>)`, so **a console variable gates dodging**. The cvar name is a string literal in the bytecode; a raw export of the `.uexp` would show it. It could be a cleaner way to turn off the stick roll (`ExecuteConsoleCommand`).
  - The controller shows a mouse cursor (`bShowMouseCursor=true`) and uses click events and a path-following component. Expect the mouse to still move the hero by clicking; that's a known limitation, since controllers are the target.
- **`BP_DungeonsCameraManager`** → parent native `DungeonsPlayerCameraManager`:
  - The Blueprint has **no functions or graphs**, so it doesn't override `BlueprintUpdateCamera` in Blueprint. Its defaults only set `Offset=0.1` (a native property) and `DefaultModifiers = [CameraModifier_CameraShake, BP_CameraModifier_Night]`. Those modifiers stack shake and night post-processing on whatever view is active, so they should work with our camera too.
  - We don't know whether the native `DungeonsPlayerCameraManager` overrides `UpdateViewTarget` in C++. **The MVP's F6 test settles it.** If the view stays isometric after `SetViewTarget`, switch to the fallback: drive the game's camera instead.
- FModel finds no Blueprint assets matching `CameraManager` or `PlayerController`, so both are native or engine defaults.
**`DefaultGame.ini`** (`ProjectVersion=1.17.0.0`):
- `[/Script/Dungeons.DungeonsCharacter] FixedCameraPitch=-45.0, FixedCameraDistance=1500.0`. This **confirms the iso camera belongs to the native hero class `DungeonsCharacter`**: a fixed −45° pitch at 1500 units, set from C++. Our `SetViewTarget` approach leaves it alone; we just stop viewing through it.
- Native class names to expect at runtime: `DungeonsCharacter` (hero base), `PlayerControllerBase` / `DungeonsPlayerController`, and `PlayerCharacterMovementComponent`.
- Auto-targeting (`AutoTarget*`) uses cones around the hero's facing (Active: melee 110°, shooting 40°, ranged 60°, radius 2000) rather than the camera. Aiming should keep working in third person as long as the hero faces where the player steers.

- **Collision profile `HideableMesh`: "Terrain hides when blocking camera view."** The game fades out terrain that blocks its iso camera, and that terrain **ignores the `Camera` and `Visibility` channels**. Our spring arm won't collide with those meshes, and the game's own fading may follow the iso camera rather than ours. We'll need to check this in-game. If it's a problem, run the spring-arm probe on a channel that does block terrain (for example `WorldStatic`, using a custom trace).

- **Design consequence:** the BP binds axis events for all four `Roll*Gamepad` names (reading RightX/RightY from them) and all four `Move*Gamepad` names, with Consume Input on. The game's movement and roll then see zero while the mod is active, and get the stick back after `DisableInput`.

The design below avoids referencing game-specific classes. It uses only engine types (`PlayerController`, `Pawn`, `Character`), so no dummy/stub assets are needed. If discovery shows that's impossible (for example, movement needs a game function), we'll add stub Blueprints at the matching `/Game/...` paths.

## In-game test results (2026-10-18, camp)
- MVP works: loader levels spawn the actor, `SetViewTargetWithBlend` is honored (original view target = `BP_AlexCharacter_C_0`), and the right stick orbits the camera.
- `PrintString` is stripped in shipping builds. Debug output goes through the `W_TPCDebug` widget and the `Log(Msg)` function instead.
- The spring-arm collision test collapsed the arm into the hero, since the probe starts inside the pawn. It's off for now; wall handling needs a custom trace that ignores the pawn.
- **The stick roll was not blocked by either attempt:** (1) key-axis events on Gamepad_RightX/Y with Consume Input, and (2) removing the four `Roll*Gamepad` axis mappings via `InputSettings.RemoveAxisMapping` + rebuild. So the roll reads the stick outside the input-component stack (native polling or the game's own controls system). Next lead: the cvar in `BP_PlayerController.IsDodgeEnabled` (needs a raw export of the `.uexp`).
- **The stick-roll switch was found in a raw export of BP_PlayerController:** the native `bool RightStickDodgingEnabled` and `RightStickHasReset` on `/Script/Dungeons.BasePlayerController`. They're Blueprint-writable, since BP_PlayerController sets them while the quick-chat wheel is open, so that the right stick picks a chat entry instead of dodging. The cvar `Dungeons.Experimental.EnableDodge` gates the Dodge *action* in `IsDodgeEnabled` and isn't what we want.
  - Plan A (no compiling): `ExecuteConsoleCommand("set BasePlayerController RightStickDodgingEnabled False/True")`. This only works if `set` is allowed in this shipping build.
  - Plan B: a C++ stub `ABasePlayerController : APlayerController` in the Mod Kit's `Dungeons` module, with those two `UPROPERTY(BlueprintReadWrite)` bools. Then `Cast To BasePlayerController` → set the property directly. The stub must not be packaged. This needs VS 2017 Build Tools.
  - **Plan A failed:** the hero still rolls. Either `set` is blocked in shipping, or the game's BP rewrites the flag (bytecode at uexp offset 12637 assigns it near a `Not(IsVisible)`, possibly every frame). Going with Plan B, and setting the flag **every tick** while active, from our actor ticking in PostUpdateWork. The stub is at `Dungeons-Mod-Kit/UE4Project/Source/Dungeons/BasePlayerController.h`.
  - **Plan B works (confirmed in camp, 2026-10-18).** `SetStickRoll(Enabled)` casts PC → `BasePlayerController` and sets `RightStickDodgingEnabled = Enabled`, and the Tick sets it to false every frame while active. The stick no longer rolls with the mod on, and it rolls again with the mod off. The roll button is unaffected.
  - Build notes: the C++ stub compiles with VS 2019 Build Tools (`Engine\Build\BatchFiles\Build.bat DungeonsEditor Win64 Development -Project=...`). The Mod Kit shipped a stale hot-reload `UE4Editor-Dungeons-8663.dll` that the editor loaded instead of the fresh build; it was moved to `Binaries\stale_backup`.
  - The `RollMappings` remove/add loop was removed (2026-10-18). With it, quitting the game while the camera was on crashed ("Unhandled exception" on exit). The likely cause: EndPlay → `AddAxisMapping(ForceRebuildKeymaps)` during world teardown. Don't touch InputSettings from EndPlay.
- The pitch direction felt inverted, so it changed to `Pitch - StickY * ...`.

## Mod layout
```
/Game/BPLoader/Ingame/TPC_Ingame.umap   (empty level containing BP_ThirdPersonCam)
/Game/BPLoader/Lobby/TPC_Lobby.umap     (same, for camp)
/Game/Mods/ThirdPersonCam/BP_ThirdPersonCam.uasset
/Game/Mods/ThirdPersonCam/SG_TPCSettings.uasset  (SaveGame: enabled flag, sensitivity, distance)
```
Output: `ThirdPersonCam.pak`, packed with `pack_compressed.bat` and renamed.

## Runtime logic (BP_ThirdPersonCam)
**Components:** `SceneRoot` → `SpringArm` (`bDoCollisionTest=true`, `ProbeChannel=Camera`, arm length about 450, socket offset (0, 60, 80) for an over-the-shoulder view, lag enabled) → `Camera` (FOV 80).

**BeginPlay**
- `PC = GetPlayerController(0)`. Cache `OriginalViewTarget = PC.GetViewTarget()`.
- Load the SaveGame slot (it holds the enabled state across levels). Initialize `Yaw` from the pawn's yaw and set `Pitch = -15`.
- `EnableInput(PC)` and set `InputPriority` high with `bBlockInput=false`, so the actor sees input before the pawn and controller.
- If enabled, call `Activate()`.

**Input**
- *F6 key event*: flip `bEnabled`, call `Activate()` or `Deactivate()`, and save.
- *Right stick*: bind axis events with the **same axis names the game uses for roll direction** (from discovery), with `Consume Input` on. This one step both reads the stick and stops the game from seeing it, which disables roll. When deactivated, we `DisableInput`, so the game gets the stick back. This avoids editing `DefaultInput.ini`, which can't be toggled at runtime.
- *Left stick*: consume the game's move axes the same way and re-apply them as `Pawn.AddMovementInput` with camera-relative vectors (forward and right from `Yaw` only). If discovery shows the game's movement already follows the camera, skip this.
- *R3* (`RightStickClick` action): snap `Yaw` behind the pawn.
- The existing roll button is untouched.

**Tick (while active)**
- `Yaw += RX * Sens * dt` and `Pitch = clamp(Pitch + RY * Sens * dt, -60, 20)`.
- Set the actor's location to `Pawn.GetActorLocation() + (0, 0, 60)` and the spring arm's world rotation to `(Pitch, Yaw, 0)`.
- If `PC.GetViewTarget()` is neither self nor the pawn/original target, a cutscene took over. Pause until the view target returns, then reclaim it.
- If the pawn is invalid (death or respawn), re-acquire it with `GetPlayerPawn(0)`.

**Activate / Deactivate**: `PC.SetViewTargetWithBlend(self or OriginalViewTarget, 0.3)`, then enable or disable the axis consumption.

## Milestones
1. ✅ **MVP:** loader level spawns the actor, F6 toggles the view target, right stick orbits.
2. ✅ Disable the stick roll while active (via `RightStickDodgingEnabled`). ✅ Camera-relative movement needs no work: the game already steers relative to the active view, so the left stick follows our camera. Also verified on Squid Coast: the mission level loads, F6 works, cutscenes and death recover, and the roll comes back after leaving with the mod on.
3. Settings + persistence (SaveGame `SG_TPCSettings`, slot `ThirdPersonCam`): `Enabled` (camera state, remembered across levels and restarts), `Distance` (TargetArmLength, default 450), `FOV` (80), `LookSpeed` (sensitivity, 150), `InvertY`.
   - An editable config file isn't possible: the mod is Blueprint-only at runtime (our C++ stub is editor-only and never shipped), and stock Blueprints can't read arbitrary files. Steam launch options (`-TPCDistance=…` via `ParseCommandLine`) would work but are clunky.
   - Plan: an in-game settings panel (UMG) toggled with **F7**. Up/Down selects a row and Left/Right changes the value. Changes apply live and are saved to the SaveGame.
   (Camp support, cutscene handoff and death/respawn were already verified working.)
   - ✅ Built (2026-10-18). SaveGame load/create in BeginPlay → `ApplySettings` → creates `W_TPCMenu` → auto-`TurnOn` after 0.5 s if Enabled. F6 saves Enabled. The F7 panel (`RefreshMenu` builds the text with Format Text; `AdjustSettings(Dir)` handles Left/Right) clamps Distance 150–1000 / step 25, FOV 60–120 / step 5, Sensitivity 30–400 / step 10. Invert Y flips the pitch sign in the Tick.
   - Debug output is gated by the `ShowDebug` bool in `Log` (off for release).
4. ✅ Wall collision (2026-10-18): each tick, `SphereTraceForObjects` (radius 12, WorldStatic+WorldDynamic) runs from the pivot to `pivot − Forward(Pitch,Yaw) × Distance`. Hit → arm length = max(hit distance, 40); else Settings.Distance. Ignore list `TraceIgnore` = pawn + any actor the trace starts inside (`Initial Overlap`). The camp has a level-wide brush volume (`AV10_Lobby_S3.BrushComponent0`) that otherwise collapsed the arm to 0. Fine-tuning (smoothing the snap-in, socket offset vs walls) is deferred.
5. R3 recenter (2026-10-18): custom event `Recenter` sets Yaw = pawn yaw and Pitch = -20. It's called by the R3 key event (`Gamepad Right Thumbstick Button`, only while Active) and by the ON path (replacing the old "Yaw from game camera"), so F6 and the auto turn-on also start behind the hero. ShowDebug is off again.
4. Polish: lag tuning, R3 recenter, a simple lock-on (nearest enemy within a radius on attack, never pets or players), distance and FOV values on D-pad.

## Known risks
- The game's own camera may live in a custom `PlayerCameraManager` that ignores `SetViewTarget`. Fallback: find the iso camera component on the pawn and drive it directly (re-parent it to our spring arm, or set its world transform each tick).
- If the hero's input goes through custom C++ rather than axis mappings, consuming by name won't block roll. Fallback: ship an overriding `DefaultInput.ini` that removes the right-stick roll binding, so roll stays off even when the camera is off.
- The levels are built for a top-down view, so expect see-through cliffs and culled geometry from low angles.
- Multiplayer: the mod affects only the local view.

## Verification
- Run `package.bat` with output to `~mods`, alongside the Blueprint Loader pak. Launch `Dungeons.exe`.
- In camp and in a mission (Squid Coast), check that:
  - the camera sits behind the hero, the right stick orbits, and the stick no longer rolls
  - the roll button still rolls, and the left stick moves relative to the camera
  - F6 switches back to iso and the right stick rolls again; F6 again returns to third person
  - the setting persists into the next mission
  - the camera doesn't clip through walls (spring arm), cutscenes show the normal camera, and death/respawn recovers.
- During development, print the view target and the actor's state with `PrintString` from the mod BP (UE4SS isn't available).
