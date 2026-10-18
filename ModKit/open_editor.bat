@echo off
rem Opens the mod kit project directly, skipping the Project Browser's
rem "Missing Compiler" check. The prebuilt Dungeons module matches UE 4.22.3,
rem so no Visual Studio is needed.
set /p EDITOR_DIR=<"%~dp0Tools\user_settings\editor_directory.txt"
start "" "%EDITOR_DIR%\UE4Editor.exe" "%~dp0UE4Project\Dungeons.uproject"
