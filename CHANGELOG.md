# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.17.0] - 2026-11-06

### Added

- Weather: the current temperature in the island, and a card with the next hours and 7 days from Open-Meteo. A new Weather screen (`Super+Alt+W`) picks the city by search or, if you turn it on, by IP, the unit (°C or °F) and whether the island shows it.
- Focus mode: a timer button in the island opens a card to start 25 or 50 minutes, an hour, or until you stop, with an optional Pomodoro cycle (25 minutes, then a 5 minute break). While it runs, the island shows the time left, and music and notification popups stay hidden except for the apps you let through; notifications still reach the history. At the end you can take a break or add 25 minutes. The launcher search can start or stop it.

## [1.16.3] - 2026-11-06

### Security

- Backup import refuses a `user.lua` or shortcuts file larger than the review shows, so no code can hide past the excerpt.
- Dock buttons that bring commands from a backup need an explicit yes, like code files.
- Liking a song copies only a regular cover file of at most 20 MB.
- Text fields show their placeholders as plain text, so a network name cannot style the password prompt.

### Fixed

- A broken file in the configuration, or an error in `user.lua`, no longer stops the session's services from starting; it shows a notification instead. The saved screen layout is checked before use.
- Notifications that leave the history are released, so memory no longer grows over a long session.
- The workspace overview keeps its previews when a window title changes, and a drag in progress survives refreshes.
- Wi-Fi rows keep a password being typed while networks reorder, and process rows keep their confirmation across readings.
- Profile requests wait their turn instead of overwriting each other.
- The night light, window border and lock screen wallpaper no longer flash at each shell restart.
- Clipboard image previews never reuse a half-written file, and the shell log stays bounded.

## [1.16.2] - 2026-11-06

### Fixed

- The clipboard panel is blurred like the other panels; it looked too transparent over windows.

### Changed

- New screenshots of every screen in the README.

## [1.16.1] - 2026-11-06

### Fixed

- The control center's search finds every button and option on every screen, read from the screens themselves, such as Extend in Monitor.

## [1.16.0] - 2026-11-06

### Changed

- The control center's screens are a single-column list that scrolls, with a search field on top. While you type it suggests screens and the settings inside them; picking a setting opens its screen, scrolls to it and marks it for a moment.

## [1.15.1] - 2026-11-06

### Changed

- Default apps: the apps for a role open in a short list right under it, and one click uses one. The system default is tagged, with less text overall.

## [1.15.0] - 2026-11-06

### Added

- Personalization card (`Super+Alt+T`) with the profile, theme, accent color and wallpaper, moved out of Settings.

### Changed

- Settings keeps language, night light, keyboard and mouse, holidays and idle times.
- Your own binds in `user.lua` can carry a `description`, which the Shortcuts screen shows.

## [1.14.1] - 2026-11-06

### Fixed

- Control center cards grow with their content, so the status line is no longer cut off.

### Removed

- The shortcut list in Settings, now that the Shortcuts screen shows them all.

## [1.14.0] - 2026-11-06

### Added

- Shortcuts screen: a keyboard map with every shortcut by group, recording a new combination with conflict warnings and free key suggestions, restoring defaults, and custom shortcuts for apps or commands. Defaults are data in `hypr/keys.lua`; changes are saved in `~/.config/atoll/shortcuts.lua`.
- Default apps screen: choose the browser, terminal, file manager, text editor, image viewer, video and music players and email client, for Atoll's shortcuts and the system defaults together, with a warning when they disagree.
- Window rules screen: per-app rules for floating, centering, size, maximized, fullscreen, pinned, opacity, focus on open and workspace, saved in `~/.config/atoll/rules.json` and applied live to new windows.
- Backup screen: export a profile or everything, with or without images, and import with a line-by-line review, as a new profile or replacing the current one, with an automatic copy first. Archives are checked before anything is read.
- Light theme, with dark, light and automatic modes. Automatic follows the night light schedule.
- Four control center cards for the new screens, with `Super+Alt+K`, `N`, `R` and `U`.

### Changed

- `Super+Enter`, `Super+B` and `Super+E` open the default apps.
- `xdg-utils` is a dependency.

## [1.13.0] - 2026-11-05

### Added

- About shows the computer's model and type, processor with cores and threads, storage with its use, battery health and charge cycles, screens, uptime and firmware, and includes them in the report.

## [1.12.1] - 2026-11-05

### Fixed

- The clipboard panel's buttons have filled backgrounds, so they stay visible over light wallpapers, and Copy spans the free width.

## [1.12.0] - 2026-11-05

### Added

