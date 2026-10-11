# hypr-wallcolors → hypr-theme

Match your Hyprland **border color and app themes to your wallpaper**, and keep
them in sync automatically whenever the wallpaper changes.

Instead of theming the whole desktop with heavy tools, it does one thing well:
reads the current wallpaper, pulls a palette out of it, and applies it to the
tools you actually use.

```
window borders        gradient of the wallpaper's two most vibrant colors
kitty                 full 16-color palette + cursor/selection/tabs
fuzzel                menu colors (background, selection, match, border)
cava                  audio visualizer colors
btop                  monitor theme
(optional: GTK3/GTK4   via commented toggle in the theme config)
```

## Requirements

- Hyprland (classic `hyprland.conf` **or** the newer `hyprland.lua` parser)
- `python3`, ImageMagick (`magick`)
- `noctalia` — ships the template engine used to theme kitty/fuzzel/cava/btop
- systemd user session (for the auto-update watcher)
- optional: `swayosd` for volume/brightness popups

Install them, e.g. on Arch / CachyOS:

```sh
sudo pacman -S noctalia imagemagick python swayosd
```

## Install

```sh
git clone <this-repo> ~/hypr-wallcolors   # or just copy the folder over
cd ~/hypr-wallcolors
./install.sh
```

The installer:

1. copies `hypr-wallcolors`, `hypr-theme` and `hypr-set-wallpaper` to
   `~/.local/bin`;
2. installs the Noctalia template engine config to
   `~/.config/noctalia/theme/`;
3. patches your `hyprland.lua` / `hyprland.conf` (idempotent, marked with
   `-- >>> hypr-wallcolors >>>` blocks so it can be cleanly removed):
   - loads the generated border colors;
   - registers the **full `hypr-theme` hook on login** (borders + kitty +
     fuzzel + cava + btop);
4. installs and enables a systemd user **path unit** that re-runs the whole
   theme on every wallpaper change;
5. applies the theme immediately.

> Picking a wallpaper is a separate tool: [hypr-wallpicker](https://github.com/barknq11/hypr-wallpicker).

### Wallpaper backends

`hypr-theme` auto-detects the current wallpaper from **PaperLite/swaybg**,
**swww**, or **hyprpaper**.

- **PaperLite / swaybg**: works out of the box — the watcher follows
  `~/.config/swaybg/current_wallpaper.sh`, which PaperLite rewrites on change.
- **swww / hyprpaper**: call `hypr-set-wallpaper /path/to/image` instead of your
  usual set command, or use the picker (both set the wallpaper and theme).

### Wallpaper picker (SUPER+W)

Use [hypr-wallpicker](https://github.com/barknq11/hypr-wallpicker) — a tiny GTK4
grid that shows every wallpaper newest-first and applies the one you click. It
calls `hypr-set-wallpaper`, so picking one here themes everything automatically.

`install.sh` over there binds **SUPER+W** for you.

### Commands

```sh
hypr-wallcolors                 # borders only
hypr-wallcolors /path/to/img    # borders only, specific image
hypr-theme                      # borders + kitty + fuzzel + cava + btop
hypr-set-wallpaper /path/img    # set wallpaper + full theme
```
> Pick your wallpaper visually with [hypr-wallpicker](https://github.com/barknq11/hypr-wallpicker).

## Customizing

- **Palette magic** (`hypr-wallcolors`): `ANGLE`, `tune(..., s_mul, v_lo, v_hi)`
  control the border gradient vividness; see the top of the script.
- **App theming** (`~/.config/noctalia/theme/config.toml`): toggle targets.
  GTK is off by default (it overwrites `~/.config/gtk-3.0/gtk.css` and the
  gtk-4.0 files). Uncomment the `[templates.gtk3]` / `[templates.gtk4]` blocks
  if you want them. `install.sh` keeps a backup of your config dirs in
  `~/.config-bak` before touching them.

## Dialogue / OSD keys

`install.sh` wires the full-theme login hook automatically, but does **not**
touch OSD binds. For swayosd volume/brightness popups, bind:

```lua
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise 2>/dev/null || wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("swayosd-client --brightness raise 2>/dev/null || brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("swayosd-client --brightness lower 2>/dev/null || brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
```

And autostart the server once:

```sh
command -v swayosd-server >/dev/null 2>&1 && swayosd-server
```

## Uninstall

```sh
./uninstall.sh
```

Removes the scripts, generated colors, theme engine, systemd units, and the
marked config blocks. Restore your original configs from `~/.config-bak` (e.g.
kitty's old `kitty.conf`, cava `config`, btop `btop.conf`) if you want them back.

## Porting to a new machine

1. Copy the folder over (or clone from git).
2. `./install.sh` — scripts, theme engine, border colors, full-theme login hook
   and the wallpaper-change watcher are all set up.
3. Install [hypr-wallpicker](https://github.com/barknq11/hypr-wallpicker) for a
   visual wallpaper picker bound to SUPER+W.
4. Install `swayosd` if you want the volume/brightness OSD.