BLRevive Steam Play Fix - Changelog
===================================

1.1.0
-----
- Added first-class support for community archive installations used by
  players who do not own Blacklight: Retribution on Steam.
- Detects and installs Blacklight's SteamDB-declared prerequisite chain:
  Visual C++ 2010/2012/2013, DirectX June 2010, .NET 4 compatibility, and
  NVIDIA PhysX 9.12.1031.
- Downloads redistributables only from Microsoft and NVIDIA endpoints and
  rejects installers without the expected valid publisher signature.
- Installs only missing or outdated components and caches publisher downloads
  for retries.
- Archive mode writes Steam compatibility AppID 480, preserves any previous
  AppID file, creates a clearly named Play BLRevive launcher and desktop
  shortcut, and opens Steam's Add Non-Steam Game flow with it selected.
- Uninstall restores/removes archive-specific integration without removing
  shared system prerequisites that other games may need.
- Diagnostics now report prerequisite readiness.

1.0.0
-----
- Initial public release candidate.
- Added the Steam Play compatibility wrapper for launching
  FoxGame-win32-Shipping.exe through Steam's expected _BE executable path.
- Removes obsolete/duplicate ZCure and Presence arguments, preserves unrelated
  arguments, and appends endpoints from BLReviveLauncher.ini.
- Keeps the wrapper alive until the game exits for Steam Running/playtime
  tracking and records diagnostic launch information with sensitive-value
  redaction.
- Added the packaged multi-resolution BLReviveSteamLauncher.ico, embedded
  directly by the installer.
- Added install metadata, diagnostics, and preservation of existing endpoint
  configuration.
- Uninstall restores a usable original launcher backup and leaves an existing
  non-BLRevive launcher untouched when Steam Verify has already restored it.
- Uninstall requests documented Windows shell item/icon refresh notifications
  after confirming that a non-BLRevive launcher is present. It does not clear
  global icon caches or restart Explorer.
- Install requests the same synchronous item, containing-folder and icon-cache
  refresh after replacing the fixed Steam launcher filename, preventing the
  restored red icon from remaining visible over the newly installed blue icon.
- Uninstall now discovers Blacklight through the registered Steam installation
  and all Steam libraries, preferring an installation containing the BLRevive
  fix. If discovery fails, it opens a folder picker before asking for typed input.
- Install now uses the same folder-picker fallback when Steam discovery fails,
  accepting either the Blacklight root folder or Binaries\Win32.
- Renamed the player-facing installer to Install BLRevive Steam Play Fix.bat
  and gave the PowerShell implementations distinct internal names, preventing
  confusion when Windows hides file extensions.
- Simplified the initial release layout: the root exposes only the three player
  entry-point BAT files; implementation scripts, launcher source, packaged
  resources and developer tooling live under scripts, src, resources and tools.
  Installed support contains only uninstall/diagnostic essentials, and duplicate
  text documentation and source-tree checksums were removed.
- Released the project source under the MIT License.
- Changed the player installer to validate and copy a prebuilt launcher instead
  of compiling C# on the player's computer. Validation covers SHA-256, product
  identity and version.
- Added repeatable release tooling that creates a player-only ZIP, publishes its
  SHA-256, excludes developer files and smoke-tests the exact archive through
  install, diagnostics and uninstall.
- Replaced the low-resolution launcher artwork with the project BLReviveLogo.svg
  vector master and regenerated the multi-resolution ICO.
