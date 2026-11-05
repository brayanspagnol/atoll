# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/brayanspagnol/atoll/compare/v1.7.0...HEAD
[1.7.0]: https://github.com/brayanspagnol/atoll/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/brayanspagnol/atoll/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/brayanspagnol/atoll/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/brayanspagnol/atoll/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/brayanspagnol/atoll/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/brayanspagnol/atoll/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/brayanspagnol/atoll/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/brayanspagnol/atoll/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/brayanspagnol/atoll/releases/tag/v1.0.0
