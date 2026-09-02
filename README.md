# BLRevive Steam Play Fix

One simple setup for playing Blacklight: Retribution with BLRevive, whether the game came from Steam or the community archive.

[Download the latest player release](https://github.com/Vyrium/BLRevive-Steam-Play-Fix/releases)

> [!IMPORTANT]
> Download the ZIP attached to a GitHub **Release**. Do not use GitHub's automatically generated **Source code** ZIP.

## For players

### Install

1. Install Blacklight from Steam if you own it, or follow BLRevive's [Download BL:R guide](https://blrevive.gitlab.io/wiki/guides/user/getting-started/#download-blr) and extract the archive.
2. [Download the latest tool release ZIP](https://github.com/Vyrium/BLRevive-Steam-Play-Fix/releases) and extract it anywhere.
3. Double-click **Install BLRevive Steam Play Fix.bat** and select your Blacklight folder if asked.
4. If Windows asks for administrator permission, approve it so missing game prerequisites can be installed.
5. Start the game:
   - **Steam owner:** use Blacklight: Retribution's normal **PLAY** button.
   - **Archive player:** start Steam, then double-click the new **Play BLRevive** desktop shortcut.

> [!NOTE]
> The installer finds a Steam copy automatically. For an archive copy, choose either the main *Blacklight: Retribution* folder or its `Binaries\Win32` folder in the folder picker. An internet connection is required the first time missing prerequisites are installed.

#### What the installer does

- Saves Steam's original BattlEye launcher as `FoxGame-win32-Shipping_BE.official-backup.exe`.
- Installs the BLRevive compatibility launcher under the filename Steam expects.
- Adds `BLReviveLauncher.ini`, which holds the BLRevive server endpoints.
- Checks and installs Blacklight's original Steam prerequisite chain from Microsoft and NVIDIA publisher downloads.
- Configures archive copies with Steam compatibility AppID `480` and creates a **Play BLRevive** desktop shortcut.
- Refreshes Windows Explorer so the launcher icon updates cleanly.

The real game executable, `FoxGame-win32-Shipping.exe`, is never modified. No custom Steam launch options are required. Licensed Steam installations keep AppID `209870`; archive installations use AppID `480`, matching BLRevive's ZCure guide.

#### Original game prerequisites

SteamDB records these shared redistributables for Blacklight AppID `209870`:

- Visual C++ 2010 SP1, 2012 Update 4, and 2013 redistributables
- DirectX End-User Runtimes (June 2010)
- .NET Framework 4 Client Profile
- NVIDIA PhysX System Software 9.12.1031

The setup installs only components that are missing or older than the required runtime version. On current Windows, the installed .NET Framework 4.x satisfies the old Client Profile dependency. Every downloaded installer must have a valid Microsoft or NVIDIA digital signature before it is allowed to run. Downloads are cached under `%LOCALAPPDATA%\BLReviveSteamPlayFix\Prerequisites` for repair or retry.

### Uninstall

1. Open the extracted player package.
2. Double-click **Uninstall.bat**.

For Steam owners, the original Steam launcher is restored automatically. For archive players, the wrapper, managed AppID file, and generated desktop shortcut are removed. System-wide prerequisites are left installed because other games may use them. The uninstaller leaves configuration and log files behind for troubleshooting; they are safe to delete manually.

### Need help?

Run **Diagnose.bat** from the extracted player package and include the generated `BLReviveSteamPlayFix-Diagnostic.txt` when asking for support.

If Steam **Verify integrity of game files** has been run, it may restore Steam's original launcher. Just run **Install BLRevive Steam Play Fix.bat** again afterwards.

---

## For developers and curious players

### How it works

Steam normally launches the obsolete BattlEye bootstrap executable, `FoxGame-win32-Shipping_BE.exe`. This fix replaces that bootstrap—or supplies it for an archive copy—with a small compatibility launcher that:

1. Receives Steam's command line.
2. Removes duplicate or obsolete ZCure and Presence arguments.
3. Preserves unrelated Steam and player arguments.
4. Reads the BLRevive endpoints from `BLReviveLauncher.ini`.
5. Starts the real game executable with clean endpoint values.
6. Waits for the game process, so Steam stays in its Running state.
7. Writes a diagnostic log for troubleshooting.

The runtime launcher makes no network requests, injects nothing, changes no registry settings, and does not patch game files. The installer makes publisher-only network requests when prerequisites are missing. ZCure and Presence networking remains the game's job.

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

The release build compiles the launcher, stages only player-facing files, records the payload SHA-256, creates `dist\BLRevive-Steam-Play-Fix-1.1.0.zip`, writes `dist\SHA256SUMS.txt`, and runs a disposable install/diagnose/uninstall smoke test against that exact ZIP. `dist` build output is intentionally not committed.

### Repository layout

The player ZIP intentionally exposes only these runnable files at its root:

- `Install BLRevive Steam Play Fix.bat`
- `Uninstall.bat`
- `Diagnose.bat`

It also contains `payload` and `scripts`. The source repository keeps launcher code in `src`, packaged assets in `resources`, and developer-only build, icon, and release utilities in `tools`.

## License

BLRevive Steam Play Fix is open-source software released under the [MIT License](LICENSE).
