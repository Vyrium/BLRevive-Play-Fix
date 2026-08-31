# BLRevive Steam Play Fix

Make Blacklight: Retribution's normal Steam **PLAY** button work with BLRevive.

[Download the latest player release](https://github.com/Vyrium/BLRevive-Steam-Play-Fix/releases)

> [!IMPORTANT]
> Download the ZIP attached to a GitHub **Release**. Do not use GitHub's automatically generated **Source code** ZIP.

## For players

### Install

1. [Download the latest release ZIP](https://github.com/Vyrium/BLRevive-Steam-Play-Fix/releases) and extract it anywhere.
2. Double-click **Install BLRevive Steam Play Fix.bat**.
3. Start Blacklight: Retribution from Steam using the normal **PLAY** button.

> [!NOTE]
> The installer finds your Steam copy automatically. If it cannot, choose either the main *Blacklight: Retribution* folder or its `Binaries\Win32` folder in the folder picker.

#### What the installer does

- Saves Steam's original BattlEye launcher as `FoxGame-win32-Shipping_BE.official-backup.exe`.
- Installs the BLRevive compatibility launcher under the filename Steam expects.
- Adds `BLReviveLauncher.ini`, which holds the BLRevive server endpoints.
- Refreshes Windows Explorer so the launcher icon updates cleanly.

The real game executable, `FoxGame-win32-Shipping.exe`, is never modified. No Steam launch options or `steam_appid.txt` file are required.

### Uninstall

1. Open the extracted player package.
2. Double-click **Uninstall.bat**.

The original Steam launcher is restored automatically. If it cannot be found, the uninstaller opens the same folder picker. It leaves the configuration and log files behind for troubleshooting; they are safe to delete manually.

### Need help?

Run **Diagnose.bat** from the extracted player package and include the generated `BLReviveSteamPlayFix-Diagnostic.txt` when asking for support.

If Steam **Verify integrity of game files** has been run, it may restore Steam's original launcher. Just run **Install BLRevive Steam Play Fix.bat** again afterwards.

---

## For developers and curious players

### How it works

Steam launches the obsolete BattlEye bootstrap executable, `FoxGame-win32-Shipping_BE.exe`. This fix replaces only that bootstrap with a small compatibility launcher that:

1. Receives Steam's command line.
2. Removes duplicate or obsolete ZCure and Presence arguments.
3. Preserves unrelated Steam and player arguments.
4. Reads the BLRevive endpoints from `BLReviveLauncher.ini`.
5. Starts the real game executable with clean endpoint values.
6. Waits for the game process, so Steam stays in its Running state.
7. Writes a diagnostic log for troubleshooting.

The runtime launcher makes no network requests, injects nothing, changes no registry settings, and does not patch game files. ZCure and Presence networking remains the game's job.

### Default configuration

| Service | Host | Port |
| --- | --- | --- |
| ZCure | `blrrevive.ddd-game.de` | `80` |
| Presence | `blrrevive.ddd-game.de` | `9004` |

The values live in `BLReviveLauncher.ini`; change that file if BLRevive changes an endpoint. The launcher does not need rebuilding.

### Files in `Binaries\Win32`

| File or folder | Purpose |
| --- | --- |
| `FoxGame-win32-Shipping.exe` | The existing real Blacklight executable — not modified. |
| `FoxGame-win32-Shipping_BE.exe` | BLRevive Steam compatibility launcher. |
| `FoxGame-win32-Shipping_BE.official-backup.exe` | Preserved original Steam/BattlEye launcher, when available. |
| `BLReviveLauncher.ini` | ZCure and Presence endpoint configuration. |
| `BLReviveSteamLauncher.log` | Runtime diagnostic log, created after Steam launches the game. |
| `BLReviveSteamPlayFix\` | Installed uninstall, diagnostic, README, and metadata files. |

The launcher log records version, paths, operating-system details, configured endpoints, received/removed/forwarded arguments, process ID, exit code, and errors. Common password/token-style values are redacted and the log rotates at roughly 1 MB.

### Icon artwork

 `resources\BLReviveSteamLauncher.ico` is the generated multi-resolution icon embedded in the prebuilt launcher from `resources\BLReviveLogo.svg`. The player package already contains the finished launcher, so players never need icon tooling or a compiler.

Windows Explorer caches icons by filename. Both install and uninstall request Explorer refresh notifications so the fixed Steam filename updates between the BLRevive and official launchers.

### Build from source

Regenerate the icon from the SVG master:

```bat
tools\icon\BuildIconTool.bat
```

Build the x86 GUI launcher with that icon:

```bat
tools\launcher\BuildLauncher.bat "resources\BLReviveSteamLauncher.ico"
```

The output is `tools\launcher\BLReviveSteamLauncher.exe`. Installation copies it under Steam's required filename, `FoxGame-win32-Shipping_BE.exe`.

### Build a player release

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File "tools\distribution\BuildRelease.ps1"
```

The release build compiles the launcher, stages only player-facing files, records the payload SHA-256, creates `dist\BLRevive-Steam-Play-Fix-1.0.0.zip`, writes `dist\SHA256SUMS.txt`, and runs a disposable install/diagnose/uninstall smoke test against that exact ZIP. `dist` build output is intentionally not committed.

### Repository layout

The player ZIP intentionally exposes only these runnable files at its root:

- `Install BLRevive Steam Play Fix.bat`
- `Uninstall.bat`
- `Diagnose.bat`

It also contains `payload` and `scripts`. The source repository keeps launcher code in `src`, packaged assets in `resources`, and developer-only build, icon, and release utilities in `tools`.

## License

BLRevive Steam Play Fix is open-source software released under the [MIT License](LICENSE).
