BLRevive Steam Play Fix 1.0.0
=============================

PURPOSE
-------
Blacklight: Retribution's Steam PLAY action launches the obsolete BattlEye
bootstrap executable FoxGame-win32-Shipping_BE.exe. On some modern systems
that launcher can fail badly, while FoxGame-win32-Shipping.exe works normally.

Steam also supplies obsolete ZCure and Presence endpoint arguments. Adding new
values to Steam Launch Options can produce duplicates that the game may read in
the wrong order.

This fix replaces only the obsolete _BE bootstrap with a small compatibility
launcher. The wrapper:

  1. Receives the command line from Steam.
  2. Removes duplicate/obsolete ZCure and Presence arguments.
  3. Preserves unrelated Steam and user arguments.
  4. Reads the BLRevive endpoints from BLReviveLauncher.ini.
  5. Launches FoxGame-win32-Shipping.exe with the clean endpoint values.
  6. Waits for the game to exit so Steam remains in the Running state.
  7. Writes a diagnostic log for troubleshooting.

The real game executable is never patched or modified.


CURRENT DEFAULT ENDPOINTS
-------------------------
ZCure:
  blrrevive.ddd-game.de:80

Presence:
  blrrevive.ddd-game.de:9004

These values are external configuration and can be changed without rebuilding
the launcher.


INSTALL
-------
1. Download the player ZIP from the GitHub Releases page. Do not download the
   automatically generated Source code archive.

2. Extract the player ZIP anywhere.

3. Double-click:

     Install BLRevive Steam Play Fix.bat

4. The installer finds Blacklight through Steam. If multiple installations are
   found, choose the correct one. If Steam discovery fails, select either the
   main Blacklight: Retribution folder or its Binaries\Win32 folder using the
   Windows folder picker.

5. The current FoxGame-win32-Shipping_BE.exe is preserved as:

     FoxGame-win32-Shipping_BE.official-backup.exe

6. The compatibility wrapper is installed as:

     FoxGame-win32-Shipping_BE.exe

7. Windows Explorer is notified to refresh the wrapper icon.

8. Start Blacklight: Retribution using the normal Steam PLAY button.

No steam_appid.txt is required for the genuine Steam library PLAY path.


LAUNCHER ICON
-------------
The prebuilt launcher contains 16, 24, 32, 48, 64, 96, 128 and 256-pixel icon
frames. Players do not need to compile the launcher or run an icon conversion
tool. The source repository keeps the packaged ICO under resources.

tools\icon\BLReviveLogoNew.png is the authoritative project-owned source
artwork. The icon tool remains in that developer-only directory so the packaged
ICO can be regenerated when the artwork changes.

Windows Explorer caches icons by filename. Install and Uninstall request
documented item, folder and icon-cache refresh notifications so the fixed Steam
filename visually changes between the BLRevive and official launchers.


WHAT GETS INSTALLED
-------------------
In Blacklight's Binaries\Win32 directory:

  FoxGame-win32-Shipping.exe
      Existing real Blacklight executable. Not modified.

  FoxGame-win32-Shipping_BE.exe
      BLRevive Steam compatibility wrapper.

  FoxGame-win32-Shipping_BE.official-backup.exe
      Preserved Steam/BattlEye launcher when available.

  BLReviveLauncher.ini
      ZCure and Presence endpoint configuration.

  BLReviveSteamLauncher.log
      Created by the wrapper for diagnostics.

  BLReviveSteamPlayFix\
      Uninstall scripts, diagnostic scripts, a plain-text README and generated
      install metadata.

The validated prebuilt launcher remains under payload in the extracted player
package. Developer source, build tools and icon artwork are not included in the
player package or copied into the game.


CONFIGURATION
-------------
BLReviveLauncher.ini:

  [ZCure]
  Host=blrrevive.ddd-game.de
  Port=80

  [Presence]
  Host=blrrevive.ddd-game.de
  Port=9004

If BLRevive changes an endpoint, edit this INI. The launcher does not need to
be rebuilt.


DIAGNOSTICS
-----------
The wrapper writes:

  Binaries\Win32\BLReviveSteamLauncher.log

Each launch records the launcher version, paths, operating-system information,
configured endpoints, received/removed/forwarded arguments, game process ID,
game exit code and launcher errors. Common inline password/token-style values
are redacted. The log rotates after approximately 1 MB.

For a support report, run:

  Binaries\Win32\BLReviveSteamPlayFix\Diagnose.bat

It creates BLReviveSteamPlayFix-Diagnostic.txt with file/configuration status,
icon embedding and shell-refresh metadata, recent runtime logging and recent
uninstall status.


