<div align="center">
  <img src="docs/logo.svg" width="96" alt="Atoll logo">
  <h1>Atoll</h1>
  <p><strong>A complete glass desktop shell for Hyprland, with everything one click away.</strong></p>
  <p>
    <a href="https://github.com/brayanspagnol/atoll/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/brayanspagnol/atoll"></a>
    <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/github/license/brayanspagnol/atoll"></a>
  </p>
  <p><a href="README.pt-BR.md">Leia em português</a></p>
</div>

![Atoll control center](docs/screenshots/hero.webp)

Atoll replaces the usual pile of bar, launcher, notification daemon and settings apps with one
consistent interface, built with [Quickshell](https://quickshell.org). Every piece floats over your
wallpaper, and windows keep the rest of the screen.

## Features

- **Island:** workspaces, clock, media and status in a floating pill at the top.
- **Dock:** hides at the bottom edge, so windows get the full height. Hover the edge or press `Super+Z`. The gear opens a full-screen launchpad to choose its apps, from the installed list or any program in your files, and to reorder them.
- **Control center:** sound, internet, Bluetooth, performance, calendar, notifications, settings and power.
- **Music card:** cover art, colors taken from the album, seek bar, repeat, shuffle, likes, volume and output switching.
- **Notifications and volume:** glass cards that drop from under the island.
- **Search:** apps and system screens in one box. Type "wifi" or "volume".
- **Languages:** English, Português (Brasil), Español, Français, Deutsch, Русский and 简体中文. It follows your system language, or pick one in Settings.
- **Lock screen:** a large clock, the current song and your profile's name and picture over your sharp wallpaper. It also greets you when waking from suspend, with no flash of the desktop.
- **Profiles:** each one keeps its own name, picture (from a saved gallery you add to), language, accent, wallpaper, dock and idle times. Create and switch them in Settings.
- **Public holidays:** for over 200 countries in the calendar, or none. Choose in Settings.
- **Idle and display:** idle timers per power source, night light and monitor brightness.
- **Resilient by design:** if the shell crashes, it restarts by itself. Your windows stay open.

## Screenshots

Personal data such as network and device names is covered with solid blocks.

![Lock screen](docs/screenshots/lock.webp)

![Desktop with the dock visible](docs/screenshots/desktop.webp)

| Music | Sound and output | Likes |
|---|---|---|
| ![Now playing card](docs/screenshots/music.webp) | ![Volume and output switching](docs/screenshots/music-sound.webp) | ![Liked songs](docs/screenshots/music-likes.webp) |

| Calendar | Performance |
|---|---|
| ![Calendar](docs/screenshots/cal.webp) | ![Performance](docs/screenshots/perf.webp) |

| Internet | Bluetooth |
|---|---|
| ![Internet](docs/screenshots/rede.webp) | ![Bluetooth](docs/screenshots/bt.webp) |

![Choosing the apps on the dock](docs/screenshots/dock-editor.webp)

![Search](docs/screenshots/launcher.webp)

| Settings | Power |
|---|---|
| ![Settings](docs/screenshots/ajustes.webp) | ![Power](docs/screenshots/energia.webp) |

![Notifications and volume](docs/screenshots/notify.webp)

## Requirements

- **Hyprland with Lua configuration.** Developed on 0.56.2. Older versions without `hl.*` will not work.
- **Quickshell** 0.3 or newer.
- NetworkManager, BlueZ and PipeWire with WirePlumber for the matching screens.
- Noto fonts (`noto-fonts`, `noto-fonts-cjk`) to display Russian and Chinese.

Atoll is developed and tested on one machine: Arch Linux with an Intel GPU. Other distributions and
GPUs may work, and reports are welcome.

## Install

On Arch Linux:

```sh
git clone https://github.com/brayanspagnol/atoll.git
cd atoll
./install.sh --deps
```

On other distributions, install the packages listed in `install.sh` and run `./install.sh`.

Log out, and start the session from a TTY:

```sh
atoll-session
```

To pick Atoll in a display manager, run `./install.sh --session` as well. `--deps` and `--session` ask
for `sudo`; everything else stays in your home directory. See `./install.sh --help`.

> [!WARNING]
> Only one notification daemon can run at a time. If `mako`, `dunst` or `swaync` is installed, an app can
> start it before Atoll and your notifications will not appear in the shell. Uninstall them if that happens.

## Shortcuts

| Keys | Action |
|---|---|
| `Super+R` | Search apps and screens |
| `Super+Z` | Show the dock |
| `Super+N` | Control center |
| `Super+Alt+A` / `I` / `B` / `D` | Sound / Internet / Bluetooth / Performance |
| `Super+Alt+C` / `V` / `J` / `E` | Calendar / Notifications / Settings / Power |
| `Super+Enter` | Terminal |
| `Super+B` / `E` | Browser / Files |
| `Super+C` | Close window |
| `Super+L` | Lock |
| `Super+1…0` | Go to workspace |
| `Super+Shift+1…0` | Move window to workspace |
| `Super+Shift+V` | Clipboard history |
| `Super+Space` | Next keyboard layout |
| `Print` / `Shift+Print` | Screenshot of a region / the full screen |
| `Super+Shift+R` | Restart the shell |

The full list is in [`hypr/binds.lua`](hypr/binds.lua).

## Configure

**Most things** are in the Settings screen: language, accent color, wallpaper, brightness, night light and idle timers.
Your wallpapers go in `~/Pictures/Wallpapers`, and the lock screen follows the one you pick. Your lock screen picture is set per profile, and falls back to `~/.face`.

**The lock screen** is `~/.config/atoll/hyprlock.conf`. Updates replace it and save your version as `hyprlock.conf.bak`.

**Hyprland** overrides go in `~/.config/atoll/user.lua`, which updates never touch. For example, a keyboard
layout, a monitor and another terminal:

```lua
hl.config({ input = { kb_layout = "br,us", kb_variant = "abnt2," } })
hl.monitor({ output = "HDMI-A-1", mode = "3440x1440@60", position = "0x0", scale = 1 })
hl.unbind("SUPER + Return") -- without this, both commands would run
hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"))
```

**Shell** options are in `~/.config/atoll/profiles/<profile>.json`, one file per profile, applied as you save it:

| Key | Meaning |
|---|---|
| `dock` | Pinned apps, normally edited with the gear on the dock. Each has a `label`, `ids` (lowercase Wayland app ids), an icon (`icon`, a key from [`Icons.qml`](shell/Icons.qml), or `appIcon`, an icon theme name) and what to start (`desktopId` or `cmd`) |
| `language` | `auto`, or a language code such as `en`, `pt-BR`, `es`, `fr`, `de`, `ru` or `zh-CN` |
| `holidays` | A country code such as `BR` or `DE`, `off`, or `auto` for your system locale's country |
| `name`, `photo` | The profile's name and picture |
| `accent` | `gelo`, `areia`, `hortela` or `coral` |
| `wallpaper` | Image path, or empty for a solid color |

## Update and remove

```sh
git pull && ./install.sh   # update; settings, events and likes stay
./uninstall.sh             # remove; add --purge to delete your data too
```

## Known limits

- **Shuffle and repeat depend on the player.** Browsers don't expose them over MPRIS. Atoll emulates
  repeat-one by seeking back 1.5 seconds before the end, and shuffle stays off for them.
- **Likes are local.** They don't reach Spotify or YouTube Music, because MPRIS has no such concept.
- **Calendar events are local.** There is no Google Calendar or CalDAV sync.
- **Holidays are nationwide only,** with names in English or in the country's language, and they need a connection the first time.
- **Events and likes are shared** by all profiles.
- **Bluetooth pairing** works for devices that need no code. For keyboards that show one, use `bluetoothctl`.
- **Blur** uses the GPU. If it feels slow, disable it in `user.lua`:
  `hl.config({ decoration = { blur = { enabled = false } } })`.

## Privacy

Atoll needs no account and sends no telemetry. One feature uses the network: when you open the calendar or Settings, it
downloads public holidays from [date.nager.at](https://date.nager.at), which sees your IP address and the country and years
requested. Results stay cached in `~/.cache/atoll/holidays`. Set `holidays` to `off` to turn this off.

## Troubleshooting

- **The shell doesn't appear:** read `~/.local/state/atoll/shell.log`. Press `Super+Shift+R` to restart it.
- **No notifications:** see the warning under [Install](#install).
- **Missing icons:** check that `papirus-icon-theme` is installed.

## Contributing

Bug reports, translation fixes and pull requests are welcome: read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md). For security problems, see [SECURITY.md](SECURITY.md). Versions follow
[Semantic Versioning](https://semver.org), and changes are recorded in the [changelog](CHANGELOG.md).

## License

[MIT](LICENSE) © 2026 Brayan Spagnol. Third-party credits are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
