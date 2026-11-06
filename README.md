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
- **Control center:** sound, internet, Bluetooth, performance, calendar, notifications, monitor, settings, about and power.
- **Music card:** cover art, colors taken from the album, seek bar, repeat, shuffle, likes, volume and output switching.
- **Notifications and volume:** glass cards that drop from under the island.
- **Overview:** a strip of workspaces above the current one's windows, with live previews. Drag a window to another workspace. `Super+O`.
- **Search:** apps, system screens, commands, emoji (searched in your language) and screenshots, with tabs and your recent apps on top. Type "wifi" or "volume".
- **Clipboard history:** search, filter by text, links or images, preview images, pin what you reuse and delete the rest. From the island icon or `Super+Shift+V`.
- **Languages:** English, Português (Brasil), Español, Français, Deutsch, Русский and 简体中文. It follows your system language, or pick one in Settings.
- **Lock screen:** a large clock, the current song and your profile's name and picture over your sharp wallpaper. It also greets you when waking from suspend, with no flash of the desktop.
- **Profiles:** each one keeps its own name, picture and wallpaper (from galleries you add to and remove from, with a wallpaper per screen if you like, which the lock screen follows too), language, accent, dock and idle times. Create and switch them in Settings.
- **Public holidays:** for over 200 countries in the calendar, or none. Choose in Settings.
- **Monitors:** drag your screens into place, and set resolution, refresh rate, scale, rotation, mirroring, VRR, brightness, workspaces and what closing the lid does. A new layout goes back by itself in 15 seconds unless you keep it.
- **Idle and power:** lock, screen off and suspend times per power source, each with a Never option, power modes, and a night light with its own schedule.
- **Keyboard and mouse:** layouts, pointer speed, natural scrolling and touchpad options in Settings.
- **Internet:** Wi-Fi with hidden and enterprise (802.1X: PEAP, TTLS and certificate-based TLS) networks, plus WireGuard and OpenVPN files you import.
- **Shortcuts:** a keyboard map of every shortcut, colored by group. Press a new combination to change one, see conflicts and free keys, and add your own for apps or commands.
- **Default apps:** browser, terminal, files, text, images, video, music and email, for Atoll's shortcuts and for the files and links you open.
- **Window rules:** per app, open floating, centered, at a size, maximized, pinned, see-through or on a given workspace, without writing Lua.
- **Backup:** export a profile or everything to one file, with or without images, and review line by line before importing it here or on another computer.
- **Light theme:** dark, light, or automatic with the night light schedule.
- **About:** version, one-click update, project links, and your computer's details (model, processor, graphics, memory, storage, battery health, screens and software) to read or paste in a bug report.
- **Resilient by design:** if the shell crashes, it restarts by itself. Your windows stay open.

## Screenshots

Screenshots use demo data.

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

![Workspace overview](docs/screenshots/overview.webp)

| Search | Clipboard history |
|---|---|
| ![Search](docs/screenshots/launcher.webp) | ![Clipboard history](docs/screenshots/clipboard.webp) |

| Monitor | About |
|---|---|
| ![Monitor](docs/screenshots/monitor.webp) | ![About](docs/screenshots/about.webp) |

| Shortcuts | Light theme |
|---|---|
| ![Shortcuts](docs/screenshots/shortcuts.webp) | ![Light theme](docs/screenshots/light.webp) |

| Settings | Power |
|---|---|
| ![Settings](docs/screenshots/ajustes.webp) | ![Power](docs/screenshots/energia.webp) |

![Notifications and volume](docs/screenshots/notify.webp)

## Requirements

- **Hyprland with Lua configuration.** Developed on 0.56.2. Older versions without `hl.*` will not work.
- **Quickshell** 0.3 or newer.
- NetworkManager, BlueZ and PipeWire with WirePlumber for the matching screens.
- Noto fonts (`noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji`) to display Russian, Chinese and emoji.
- Optional: `power-profiles-daemon` for power modes, `networkmanager-openvpn` for OpenVPN files.

Atoll is developed and tested on one machine: Arch Linux with an Intel GPU. Other distributions and
GPUs may work, and reports are welcome.

## Install

On Arch Linux:

```sh
git clone https://github.com/brayanspagnol/atoll.git
cd atoll
./install.sh --deps
```

Or as a package, built from `packaging/aur`, then run the setup as your own user:

```sh
cd packaging/aur && makepkg -si
atoll-setup
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
| `Super+Alt+M` / `O` | Monitor / About |
| `Super+Alt+T` | Personalization |
| `Super+Alt+K` / `N` / `R` / `U` | Shortcuts / Default apps / Window rules / Backup |
| `Super+Shift+V` / `Super+.` | Clipboard history / Emoji |
| `Super+O` | Workspace overview |
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

The full list is in [`hypr/keys.lua`](hypr/keys.lua), and you can change any of them in the Shortcuts screen (`Super+Alt+K`).

## Configure

**Most things** are in two screens: Personalization (profile, theme, accent color and wallpaper) and Settings (language, night light, keyboard and mouse, holidays and idle timers). Screens are in the Monitor screen, saved in `~/.config/atoll/monitors.lua`.
Atoll ships no wallpapers and starts on a solid color. Add yours with the **+** in Settings: they stay in the gallery, and the lock screen follows the one you pick. Your lock screen picture is set per profile, and falls back to `~/.face`.

**The lock screen** is `~/.config/atoll/hyprlock.conf`. Updates replace it and save your version as `hyprlock.conf.bak`.

**Hyprland** overrides go in `~/.config/atoll/user.lua`, which updates never touch. Give your binds a `description`: the Shortcuts screen shows it. For example, a keyboard
layout and another terminal:

```lua
hl.config({ input = { kb_layout = "br,us", kb_variant = "abnt2," } })
hl.unbind("SUPER + Return") -- without this, both commands would run
hl.bind("SUPER + Return", hl.dsp.exec_cmd("foot"), { description = "Terminal (foot)" })
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
git pull && ./install.sh   # update; settings, events and likes stay. About can also do this in one click
./uninstall.sh             # remove; add --purge to delete your data too
```

## Known limits

- **Shuffle and repeat depend on the player.** Browsers don't expose them over MPRIS. Atoll emulates
  repeat-one by seeking back 1.5 seconds before the end, and shuffle stays off for them.
- **Likes are local.** They don't reach Spotify or YouTube Music, because MPRIS has no such concept.
- **Calendar events are local.** There is no Google Calendar or CalDAV sync.
- **Holidays are nationwide only,** with names in English or in the country's language, and they need a connection the first time.
- **Events and likes are shared** by all profiles.
- **Notification buttons** only work while the notification is live. After a shell restart, a card from history offers to open its app instead.
- **Bluetooth pairing** works for devices that need no code. For keyboards that show one, use `bluetoothctl`.
- **Blur** uses the GPU. If it feels slow, disable it in `user.lua`:
  `hl.config({ decoration = { blur = { enabled = false } } })`.

## Privacy

Atoll needs no account and sends no telemetry. Notification history, which can include message text, stays on your computer in `~/.local/state/atoll`, readable only by you; Clear all erases it. Pinned clipboard items are kept there too. Two features use the network. The update check in About asks GitHub for the latest release, only when you click it. And when you open the calendar or Settings, it
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
