# hypr-wallcolors

Match your **Hyprland window-border color to your wallpaper**, and keep it in
sync automatically whenever the wallpaper changes.

Instead of theming the whole desktop, it does one thing well: it reads the
current wallpaper, pulls a small palette out of it, and paints the focused
window border with a 45° gradient of the two most vibrant colors, plus a muted
`inactive_border` derived from the same palette.

```
        focused window border  ->  gradient of wallpaper's dominant colors
        unfocused border       ->  dimmed, desaturated version
```

## Requirements

- Hyprland (classic `hyprland.conf` **or** the newer `hyprland.lua` parser)
- `python3`
- ImageMagick (`magick`)
- systemd user session (for the auto-update watcher)

Install them, e.g.:

| distro | command |
|--------|---------|
| Arch / CachyOS | `sudo pacman -S imagemagick python` |
| Debian / Ubuntu | `sudo apt install imagemagick python3` |
| Fedora | `sudo dnf install ImageMagick python3` |

## Install

```sh
git clone <this-repo> ~/hypr-wallcolors   # or just copy the folder over
cd ~/hypr-wallcolors
./install.sh
```

The installer:

1. copies `hypr-wallcolors` and `hypr-set-wallpaper` to `~/.local/bin`;
2. adds a small include to your `hyprland.lua` / `hyprland.conf` (idempotent,
   with markers so it can be cleanly removed);
3. installs and enables a systemd user **path unit** that re-runs the script
   whenever the wallpaper changes;
4. applies colors immediately.

### Wallpaper backends

The script auto-detects the current wallpaper from **PaperLite/swaybg**,
**swww**, or **hyprpaper**.

- **PaperLite / swaybg**: works out of the box — the watcher follows
  `~/.config/swaybg/current_wallpaper.sh`, which PaperLite rewrites on change.
- **swww / hyprpaper**: call `hypr-set-wallpaper /path/to/image` instead of your
  usual set command (bind it, so borders update with the wallpaper). It sets the
  wallpaper with whatever backend you have and recolors the borders.

You can always recolor manually:

```sh
hypr-wallcolors                 # use the current wallpaper
hypr-wallcolors /path/to/img    # use a specific image
```

## Uninstall

```sh
./uninstall.sh
```

Removes the scripts, generated colors, systemd units, and the marked config
blocks.

## Tuning

The look is controlled by constants at the top of `hypr-wallcolors`:

| knob | meaning |
|------|---------|
| `ANGLE` | gradient angle of the active border |
| `tune(..., s_mul=1.45, s_add=0.05, v_lo=0.62, v_hi=0.95)` | active-border vividness / brightness |
| `inactive = tune(c1, s_mul=0.45, v_hi=0.32)` | inactive border dimming |
| alpha `0xEE` / `0xAA` | border opacity |

Generated files (`~/.config/hypr/border-colors.lua` and `.conf`) are rewritten
on every change — don't edit them by hand.

## How it works

- `hyprctl eval 'pcall(dofile, ".../border-colors.lua")'` updates the Lua config
  live; on the classic parser it uses `hyprctl keyword`, with `hyprctl reload
  config-only` as a fallback.
- Because the generated file is loaded from your config, colors also survive
  Hyprland restarts and logins.

## Porting to a new machine

1. Copy this folder over (or push it to a git repo and clone it).
2. `./install.sh`.
3. If you don't use PaperLite, bind `hypr-set-wallpaper` for your wallpaper.
