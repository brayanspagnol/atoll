#!/usr/bin/env bash
# Removes Atoll. Keeps settings, events and likes unless --purge is given.
set -euo pipefail

purge=0
case "${1:-}" in
    "") ;;
    --purge) purge=1 ;;
    *) echo "Usage: ./uninstall.sh [--purge]" >&2; exit 2 ;;
esac

rm -rf "$HOME/.config/quickshell/atoll" "$HOME/.config/atoll/hypr" "$HOME/.config/atoll/hyprlock.conf"
rm -rf "$HOME/.local/share/atoll/scripts" "$HOME/.local/share/atoll/wallpapers" "$HOME/.local/share/atoll/VERSION" "$HOME/.local/share/atoll/current-wallpaper" "$HOME/.local/share/atoll/current-face"
rm -f "$HOME/.local/bin/atoll-session"

if ((purge)); then
    rm -rf "$HOME/.config/atoll" "$HOME/.local/share/atoll" "$HOME/.local/state/atoll"
    echo "Atoll and its data were removed."
else
    echo "Atoll was removed. Your data is still in ~/.config/atoll and ~/.local/share/atoll (use --purge to delete it)."
fi

if [[ -f /usr/share/wayland-sessions/atoll.desktop ]]; then
    echo "To remove the session entry: sudo rm /usr/share/wayland-sessions/atoll.desktop"
fi
