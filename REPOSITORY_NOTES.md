# Repository notes

This repository contains the source for the forthcoming initial public
**BLRevive Steam Play Fix 1.0.0** release.

## Important

- Do **not** commit Blacklight: Retribution executables, icons extracted from
  the game, locally compiled executables, or other proprietary game assets.
- `tools/icon/BLReviveLogoNew.png` is the project-owned source artwork for the
  launcher icon and is intentionally tracked with its developer-only generator.
- `resources/BLReviveSteamLauncher.ico` is the intentionally tracked,
  multi-resolution release asset generated from that artwork. The installer
  embeds it directly.
- `README.md` and `CHANGELOG.md` are the only documentation sources. Install
  copies `README.md` into the support directory as the user-friendly README.txt.
- `Install BLRevive Steam Play Fix.bat`, `Uninstall.bat`, and `Diagnose.bat`
  are the only runnable files in the package root. Their PowerShell
  implementations live under `scripts/`; launcher source, packaged assets and
  developer tooling live under `src/`, `resources/` and `tools/`.
- The 1.0.0 installer compiles the launcher locally and embeds the packaged ICO.
  The icon helper is a developer-only regeneration tool. A prebuilt,
  consistently code-signed installer/launcher is not implemented yet.
- The project is released under the permissive MIT License. Preserve the
  copyright and permission notice when redistributing substantial portions.

## Initial commit

Before committing, confirm that generated EXEs, untracked/generated ICOs, logs,
diagnostic reports, game files, and launcher backups are absent or ignored. The
packaged `resources/BLReviveSteamLauncher.ico` is the intentional exception.
Then create the initial commit and tag only after the 1.0.0 release candidate
has passed installation, Steam launch, diagnostic, uninstall, and Steam Verify
tests on Windows.
