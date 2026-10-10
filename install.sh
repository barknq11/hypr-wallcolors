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
command -v noctalia >/dev/null 2>&1 || missing="$missing noctalia"
command -v magick   >/dev/null 2>&1 || command -v convert >/dev/null 2>&1 || missing="$missing imagemagick"
# the grid wallpaper picker needs GTK4 + Python bindings
if ! python3 -c "import gi; gi.require_version('Gtk','4.0')" 2>/dev/null; then
    missing="$missing python-gobject(gtk4)"
fi
if [ -n "$missing" ]; then
    warn "missing commands:$missing"
    if command -v pacman >/dev/null 2>&1; then
        warn "install with: sudo pacman -S noctalia imagemagick python python-gobject gtk4"
        warn "optional (OSD popups): sudo pacman -S swayosd"
    elif command -v apt    >/dev/null 2>&1; then warn "install with: sudo apt install imagemagick python3 gir1.2-gtk-4.0"
    elif command -v dnf    >/dev/null 2>&1; then warn "install with: sudo dnf install ImageMagick python3"
    fi
fi

# --- install executables -----------------------------------------------------
mkdir -p "$BIN_DIR"
install -m755 "$SRC/hypr-wallcolors"     "$BIN_DIR/hypr-wallcolors"
install -m755 "$SRC/hypr-theme"          "$BIN_DIR/hypr-theme"
install -m755 "$SRC/hypr-set-wallpaper"  "$BIN_DIR/hypr-set-wallpaper"
install -m755 "$SRC/wallpaper-picker"    "$BIN_DIR/wallpaper-picker"
install -m755 "$SRC/wallpaper-picker-gtk" "$BIN_DIR/wallpaper-picker-gtk"
say "installed scripts to $BIN_DIR"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR is not in your PATH -- add it to your shell profile" ;;
esac

# --- Noctalia theme engine config -------------------------------------------
NOCTALIA_THEME_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/theme"
rm -rf "$NOCTALIA_THEME_DIR.bak"
if [ -d "$NOCTALIA_THEME_DIR" ]; then cp -a "$NOCTALIA_THEME_DIR" "$NOCTALIA_THEME_DIR.bak"; fi
mkdir -p "$NOCTALIA_THEME_DIR"
install -m644 "$SRC/theme/noctalia/config.toml" "$NOCTALIA_THEME_DIR/config.toml"
install -m644 "$SRC/theme/noctalia/fuzzel.tpl"  "$NOCTALIA_THEME_DIR/fuzzel.tpl"
say "installed Noctalia theme engine to $NOCTALIA_THEME_DIR"

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
    # migrate any bare `hypr-wallcolors` login hook to the full theme
    if grep -q 'hl.exec_cmd("hypr-wallcolors")' "$CONF_DIR/hyprland.lua"; then
        sed -i 's|hl.exec_cmd("hypr-wallcolors")|hl.exec_cmd("bash -c '"'"'$HOME/.local/bin/hypr-theme'"'"'")|' \
            "$CONF_DIR/hyprland.lua"
        say "upgraded login hook to full theme (hypr-theme)"
    fi

    if ! grep -q "hypr-wallcolors" "$CONF_DIR/hyprland.lua"; then
        cat >> "$CONF_DIR/hyprland.lua" <<'EOF'

-- >>> hypr-wallcolors >>>
-- Wallpaper-driven theming (see ~/.local/bin/hypr-wallcolors).
-- Border colors generated from the current wallpaper.
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/border-colors.lua")

-- Apply the full theme (borders, kitty, fuzzel, cava, btop) on login.
hl.on("hyprland.start", function()
    hl.exec_cmd("bash -c '$HOME/.local/bin/hypr-theme'")
end)
-- <<< hypr-wallcolors <<<
EOF
        say "patched $CONF_DIR/hyprland.lua"
    else
        say "hyprland.lua already integrated"
    fi

    # add the SUPER+W wallpaper-picker bind unless a W bind already exists
    if grep -Eq '\+ *W(\b|")' "$CONF_DIR/hyprland.lua"; then
        say "found an existing W keybind -- leaving it alone"
    elif grep -q 'wallpaper-picker' "$CONF_DIR/hyprland.lua"; then
        say "wallpaper-picker bind already present"
    else
        cat >> "$CONF_DIR/hyprland.lua" <<'EOF'

-- >>> hypr-wallcolors: wallpaper picker >>>
hl.bind("SUPER + W", hl.dsp.exec_cmd("bash -c '$HOME/.local/bin/wallpaper-picker'"))
-- <<< hypr-wallcolors: wallpaper picker <<<
EOF
        say "bound SUPER+W to the wallpaper picker"
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
    "$BIN_DIR/hypr-theme" && say "applied wallpaper colors: borders, kitty, fuzzel, cava, btop"
else
    warn "Hyprland is not running; colors will apply on next start"
fi

say "done."
