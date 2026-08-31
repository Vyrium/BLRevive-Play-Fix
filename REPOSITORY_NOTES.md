# Repository notes

This repository contains the source for the forthcoming initial public
**BLRevive Steam Play Fix 1.0.0** release.

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
- The 1.0.0 player installer validates and copies the prebuilt launcher from the
  generated release payload. It never compiles code on the player's computer.
  `tools/distribution/BuildRelease.ps1` creates and smoke-tests the player ZIP.
- The player release is intentionally a ZIP with the three root BAT entry
  points; no separate setup executable is required.
- The project is released under the permissive MIT License. Preserve the
  copyright and permission notice when redistributing substantial portions.
