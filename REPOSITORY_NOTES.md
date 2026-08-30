# Repository notes

This repository contains the source for the forthcoming initial public
**BLRevive Steam Play Fix 1.0.0** release.

## Important

- Do **not** commit Blacklight: Retribution executables, icons extracted from
  the game, locally compiled executables, or other proprietary game assets.
- `tools/icon/BLReviveLogoNew.png` is the project-owned source artwork for the
  launcher icon and is intentionally tracked with its developer-only generator.
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
- The launcher is not yet Authenticode-signed and a single-file setup is not yet
  implemented. The release builder supports signing when a trusted certificate,
  SignTool and RFC 3161 timestamp service are supplied. Those prerequisites and
  the single-file setup remain gates for the broad public release.
- The project is released under the permissive MIT License. Preserve the
  copyright and permission notice when redistributing substantial portions.

## Initial commit

Before committing, confirm that generated EXEs, untracked/generated ICOs, logs,
diagnostic reports, game files, and launcher backups are absent or ignored. The
packaged `resources/BLReviveSteamLauncher.ico` is the intentional exception.
Then create the initial commit and tag only after the 1.0.0 release candidate
has passed installation, Steam launch, diagnostic, uninstall, and Steam Verify
tests on Windows.
