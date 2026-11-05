# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/brayanspagnol/atoll/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/brayanspagnol/atoll/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/brayanspagnol/atoll/releases/tag/v1.0.0
