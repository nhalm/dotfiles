# Linux

A Hyprland session on [CachyOS](https://cachyos.org), with a quickshell bar,
swaync notifications, and colours taken from the wallpaper by matugen. The
config is the `linux` stow package; packages are `install/pacman.txt` (beyond
what CachyOS installs) and `install/aur.txt`.

## Session

Hyprland is configured in Lua. `hyprland.lua` only requires the other files:

| File | Holds |
|---|---|
| `monitors_default.lua` | the scale variant, then the untracked `monitors.lua` |
| `looks.lua` | env, gaps, borders, animations |
| `input.lua` | keyboard, touchpad, gestures |
| `programs.lua` | terminal, launcher, browser, file manager — named once, used by keybinds |
| `keybinds.lua` | every binding |
| `rules.lua` | window rules |
| `lid.lua` | clamshell |
| `autostart.lua` | wallpaper, quickshell, swaync, hypridle, clipboard history, polkit agent, blueman-applet, 1Password |

`hyprctl reload` doesn't re-run autostart.

`SUPER+/` shows every binding, grouped by the `"Category: action"` description
each bind carries; a bind without a description doesn't appear. `SUPER` is the
modifier, `SUPER+SHIFT` acts on the window instead of the focus, and the layout
is Hyprland's `scrolling` (columns on a tape).

| Function | Owner |
|---|---|
| Bar, popups, sidebar (`SUPER+A`), overview (`SUPER+Tab`), wallpaper picker (`SUPER+W`) | [hyprland-quickshell](https://github.com/nhalm/hyprland-quickshell) |
| Notifications, control center (`SUPER+N`) | swaync |
| Launcher / dmenu pickers | hyprlauncher / fuzzel |
| Idle / lock | hypridle / hyprlock |
| Display layout | nwg-displays |
| Screenshots / recording | hyprshot + satty / `screenrec.sh` |
| Login | ly |

## Theming

`wallpaper.sh <image>|--random|--restore` sets the wallpaper with awww, runs
matugen, records the choice in `~/.local/state/wallpaper`, and tells each app to
reload. `SUPER+SHIFT+W` (`theme-mode.sh`) toggles light/dark: it writes
`~/.local/state/matugen/mode` and both `gtk-*/settings.ini`, then re-runs
`wallpaper.sh --restore`.

Templates are in `.config/matugen/templates/` of `linux` and `shared`;
quickshell's ships with it. Edit templates, never their output.

| Output | Picked up |
|---|---|
| quickshell, swaync, ghostty, Neovim, Hyprland borders | live, signalled by `wallpaper.sh` |
| starship, fuzzel, hyprlock | next prompt, launch or lock |
| gtk | live, by toggling `color-scheme` |
| Qt (qt6ct), Zen | next start |

Borders change through `hyprctl eval`, not a reload, which would re-apply
monitor rules and flicker every display.

## Monitors and lid

Displays are packed left to right at the scale of a variant named in
`~/.config/hypr/monitor-variant` (`preferred`, `scale-125` (default),
`scale-150`, `highres`). A real arrangement comes from nwg-displays, which
writes the untracked `~/.config/hypr/monitors.lua`, matching displays by
description because connector names change across docks and boots.

Closing the lid with another display connected disables the internal panel
(`HYPR_INTERNAL_MONITOR`, default `eDP-1`); without one, logind suspends. Both
`lid.lua`, at config load, and `hypr-lid.sh`, from the switch binds, do it,
because a reload re-enables the panel. Opening the lid reloads, which restores
the nwg-displays layout. `HYPR_LID_LOCK=0` keeps the session unlocked on close.

## Idle

| After | hypridle does |
|---|---|
| 5 min | dim to 10% |
| 10 min | lock |
| 15 min | screens off (`wlopm`) |
| 20 min | suspend, only on battery with nothing playing (`suspend-if-on-battery.sh`) |

Only the suspend step ignores inhibitors.

## Shell and SSH

`os.zsh` adds GNU colour aliases and `pbcopy`/`pbpaste` over `wl-copy`.
`SSH_AUTH_SOCK` points at gcr's agent in `.zprofile` and in Hyprland's env; the
first use prompts for the key's passphrase, and "automatically unlock" stores it
in the login keyring.

## Gotchas

- `hyprctl` exits 0 when a Lua call fails, so scripts check its output for
  `error`.
- Use `hyprctl eval`, not `hyprctl keyword`, which a Lua config rejects.
- Outputs power off through `wlopm`; Hyprland's dpms dispatcher is not used.
- `network-manager-applet` is installed for `nm-connection-editor`; the applet
  never runs.