- Clipboard history panel: search, filters for text, links, images and pinned items, image and color previews, pin, delete and clear. Pinned items are kept by Atoll and survive clearing the history.

### Changed

- Redesigned search: tabs for apps, screens, clipboard, emoji and screenshots, results grouped by kind with larger icons, recent apps on top, and an opening and closing animation.

## [1.11.0] - 2026-11-05

### Added

- A clipboard icon on the island opens the clipboard history.
- Certificate-based enterprise Wi-Fi (EAP-TLS), with client certificate, private key and an optional CA.
- Emoji search in the interface language, from Unicode CLDR annotations, ignoring accents.
- The lock screen follows the wallpaper chosen for each screen.
- Restored notifications offer to open their app.

### Changed

- The workspace overview lays out overlapping windows in rows of the same height.
- Shuffle shows as unavailable when the player does not support it.

### Fixed

- A profile missing a newer setting gets its default instead of the previous profile's value.
- Saving a network fails cleanly when NetworkManager rejects a value, such as an invalid CA certificate.

## [1.10.1] - 2026-11-05

### Changed

- The workspace overview animates: windows travel between their real place and the spread, also when closing.
- Overlapping windows, such as maximized ones, spread out in a grid in the overview.

### Fixed

- A laptop screen left off is turned back on when the external monitor goes away with the lid open.
- A closed lid with the external monitor asleep no longer moves the laptop panel back into the layout.
- Turning on a laptop screen that was off from the Monitor screen now works.
- Restored notifications can be dismissed, and replaced ones keep updating after a shell reload.
- The night light is applied at login when the schedule or switch has it on.
- Network requests wait their turn instead of taking over each other's results, and nmcli's own error is shown when saving a network fails.
- The Monitor tile shows the screen count right after the shell starts.
- Translation fixes across all languages.

## [1.10.0] - 2026-11-05

### Added

- Workspace overview, with `Super+O`: a strip of workspaces above the current one's windows, with live previews. Drag a window to another workspace.

## [1.9.0] - 2026-11-05

### Added

- Keyboard and mouse in Settings: layouts, pointer speed, natural scrolling and touchpad options.
- Clipboard history, emoji and screenshots in Search. `Super+Shift+V` and `Super+.` open them directly.
- Power modes in the Power screen, with `power-profiles-daemon`.
- A schedule for the night light.
- A wallpaper per screen.
- Remove images from the photo and wallpaper galleries.
- Drag icons to reorder the dock in its editor.
- Notifications are grouped by app, and their history survives a shell restart.
- Hidden and enterprise (802.1X) Wi-Fi networks.
- VPN section: import WireGuard and OpenVPN files, connect, disconnect and forget.
- One-click update in About.
- An AUR package definition in `packaging/aur`.

### Removed

- The wofi clipboard picker, replaced by Search.

## [1.8.0] - 2026-11-05

### Added

- Idle times are now picked from a list with a Never option.
- Wallpaper gallery: add images with the + button in Settings and they stay there. An image you already use joins it by itself.

### Changed

- Settings no longer lists every image in `~/Pictures/Wallpapers`.

### Removed

- The bundled default wallpaper and its generator. New installs start on a solid color.

## [1.7.1] - 2026-11-05

### Fixed

- A closed laptop panel no longer moves out of its parked position and back when the configuration reloads.

## [1.7.0] - 2026-11-05

### Added

- Monitor screen: drag screens into place, with presets, resolution, refresh rate, scale, rotation, mirroring, VRR, 10-bit color, brightness, workspaces per screen and a lid action. A new layout goes back by itself in 15 seconds unless kept.
- About screen: version, update check, project links, system details to copy for a report, and credits.

### Changed

- Screen and brightness settings moved from Settings to the Monitor screen.

## [1.6.1] - 2026-11-05

### Changed

- Larger icons on the dock.
- Switching screens in the control center now animates.

## [1.6.0] - 2026-11-05

### Changed

- Larger icons in the dock launchpad.
- Profile pictures now come from a gallery: the + button opens a file chooser, and every image you add stays available to all profiles. It no longer lists your pictures folders.
- `zenity` is now required, for the file chooser.

## [1.5.0] - 2026-11-05

### Changed

- New lock screen: a large clock at the bottom left over a sharp wallpaper, with the profile's name and picture beside the password field.
- Customizing the dock now happens in a full-screen launchpad with large icons, with the dock in edit mode at the bottom.

## [1.4.0] - 2026-11-05

### Added

