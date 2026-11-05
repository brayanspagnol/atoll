#!/usr/bin/env bash
# Installs Atoll for the current user. Only --deps and --session ask for sudo.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./install.sh [--deps] [--session] [--help]

  --deps     Install the required packages with pacman (Arch Linux, asks for sudo)
  --session  Add "Atoll" to the display manager session list (asks for sudo)
  --help     Show this message
EOF
}

want_deps=0
want_session=0
for arg in "$@"; do
    case "$arg" in
        --deps) want_deps=1 ;;
        --session) want_session=1 ;;
        --help | -h) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="$HOME/.config/atoll"
shell_dir="$HOME/.config/quickshell/atoll"
data="$HOME/.local/share/atoll"
bin="$HOME/.local/bin"

packages=(hyprland quickshell hyprlock hypridle hyprsunset xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    polkit-gnome networkmanager bluez bluez-utils pipewire wireplumber libnotify cliphist wl-clipboard
    grim slurp jq brightnessctl ttf-jetbrains-mono-nerd papirus-icon-theme qt6-svg curl noto-fonts noto-fonts-cjk noto-fonts-emoji playerctl zenity)
commands=(Hyprland start-hyprland qs hyprlock hypridle hyprsunset nmcli bluetoothctl wpctl notify-send cliphist
    wl-paste grim slurp jq brightnessctl zenity)

if ((want_deps)); then
    command -v pacman >/dev/null || { echo "--deps needs pacman. Install the packages listed in README.md by hand." >&2; exit 1; }
    sudo pacman -S --needed "${packages[@]}"
fi

missing=()
for cmd in "${commands[@]}"; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if ((${#missing[@]})); then
    echo "Missing commands: ${missing[*]}" >&2
    echo "Run ./install.sh --deps on Arch Linux, or install them with your package manager." >&2
    exit 1
fi

echo "Installing to $config, $shell_dir and $data"
mkdir -p "$config/hypr" "$shell_dir" "$data/scripts" "$bin"

# Settings moved into profiles in 1.4.0.
mkdir -p "$config/profiles"
if [[ -f "$config/settings.json" && ! -e "$config/profiles/default.json" ]]; then
    # "on" used to mean Brazil, the only country supported before 1.4.0.
    jq 'if .holidays == "on" then .holidays = "BR" else . end' "$config/settings.json" >"$config/profiles/default.json"
    rm "$config/settings.json"
fi

# Replace managed files only: profiles, user.lua and likes stay.
rm -rf "$shell_dir"/*.qml "$shell_dir"/*.js "$shell_dir/i18n"
cp -r "$repo"/shell/* "$shell_dir/"
cp "$repo"/hypr/*.lua "$config/hypr/"
cp "$repo"/scripts/* "$data/scripts/"
cp "$repo/VERSION" "$data/VERSION"
# A modified lock screen is kept aside, not lost.
if [[ -f "$config/hyprlock.conf" ]] && ! cmp -s "$repo/config/hyprlock.conf" "$config/hyprlock.conf"; then
    cp "$config/hyprlock.conf" "$config/hyprlock.conf.bak"
    echo "Your previous lock screen was saved as $config/hyprlock.conf.bak"
fi
cp "$repo/config/hyprlock.conf" "$config/hyprlock.conf"
# The idle page in Settings rewrites this file, so keep the existing one.
[[ -f "$config/hypridle.conf" ]] || cp "$repo/config/hypridle.conf" "$config/hypridle.conf"
ln -sf "$data/scripts/atoll-session" "$bin/atoll-session"

if ! fc-list | grep -qi "Instrument Sans"; then
    echo "Downloading the Instrument Sans font (SIL OFL)"
    mkdir -p "$HOME/.local/share/fonts"
    if curl -fsSL -o "$HOME/.local/share/fonts/InstrumentSans.ttf" \
        'https://github.com/google/fonts/raw/main/ofl/instrumentsans/InstrumentSans%5Bwdth,wght%5D.ttf'; then
        fc-cache -f "$HOME/.local/share/fonts"
    else
        echo "Could not download the font. The interface still works with a fallback font." >&2
    fi
fi

if ((want_session)); then
    entry="$(mktemp)"
    trap 'rm -f "$entry"' EXIT
    printf '[Desktop Entry]\nName=Atoll\nComment=Hyprland with the Atoll shell\nExec=%s\nType=Application\nDesktopNames=Hyprland\n' \
        "$data/scripts/atoll-session" >"$entry"
    sudo install -Dm644 "$entry" /usr/share/wayland-sessions/atoll.desktop
fi

# Files disappear for a moment above, which can make a running shell fail its automatic reload. This retries it.
touch "$shell_dir/shell.qml"

cat <<EOF

Atoll $(cat "$repo/VERSION") installed.

Start it from a TTY with:  atoll-session
Make sure $bin is in your PATH, or pick "Atoll" in your display manager after ./install.sh --session.
Personal Hyprland settings go in $config/user.lua.
EOF