UNINSTALL
---------
For the easiest uninstall, double-click Uninstall.bat in the original extracted
package. It searches the registered Steam installation and every Steam library,
preferring the installation where the BLRevive fix is present.

The installed support copy is also available at:

  Binaries\Win32\BLReviveSteamPlayFix\Uninstall.bat

If automatic discovery fails, a Windows folder picker accepts either the main
Blacklight: Retribution folder or Binaries\Win32. Typed input is the final
fallback only.

Uninstall validates and restores:

  FoxGame-win32-Shipping_BE.official-backup.exe

as:

  FoxGame-win32-Shipping_BE.exe

It then asks Windows Explorer to refresh the restored official icon. If Steam
Verify already restored a non-BLRevive launcher, uninstall leaves it untouched.
If no usable backup exists, use Steam Verify Integrity to restore the official
file.

Configuration, runtime diagnostics and uninstall logs are intentionally left
behind and may be deleted manually.


STEAM VERIFY INTEGRITY
----------------------
Steam considers FoxGame-win32-Shipping_BE.exe an official depot file. Verify
Integrity may therefore restore the obsolete Steam launcher over this fix. Run
Install BLRevive Steam Play Fix.bat again afterward.


BUILD MANUALLY
--------------
The player release already contains a prebuilt launcher. Players do not need
this section. Developers working from the source repository can regenerate the
packaged icon from the repository root:

  tools\icon\BuildIconTool.bat

  tools\icon\BLReviveIconTool.exe ^
      --input "tools\icon\BLReviveLogoNew.png" ^
      --output "resources\BLReviveSteamLauncher.ico"

The developer build script embeds that icon and compiles the x86 GUI wrapper:

  tools\launcher\BuildLauncher.bat "resources\BLReviveSteamLauncher.ico"

The output is tools\launcher\BLReviveSteamLauncher.exe. Install copies it under
the filename Steam expects: FoxGame-win32-Shipping_BE.exe.


BUILD A PLAYER RELEASE
----------------------
From the source repository, run:

  powershell.exe -NoProfile -ExecutionPolicy Bypass ^
      -File "tools\distribution\BuildRelease.ps1"

This builds the launcher, stages only player-facing files, records the payload
SHA-256, creates dist\BLRevive-Steam-Play-Fix-1.0.0.zip, writes the archive hash
to dist\SHA256SUMS.txt, and runs a disposable install/diagnose/uninstall smoke
test against the exact ZIP. Build output under dist is intentionally not
committed.

For a public signed build, install SignTool and use the SHA-1 thumbprint of a
trusted code-signing certificate plus its certificate authority's RFC 3161
timestamp URL:

  powershell.exe -NoProfile -ExecutionPolicy Bypass ^
      -File "tools\distribution\BuildRelease.ps1" ^
      -CertificateThumbprint "YOUR_CERTIFICATE_THUMBPRINT" ^
      -TimestampUrl "YOUR_CA_RFC3161_TIMESTAMP_URL"

The release builder signs with SHA-256, verifies the signature before packaging,
and calculates the payload hash after signing. Without those parameters it
creates an explicitly warned unsigned preview build.


TROUBLESHOOTING
---------------
Problem: Install says the prebuilt player payload is missing
  Download the player ZIP from GitHub Releases rather than GitHub's automatic
  Source code archive, then extract the complete ZIP before running Install.

Problem: The wrapper has a generic icon
  Run Diagnose.bat and retain its report plus the full install output for
  support. The icon is embedded in payload\BLReviveSteamLauncher.exe, and Steam
  PLAY functionality is unaffected by Explorer's displayed icon.

Problem: Steam PLAY stopped working after Verify Integrity
  Run Install BLRevive Steam Play Fix.bat again; Steam probably restored the
  official _BE launcher.

Problem: The game does not reach BLRevive
  Check BLReviveLauncher.ini, then inspect BLReviveSteamLauncher.log to confirm
  which endpoint arguments were passed to the game.


SOURCE AND DISTRIBUTION NOTES
-----------------------------
The runtime launcher performs no network access, injection, registry changes or
game-file patching. ZCure and Presence networking remains the game's job.

The player installer validates and copies a prebuilt launcher; it does not run a
compiler. Source and repeatable build instructions remain public for auditing.
The prebuilt launcher and a future single-file setup should be consistently
Authenticode-signed before broad distribution.

The package root intentionally exposes only three runnable entry points:

  Install BLRevive Steam Play Fix.bat
  Uninstall.bat
  Diagnose.bat

The player ZIP contains `scripts` and `payload`. The source repository also
contains launcher source under `src`, packaged development assets under
`resources`, and developer-only build, icon and release utilities under `tools`.


LICENSE
-------
BLRevive Steam Play Fix is open-source software released under the MIT License.
See LICENSE for the full terms.
