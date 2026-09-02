# Repository notes

This repository contains the source for BLRevive Steam Play Fix. Version 1.1
expands the original Steam-owner flow to support archive installations.

## Important

- Do **not** commit Blacklight: Retribution executables, icons extracted from
  the game, locally compiled executables, or other proprietary game assets.
- `resources/BLReviveLogo.svg` is the project vector master for the
  launcher icon. `tools/icon/RenderSvgLogo.ps1` renders it to a temporary
  transparent PNG before the developer icon tool packages the ICO.
- `resources/BLReviveSteamLauncher.ico` is the intentionally tracked,
  multi-resolution release asset generated from that artwork. The developer
  build embeds it in the launcher before the player package is assembled.
- `README.md` and `CHANGELOG.md` are the only documentation sources. Install
  copies `README.md` into the support directory as the user-friendly README.txt.
- `Install BLRevive Steam Play Fix.bat`, `Uninstall.bat`, and `Diagnose.bat`
  are the only runnable files in the package root. Their PowerShell
  implementations live under `scripts/`; launcher source, packaged assets and
  developer tooling live under `src/`, `resources/` and `tools/`.
- `scripts/BLRevivePrerequisites.ps1` owns prerequisite detection, official
  publisher downloads, Authenticode validation, elevation and silent setup.
  Release smoke tests must use `-SkipPrerequisites`; never install system
  components on the developer machine as part of a package test.
- Archive mode is selected only when the chosen game directory does not match
  a Steam library containing `appmanifest_209870.acf`. It manages AppID `480`
  and creates `Play BLRevive.exe`, a desktop shortcut, and a preselected Steam
  Add Non-Steam Game flow while preserving any pre-existing AppID file. Do not
  write Steam's binary `shortcuts.vdf` directly.
- The 1.1.0 player installer validates and copies the prebuilt launcher from the
  generated release payload. It never compiles code on the player's computer.
  `tools/distribution/BuildRelease.ps1` creates and smoke-tests the player ZIP.
- The player release is intentionally a ZIP with the three root BAT entry
  points; no separate setup executable is required.
- The project is released under the permissive MIT License. Preserve the
  copyright and permission notice when redistributing substantial portions.
