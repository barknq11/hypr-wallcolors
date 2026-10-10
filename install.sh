#!/usr/bin/env bash
# hypr-wallcolors installer
# Sets up wallpaper-driven Hyprland border colors on a fresh machine.
# Safe to re-run / idempotent.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
PAPERLITE_SH="$HOME/.config/swaybg/current_wallpaper.sh"
STATE_FILE="$HOME/.cache/hypr-wallcolors/wallpaper"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# --- dependencies ------------------------------------------------------------
missing=""
command -v hyprctl  >/dev/null 2>&1 || missing="$missing hyprctl"
command -v python3  >/dev/null 2>&1 || missing="$missing python3"
command -v magick   >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 || missing="$missing imagemagick"
if [ -n "$missing" ]; then
    warn "missing commands:$missing"
    if   command -v pacman >/dev/null 2>&1; then warn "install with: sudo pacman -S imagemagick python"
    elif command -v apt    >/dev/null 2>&1; then warn "install with: sudo apt install imagemagick python3"
    elif command -v dnf    >/dev/null 2>&1; then warn "install with: sudo dnf install ImageMagick python3"
    fi
fi

# --- install executables -----------------------------------------------------
mkdir -p "$BIN_DIR"
install -m755 "$SRC/hypr-wallcolors"     "$BIN_DIR/hypr-wallcolors"
install -m755 "$SRC/hypr-set-wallpaper"  "$BIN_DIR/hypr-set-wallpaper"
say "installed scripts to $BIN_DIR"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR is not in your PATH -- add it to your shell profile" ;;
esac

# --- Hyprland config integration --------------------------------------------
mkdir -p "$CONF_DIR"
if [ -f "$CONF_DIR/hyprland.lua" ]; then
    MODE=lua
elif [ -f "$CONF_DIR/hyprland.conf" ]; then
    MODE=conf
else
    MODE=none
fi

if [ "$MODE" = lua ]; then
    if ! grep -q "hypr-wallcolors" "$CONF_DIR/hyprland.lua"; then
        cat >> "$CONF_DIR/hyprland.lua" <<'EOF'

-- >>> hypr-wallcolors >>>
-- Border colors generated from the current wallpaper (see ~/.local/bin/hypr-wallcolors).
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/border-colors.lua")
hl.on("hyprland.start", function() hl.exec_cmd("hypr-wallcolors") end)
-- <<< hypr-wallcolors <<<
EOF
        say "patched $CONF_DIR/hyprland.lua"
    else
        say "hyprland.lua already integrated"
    fi
elif [ "$MODE" = conf ]; then
    if ! grep -q "hypr-wallcolors" "$CONF_DIR/hyprland.conf"; then
        cat >> "$CONF_DIR/hyprland.conf" <<'EOF'

# >>> hypr-wallcolors >>>
# Border colors generated from the current wallpaper (see ~/.local/bin/hypr-wallcolors).
source = ~/.config/hypr/border-colors.conf
exec-once = hypr-wallcolors
# <<< hypr-wallcolors <<<
EOF
        say "patched $CONF_DIR/hyprland.conf"
    else
        say "hyprland.conf already integrated"
    fi
else
    warn "no hyprland.lua or hyprland.conf found in $CONF_DIR"
    warn "add this to your config manually:"
    if [ "$MODE" = none ]; then
        warn "    (lua) pcall(dofile, os.getenv(\"HOME\") .. \"/.config/hypr/border-colors.lua\")"
        warn "    (conf) source = ~/.config/hypr/border-colors.conf"
    fi
fi

# --- systemd user watcher ----------------------------------------------------
mkdir -p "$UNIT_DIR"
# Pick something to watch: PaperLite's script if present, else our state file.
if [ -f "$PAPERLITE_SH" ]; then
    WATCH="%h/.config/swaybg/current_wallpaper.sh"
    say "watching PaperLite wallpaper script"
else
    WATCH="%h/.cache/hypr-wallcolors/wallpaper"
    say "watching state file (use 'hypr-set-wallpaper' or run hypr-wallcolors)"
fi
sed "s|@@WATCH@@|$WATCH|" "$SRC/systemd/hypr-wallcolors.service" > "$UNIT_DIR/hypr-wallcolors.service"
sed "s|@@WATCH@@|$WATCH|" "$SRC/systemd/hypr-wallcolors.path"    > "$UNIT_DIR/hypr-wallcolors.path"

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now hypr-wallcolors.path 2>/dev/null || \
        warn "could not enable the watcher (is the user systemd instance running?)"
    say "enabled hypr-wallcolors.path"
fi

# --- first run ---------------------------------------------------------------
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    "$BIN_DIR/hypr-wallcolors" && say "applied border colors from the current wallpaper"
else
    warn "Hyprland is not running; colors will apply on next start"
fi

say "done."