- Profiles: create, switch and delete them in Settings. Each keeps its own name, picture, language, accent, wallpaper, dock and idle times.
- Each profile can have its own picture, which the lock screen shows.
- Public holidays for over 200 countries, chosen in Settings, from [date.nager.at](https://date.nager.at) and cached.

### Changed

- Settings moved from `settings.json` to `profiles/default.json`. `install.sh` migrates them.
- Blur no longer darkens translucent windows, which look clearer again.

### Removed

- Built-in Brazilian holiday calculation, replaced by the per-country list.

## [1.3.0] - 2026-11-05

### Added

- A gear on the dock opens a panel to choose, order and remove the apps it shows.
- The panel lists installed apps and also searches your files for executables, AppImages and `.desktop` files.
- Pinned apps show their own icon, or their first letter when they have none.

## [1.2.0] - 2026-11-05

### Added

- New lock screen with a large clock, the current song, battery, keyboard layout and your `~/.face` picture. It renders on the first frame after waking from suspend.
- The lock screen follows the wallpaper chosen in Settings.

### Changed

- Password prompt and error messages on the lock screen come from the system, in its language.
- `install.sh` updates the lock screen and saves a modified one as `hyprlock.conf.bak`.
- `install.sh --deps` also installs `playerctl`, used to show the current song.

### Removed

- GitHub Actions workflows and Dependabot. Checks run locally, as described in `CONTRIBUTING.md`.

## [1.1.0] - 2026-11-05

### Added

- Interface in English, Brazilian Portuguese, Spanish, French, German, Russian and Simplified Chinese, chosen in Settings or from the system language.
- Dates and the first day of the week follow the selected language.
- A setting for Brazilian holidays in the calendar. They now appear by default only on Brazilian locales.

### Changed

- English is the source language of the interface and of the helper scripts' messages.
- The installer keeps an existing `hyprlock.conf`, so a personalized lock screen survives updates.
- `install.sh --deps` also installs Noto fonts, needed for Russian and Chinese.

## [1.0.0] - 2026-11-05

### Added

- Floating island with workspaces, clock, media, tray and system status.
- Dock that hides at the screen edge, with pinned apps and running indicators.
- Control center with screens for sound, internet, Bluetooth, performance, calendar, notifications, settings and power.
- Now playing card with cover-tinted colors, seek bar, repeat, shuffle, local likes, volume and output switching.
- Notification cards and a volume indicator under the island.
- Search for apps and system screens.
- Calendar with month, week and year views, events, reminders and Brazilian national holidays.
- Lock screen, idle timers, night light and monitor brightness.
- Installer, uninstaller, automated tests and an original default wallpaper.

[Unreleased]: https://github.com/brayanspagnol/atoll/compare/v1.17.0...HEAD
[1.17.0]: https://github.com/brayanspagnol/atoll/compare/v1.16.3...v1.17.0
[1.16.3]: https://github.com/brayanspagnol/atoll/compare/v1.16.2...v1.16.3
[1.16.2]: https://github.com/brayanspagnol/atoll/compare/v1.16.1...v1.16.2
[1.16.1]: https://github.com/brayanspagnol/atoll/compare/v1.16.0...v1.16.1
[1.16.0]: https://github.com/brayanspagnol/atoll/compare/v1.15.1...v1.16.0
[1.15.1]: https://github.com/brayanspagnol/atoll/compare/v1.15.0...v1.15.1
[1.15.0]: https://github.com/brayanspagnol/atoll/compare/v1.14.1...v1.15.0
[1.14.1]: https://github.com/brayanspagnol/atoll/compare/v1.14.0...v1.14.1
[1.14.0]: https://github.com/brayanspagnol/atoll/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/brayanspagnol/atoll/compare/v1.12.1...v1.13.0
[1.12.1]: https://github.com/brayanspagnol/atoll/compare/v1.12.0...v1.12.1
[1.12.0]: https://github.com/brayanspagnol/atoll/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/brayanspagnol/atoll/compare/v1.10.1...v1.11.0
[1.10.1]: https://github.com/brayanspagnol/atoll/compare/v1.10.0...v1.10.1
[1.10.0]: https://github.com/brayanspagnol/atoll/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/brayanspagnol/atoll/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/brayanspagnol/atoll/compare/v1.7.1...v1.8.0
[1.7.1]: https://github.com/brayanspagnol/atoll/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/brayanspagnol/atoll/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/brayanspagnol/atoll/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/brayanspagnol/atoll/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/brayanspagnol/atoll/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/brayanspagnol/atoll/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/brayanspagnol/atoll/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/brayanspagnol/atoll/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/brayanspagnol/atoll/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/brayanspagnol/atoll/releases/tag/v1.0.0
