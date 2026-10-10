#!/usr/bin/env bash
# hypr-wallcolors uninstaller
# Refuses to run accidentally: pass `--yes`, or confirm interactively.
set -euo pipefail

case "${1:-}" in
    --yes|-y)
        ;;
    --help|-h)
        echo "usage: $0 [--yes]" >&2
        echo "Removes scripts, theme engine, systemd units and config blocks." >&2
        exit 0
        ;;
    "")
        read -rp "Remove hypr-wallcolors entirely? Type 'uninstall' to continue: " ans
        if [ "$ans" != "uninstall" ]; then echo "aborted."; exit 1; fi
        ;;
    *)
        echo "unknown argument: $1 (use --yes or run interactively)" >&2
        exit 2
        ;;
esac

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now hypr-wallcolors.path 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
fi

rm -f "$HOME/.local/bin/hypr-wallcolors" \
      "$HOME/.local/bin/hypr-theme" \
      "$HOME/.local/bin/hypr-set-wallpaper" \
      "$HOME/.local/bin/wallpaper-picker" \
      "$HOME/.local/bin/wallpaper-picker-gtk" \
      "$CONF_DIR/border-colors.lua" \
      "$CONF_DIR/border-colors.conf" \
      "$UNIT_DIR/hypr-wallcolors.service" \
      "$UNIT_DIR/hypr-wallcolors.path"
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/theme"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/wallpicker"
say "removed scripts, generated colors, theme engine and systemd units"

# strip the blocks the installer appended
for f in "$CONF_DIR/hyprland.lua" "$CONF_DIR/hyprland.conf"; do
    [ -f "$f" ] || continue
    if grep -q "hypr-wallcolors" "$f"; then
        sed -i '/>>> hypr-wallcolors >>>/,/<<< hypr-wallcolors <<</d' "$f"
        say "cleaned $f"
    fi
done

say "done. (restore your original col.active_border / reload Hyprland)"
