# Arch Linux

The desktop is a Hyprland session with a quickshell bar, swaync notifications,
and a colour scheme derived from the wallpaper by matugen. Everything here lives
in the `arch` stow package unless noted; `linux` holds what any distro would use.

The base system comes from
[nhalm/arch-install](https://github.com/nhalm/arch-install) — LUKS, btrfs +
snapper, pipewire, NetworkManager, bluetooth, printing. `packages.txt` lists
only what that does not already provide.

## Session

Hyprland is configured in **Lua**, not `hyprland.conf`. `arch/.config/hypr/hyprland.lua`
is a table of contents and nothing else:

```
monitors_default   defaults, and which scale variant to use
monitors           machine-local override, pcall'd — untracked, absent on a fresh machine
looks              env, gaps, borders, decoration, animations
input              keyboard, touchpad, gestures
keybinds           every binding
rules              window rules
lid                clamshell
autostart          what starts with the session
```

`programs.lua` is required by `keybinds.lua`. It is the single place terminal,
launcher, browser and file manager are named:

| Key | Value |
|---|---|
| `terminal` | ghostty |
| `menu` | hyprlauncher |
| `browser` | zen-browser |
| `fileManager` | nemo |
| `colorPicker` | hyprpicker -a |
| `audioMixer` | pavucontrol — the app the `float-audio-mixer` rule exists for |

### What starts with the session

`autostart.lua`, in order:

| Command | Purpose |
|---|---|
| `wallpaper.sh --restore` | last wallpaper, and the palette derived from it; starts the wallpaper daemon itself |
| `qs -d` | quickshell: bar, sidebar, overview, wallpaper picker, keybind overlay |
| `swaync` | notification daemon and control center |
| `hypridle` | idle timeouts |
| `low-battery-notify.sh` | threshold warnings |
| `wl-paste --watch cliphist store` ×2 | clipboard history, text and image |
| `wl-clip-persist --clipboard regular` | keeps a selection alive after the source window closes |
| `systemctl --user start hyprpolkitagent.service` | polkit agent; ships a user unit, not a plain binary |
| `blueman-applet` | BlueZ pairing agent only — its tray icon is disabled by `post-link.sh` |
| `1password --silent` | starts to tray; the SSH agent must run to answer git |

`hyprctl reload` does not re-fire `hyprland.start`, so a reload does not re-run
any of this.

### Who owns what

| Function | Owner |
|---|---|
| Bar, tray, workspaces, clock, volume/battery/updates/power-profile, power menu | quickshell |
| Sidebar (quick settings), overview, wallpaper picker, keybind overlay | quickshell |
| Notification daemon, toasts, control center, DND state | swaync |
| Notification count and DND glyph in the bar | quickshell, reading `swaync-client -swb` |
| App launcher | hyprlauncher |
| Clipboard history picker | fuzzel |
| Wallpaper picker | quickshell carousel, `SUPER+W` or the sidebar |
| Wallpaper daemon | `awww-daemon`, started on demand by `wallpaper.sh` |
| Idle | hypridle |
| Lock | hyprlock |
| Network / bluetooth UI | quickshell sidebar; `nm-connection-editor` and `blueman-manager` for detail |
| Display layout | nwg-displays |
| Screenshots, annotation, recording | hyprshot, satty, `screenrec.sh` (slurp + wf-recorder) |
| Display manager | ly (`ly@tty2.service`) |

swaync's panel (`SUPER+N`) and the quickshell sidebar (`SUPER+A`) both offer
DND, Wi-Fi, bluetooth and media controls, and are independent of each other.

`bar.json` names only the modules in the bar's islands; `shell.qml` instantiates
`Sidebar`, `Hotkeys`, `Overview` and `WallpaperPicker` directly, each reachable
over `qs ipc call <target> toggle`. `NowPlaying` owns the `media` target.

In the overview, `h`/`l` or arrows walk the tiles, `j`/`k` jump a workspace,
Enter focuses, Escape closes.

## Keybindings

`SUPER` throughout; `SUPER+SHIFT` acts on the window rather than the focus.

### Launching

| Chord | Action |
|---|---|
| `SUPER+T` | ghostty |
| `SUPER+space` | hyprlauncher |
| `SUPER+E` | nemo |
| `SUPER+B` | zen-browser |
| `SUPER+SHIFT+C` | `hyprpicker -a` |

### Windows

| Chord | Action |
|---|---|
| `SUPER+h/j/k/l` | focus left/down/up/right |
| `SUPER+SHIFT+h/j/k/l` | move window |
| `SUPER+C` | close |
| `SUPER+F` | float this window |
| `SUPER+SHIFT+F` | float or re-tile **every** window on the workspace |
| `SUPER+mouse:272` / `mouse:273` | drag / resize |
| `SUPER+M` | `hyprshutdown` (session dialog) |
| `SUPER+Escape` | `loginctl lock-session` |

### Scrolling layout

Hyprland's `scrolling` layout: windows sit in columns on a tape extending past
the screen edge. `dwindle` and `master` stay configured in `looks.lua` for a
per-workspace rule.

| Chord | Action |
|---|---|
| `SUPER+h/l` | focus the column left / right |
| `SUPER+j/k` | focus within the column |
| `SUPER+minus` / `SUPER+equal` | cycle column width through `explicit_column_widths` |
| `SUPER+comma` / `SUPER+period` | scroll the tape one column |
| `SUPER+SHIFT+comma` / `SUPER+SHIFT+period` | swap the column with its neighbour |
| `SUPER+P` | move the window to its own column |
| `SUPER+V` | consume into the previous column, or expel if alone |
| `SUPER+G` | centre the focused column |
| `SUPER+CTRL+equal` | expand the window into the free space |
| `SUPER+CTRL+minus` | fit every visible column on screen |

### Workspaces

| Chord | Action |
|---|---|
| `SUPER+1`…`SUPER+9`, `SUPER+0` | focus workspace 1–9, 10 |
| `SUPER+SHIFT+1`…`0` | move window to that workspace |
| `SUPER+Tab` | overview (`qs ipc call overview toggle`) |
| `SUPER+slash` | keybind overlay (`qs ipc call hotkeys toggle`) |
| `SUPER+grave` | previous workspace |
| `SUPER+S` / `SUPER+SHIFT+S` | special workspace "magic": toggle / move window to |
| `SUPER+scroll` | next / previous workspace |

### Hardware keys

All bound `locked = true`, so they work on the lock screen.

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` / `LowerVolume` | `wpctl set-volume` ±5% (raise is capped with `-l 1`) |
| `XF86AudioMute` / `MicMute` | `wpctl set-mute` toggle |
| `XF86MonBrightnessUp` / `Down` | `brightnessctl -e4 -n2 set` ±5% |
| `XF86AudioNext` / `Prev` / `Play` / `Pause` | playerctl |

### Screenshots

`CTRL+SHIFT` + digit. Output goes to `~/Pictures/Screenshots`.

| Chord | Action |
|---|---|
| `CTRL+SHIFT+4` | region |
| `CTRL+SHIFT+3` | whole output |
| `CTRL+SHIFT+5` | window |
| `CTRL+SHIFT+2` | region, then annotate in satty |
| `CTRL+SHIFT+6` | start/stop screen recording |

### Shell, theme and clipboard

| Chord | Action |
|---|---|
| `SUPER+A` | quickshell sidebar |
| `SUPER+N` | swaync control center |
| `SUPER+W` | wallpaper picker |
| `SUPER+CTRL+W` | random wallpaper |
| `SUPER+SHIFT+W` | toggle light/dark |
| `SUPER+SHIFT+V` | clipboard history through fuzzel |
| `SUPER+SHIFT+N` | toggle `hyprsunset -t 4000` |

### The keybind overlay

`SUPER+slash` renders `hyprctl binds -j`. A Lua dispatcher reports itself as
`__lua` with no argument, so `description` is all the overlay can read:

```lua
hl.bind(mod .. " + T", hl.dsp.exec_cmd(apps.terminal), { description = "Launch: terminal" })
```

Format is `"Category: what it does"`; the overlay groups on the prefix. A bind
with no description does not appear.

## Power

The profile is whatever you last set it to — nothing switches it on plug or
unplug, and power-profiles-daemon starts every boot on `balanced`.
`modules/PowerProfile.qml` cycles it from the bar.

It reads `org.freedesktop.UPower.PowerProfiles` over `busctl`.

**No global `python` pin** — it would shadow the distro interpreter. Pin per
project.

## Input

`kb_layout = "us"`, no remapping. Natural scroll on mouse and touchpad,
sensitivity −0.1, tap-to-click `lrm`, disable-while-typing. One gesture:
three-finger horizontal swipe switches workspace.

`follow_mouse = 2` is click-to-focus; `0` would also stop the *pointer*
following the cursor, killing hover states and scroll over an unfocused window.
`float_switch_override_focus = 0` stops focus jumping to whatever is under the
cursor when a window floats or re-tiles.

## Window rules

| Rule | Match | Effect |
|---|---|---|
| suppress-maximize-events | everything | stops apps that spam maximize from fighting the layout |
| fix-xwayland-drags | empty class and title, xwayland, floating | `no_focus` — drag surfaces must not steal focus |
| move-hyprland-run | `hyprland-run` | float, positioned near the bottom left |
| float-1password, float-audio-mixer, float-nm-connection-editor | those classes | float |
| pip-stays-visible | title `Picture-in-Picture` | float and pin |

## The bar

`arch/.config/quickshell/`. One `PanelWindow` per monitor, 32px tall inside a
42px window, holding three rounded "islands" that hide themselves when empty.

`bar.json` decides the layout and which modules appear:

```json
{
  "layout": "centered",
  "modules": {
    "left":   ["Launcher", "Workspaces"],
    "center": ["NowPlaying", "Volume", "Battery", "Clock"],
    "right":  ["Updates", "PowerProfile", "Tray", "Notifications", "PowerMenu"]
  }
}
```

Names are file names under `modules/`. `Config.qml` watches the file, so edits
apply live; a JSON error is logged and the previous value kept. `layout:
"centered"` centres the middle island on screen, otherwise it sits next to the
left one.

| Module | Shows | Click |
|---|---|---|
| `Launcher` | distro glyph | L hyprlauncher, R ghostty |
| `Workspaces` | one pill per occupied or focused workspace, per monitor | focus that workspace |
| `NowPlaying` | the source — YouTube, Spotify — collapses when nothing plays | L player dropdown, M play/pause |
| `Volume` | sink icon + percent | L mute, R pavucontrol, wheel ±5% |
| `Battery` | percent, warn under 20% — hidden on AC | — |
| `Clock` | `ddd dd MMM  HH:mm` | month calendar popup |
| `Updates` | `checkupdates` count, hidden at zero, polled every 30 min | ghostty running `sudo pacman -Syu` |
| `PowerProfile` | current profile | cycle power-saver → balanced → performance |
| `Tray` | SystemTray items | L activate, R menu |
| `Notifications` | swaync count / DND glyph | L control center, R toggle DND |
| `PowerMenu` | power glyph | lock, suspend, log out, reboot, shut down |

#### NowPlaying

The label shows the **source**, not the track. Clicking opens a popup with art,
title, artist, transport controls, and chips to pick between players.
Middle-click toggles play/pause; `qs ipc call media toggle` opens it for a
keybind. Starting a player from the popup pauses the others.

### Sidebar, overview, picker

Three overlay windows, each with an IPC handler:

| Window | Opened by | Contents |
|---|---|---|
| Sidebar | `SUPER+A`, `qs ipc call sidebar toggle` | theme toggle, colour picker, screenshot; wallpaper and display buttons; volume and brightness sliders; Wi-Fi, bluetooth, blue-light, idle-lock and DND toggles; MPRIS cards |
| Overview | `SUPER+Tab`, `qs ipc call overview toggle` | every window grouped by workspace; click to focus |
| Wallpaper picker | `SUPER+W`, `qs ipc call wallpaper toggle` | searchable carousel with live palette preview |

Full IPC surface:

```
qs ipc call theme-manager reload
qs ipc call sidebar   toggle | open | close
qs ipc call overview  toggle | close
qs ipc call wallpaper toggle | open | close
```

The sidebar closes on click-away or `Escape`. The wallpaper picker previews the
palette of whatever is highlighted, so the whole shell retints as you scroll.

## Theming

matugen derives a Material palette from the wallpaper. One command drives it:

```bash
wallpaper.sh <image>     # a specific image
wallpaper.sh --random
wallpaper.sh --restore   # what autostart runs
```

The script has no interactive mode. It sets the wallpaper with `awww`, runs
matugen, records the path in `~/.local/state/wallpaper`, then reloads each
consumer.

Templates live in `arch/.config/matugen/templates/`, except `ghostty-colors`,
`starship.toml` and `zen-colors.css`, which are in `shared/`.

| Template | Output | Consumer | Reload |
|---|---|---|---|
| `colors.json` | `~/.local/state/matugen/colors.json` | quickshell `Theme.qml` | `qs ipc call theme-manager reload` |
| `hyprland-colors.lua` | `~/.config/hypr/matugen-colors.lua` | `looks.lua` | borders applied live by `hyprctl eval` |
| `ghostty-colors` | `~/.config/ghostty/colors` | `config-file = ?colors` | SIGUSR2, sent by `wallpaper.sh` |
| `colors.css` | `~/.config/swaync/colors.css` | swaync glass theme | `swaync-client --reload-css` |
| `gtk-colors.css` | `~/.config/gtk-3.0/colors.css` and `gtk-4.0/colors.css` | both `gtk.css` files | `color-scheme` bounce |
| `hyprlock-colors.conf` | `~/.local/state/matugen/hyprlock-colors.conf` | `hyprlock.conf` | next lock |
| `qtct-colors.conf` | `~/.local/state/matugen/qtct-colors.conf` | qt6ct | app restart |
| `fuzzel-colors.ini` | `~/.config/fuzzel/colors.ini` | `fuzzel.ini` | next launch |
| `starship.toml` | `~/.local/state/matugen/starship.toml` | `STARSHIP_CONFIG`, set by `os.zsh` | next prompt |
| `btop.theme` | `~/.config/btop/themes/matugen.theme` | btop — nothing in the repo selects it | — |
| `zen-colors.css` | `~/.local/state/matugen/zen-colors.css` | `userChrome.css` `@import` | live, within 5s |
| `nvim-colors.lua` | `~/.local/state/matugen/nvim-colors.lua` | tokyonight `on_colors` | `:MatugenReload`, sent by `wallpaper.sh` |

`link_zen_theme` runs in post-link: it resolves the profile from `profiles.ini` —
the `[Install*]` section, not the one marked `Default=1` — symlinks the render
into `chrome/zen-matugen.css`, prepends the `@import` to `userChrome.css`, and
sets `toolkit.legacyUserProfileCustomizations.stylesheets` in `user.js`.

`install_zen_autoconfig` puts `lib/zen/zen-matugen.cfg` and its prefs file beside
the Zen binary, with sudo. Zen reads `userChrome.css` only at startup, so that
script polls the rendered palette every 5s and loads it into open windows as a
user-origin sheet. It also installs `distribution/policies.json`, which disables
Zen's own updater -- an upgrade replaces these files and ends the live reload.
After upgrading Zen deliberately, re-run `./setup.sh`.

Borders go through `hyprctl eval` rather than a config reload: a reload
re-applies the monitor rules and flickers every display.

Light/dark lives in `~/.local/state/matugen/mode`, written only by
`theme-mode.sh` (`SUPER+SHIFT+W`), which also writes both `gtk-*/settings.ini`
— untracked, because they carry the mode, so a stowed copy would be wrong in one
of them — then re-runs `wallpaper.sh --restore`.
`gtk-theme-name` stays `Adwaita`, since the generated `colors.css` overrides
every libadwaita named colour.

Wallpapers come from [nhalm/wallpapers](https://github.com/nhalm/wallpapers),
cloned to `~/.local/share/wallpapers` by the Arch post-link step. `WALLPAPER_REPO`
and `WALLPAPER_DIR` override source and destination.

## Monitors

Placement is never stored: each variant is one catch-all rule (`output = ""`,
`position = "auto"`) packing displays left-to-right.

Pick a variant by writing its name to `~/.config/hypr/monitor-variant`; an
unknown name falls back to `scale-125`:

| Variant | Mode | Scale |
|---|---|---|
| `preferred` | preferred | 1 |
| `scale-125` (default) | preferred | 1.25 |
| `scale-150` | preferred | 1.5 |
| `highres` | highest available | auto |

The internal panel is pinned unconditionally on the last line (`eDP-1`,
preferred, scale 1.25), so a variant only affects **external** displays. The
same value is repeated as `HYPR_INTERNAL_SCALE` in `hypr-lid.sh`.

A specific arrangement goes in `~/.config/hypr/monitors.lua`, written by
nwg-displays — untracked, `pcall`ed after the defaults so it overrides them.
Tick **"use monitor descriptions"** there, so rules match on description rather
than connector name.

`hypr-monitors.sh` re-packs enabled monitors left-to-right from x=0, matching on
description — connector names are not stable across boots. Only the lid-closed
path calls it.

## Lid and clamshell

Closing the lid disables the internal panel and leaves externals running, but
only while another display is connected. Undocked, logind suspends instead
(`HandleLidSwitchDocked`).

The disable happens in both `lid.lua`, at config parse time, and `hypr-lid.sh`,
from the `switch:` binds and `sync` at config load. Both are needed: a reload
re-enables the panel, and reacting afterwards from an async exec loses that
race.

`hypr-lid.sh` reads `/proc/acpi/button/lid/*/state` rather than the switch edge,
and uses `hyprctl eval`, never `hyprctl keyword`, which a Lua-configured
Hyprland rejects.

On close: record the panel's workspace, disable the output, re-pack the
remaining monitors, re-focus that workspace, lock. On open: `hyprctl reload`,
which restores the nwg-displays layout.

| Variable | Default | Effect |
|---|---|---|
| `HYPR_INTERNAL_MONITOR` | `eDP-1` | which output is the panel |
| `HYPR_INTERNAL_MODE` / `_POSITION` / `_SCALE` | preferred / auto / 1.25 | re-enable fallback if reload fails |
| `HYPR_LID_LOCK` | `1` | `0` keeps working on externals with the lid closed |
| `HYPR_MONITORS_DELAY` | `0.4` | settle time before re-packing after a hotplug |

One line per invocation is logged to `$XDG_RUNTIME_DIR/hypr-lid.log`.

## Idle and lock

`hypridle.conf`:

| After | Action |
|---|---|
| 300s | dim to 10% (`brightnessctl -s`, restored on resume) |
| 600s | `loginctl lock-session` |
| 900s | screens off — `wlopm --off '*'`, back on with any activity |
| 1200s | `suspend-if-on-battery.sh` — only on battery, and only if nothing is playing |

### Inhibitors

The suspend listener carries `ignore_inhibit = true`; dim, lock and screens-off
do not. `suspend-if-on-battery.sh` bails if any MPRIS player reports `Playing`;
a site publishing no MPRIS session is the gap.

Outputs power down through `wlopm`, not Hyprland's dpms dispatcher.

hyprlock draws a centred input field over the matugen palette, with a large clock
and date, and sources its colours from
`~/.local/state/matugen/hyprlock-colors.conf`.

## Scripts

`arch/.local/scripts/`:

| Script | Arguments | Invoked by |
|---|---|---|
| `wallpaper.sh` | image, `--random`, `--restore` | autostart, `SUPER+CTRL+W`, the carousel, `theme-mode.sh` |
| `theme-mode.sh` | none (toggle), `dark`, `light`, `--apply`, `--current` | `SUPER+SHIFT+W`, sidebar, arch post-link |
| `hypr-lid.sh` | `closed`, `open`, `sync` | lid switch binds, config load |
| `hypr-monitors.sh` | — | `hypr-lid.sh` on close |
| `toggle-float.sh` | — | `SUPER+SHIFT+F` |
| `screenrec.sh` | — (toggles) | `CTRL+SHIFT+6` |
| `low-battery-notify.sh` | — (60s loop) | autostart; warns once per crossing at 20/10/5% |
| `suspend-if-on-battery.sh` | — | hypridle at 1800s |

No systemd units ship for these.

## Shell

zsh with a starship prompt. `linux/.zshrc` sources two fragments:
`~/.config/zsh/os.zsh` (tracked, from this package) and `~/.config/zsh/local.zsh`
(per-machine, gitignored).

| Area | Setting |
|---|---|
| History | 50000 lines in `$XDG_STATE_HOME/zsh/history`, shared and incrementally appended, dedup, `HIST_VERIFY` |
| Options | `AUTO_CD`, `AUTO_PUSHD`, `INTERACTIVE_COMMENTS`, no beep, no flow control (frees `Ctrl+S`/`Ctrl+Q`) |
| Completion | `compinit` cached in `$XDG_CACHE_HOME/zsh`, rebuilt at most once a day; menu select, case-insensitive matching, `LS_COLORS` |
| Keys | emacs bindings, `Ctrl+←/→` word motion, up/down search history against what is typed |
| Plugins | zsh-autosuggestions, zsh-completions, fast-syntax-highlighting — cloned by `lib/common.sh`, syntax highlighting sourced last |
| Tools | mise, zoxide (as `cd`), starship, fzf's own `--zsh` integration for `Ctrl+R` / `Ctrl+T` |

`os.zsh` sets GNU colour aliases, points `STARSHIP_CONFIG` at the matugen
render, and maps `pbcopy`/`pbpaste` onto `wl-copy`/`wl-paste`. The 1Password
`SSH_AUTH_SOCK` is set in `.zprofile`, so non-interactive shells reach the agent
too.

`.zprofile` holds environment only: `EDITOR`/`VISUAL` as nvim, `GOPATH`,
`PROJECTS_DIR`, `~/.local/bin` and the mise shims on `PATH`.

The prompt is two lines: directory, repo name when below the root, branch, git
state and status; then right-aligned language versions, docker context and
command duration over 2s. Exit status shows only through the character's colour.

Its config is a matugen template at
`shared/.config/matugen/templates/starship.toml` — edit the template, never the
output. The success character keeps a fixed green.

## Packages

`platform/linux/arch/packages.txt` lists only what a base `archinstall` does not
provide, and omits anything another entry pulls in as a dependency.

| Group | Contents |
|---|---|
| Kernel, hardware | linux-lts, linux-headers, intel-ucode, intel-media-driver, intel-lpmd, vulkan-intel, libva-utils, thermald, fwupd, sof-firmware, v4l2loopback-dkms |
| Filesystem | snapper, zram-generator |
| Security | ufw, gitleaks, arch-audit |
| Core | base-devel, git, git-lfs, openssh, stow, wget, unzip, man-db, clang, 7zip, jq, yq |
| Shell | zsh, starship, mise |
| Editor | neovim, python-pynvim, tree-sitter-cli, wl-clipboard, xclip |
| Search | ripgrep, fd, fzf, bat, glow, tree |
| System | htop, btop, pacman-contrib |
| Git | github-cli |
| Terminal | ghostty |
| Containers | docker, docker-compose, docker-buildx |
| Audio | pipewire-alsa/jack/pulse, gst-plugin-pipewire, wireplumber, alsa-utils, pavucontrol, playerctl |
| Network | network-manager-applet, blueman, bluez-utils |
| Hyprland session | hyprland, hyprlauncher, hyprpicker, hyprpolkitagent, hyprshutdown, hyprlock, hypridle, hyprshot, hyprsunset, xdg-desktop-portal-hyprland, quickshell, swaync, awww, matugen, fuzzel, satty, wf-recorder, cliphist, wl-clip-persist, nwg-displays, brightnessctl, wlopm, upower, power-profiles-daemon, ly, qt6ct, qt5/qt6 wayland, papirus-icon-theme |
| Printing | cups, cups-pk-helper, system-config-printer |
| Apps | firefox, nemo, imv, mpv, obs-studio, telegram-desktop, imagemagick |
| Fonts | ttf-monaspace-variable, ttf-jetbrains-mono-nerd, noto-fonts, noto-fonts-emoji, ttf-dejavu |

`aur.txt` holds `1password`, `1password-cli` and `zen-browser-bin`, installed
through yay with the PKGBUILD diff prompt kept.

`network-manager-applet` is installed for `nm-connection-editor`; the applet
itself is never started.

`spotify-launcher.conf` passes `--ozone-platform=wayland`, keeping Spotify off
XWayland.

## System state set by post-link

| Step | Detail |
|---|---|
| docker | enable `docker.service`, add the user to the `docker` group |
| backlight | add the user to `video` — a fallback only; brightnessctl goes through logind, which needs no permissions on `/sys/class/backlight` for the active session |
| display manager | enable `ly@tty2.service` |
| bluetooth | enable `bluetooth.service`; bluez ships it disabled and blueman cannot see the adapter without it |
| blueman | `gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"` — pairing agent without a tray icon |
| directories | `~/Pictures/Screenshots`, `~/Videos/Recordings` |
| wallpapers | clone or update `~/.local/share/wallpapers`, then pick one at random if none is recorded, so the generated palette exists before anything reads it |
| theme mode | `theme-mode.sh --apply`, which writes the two `settings.ini` files |
| hypridle | restarted if running — it reads its config only at startup, so a re-link alone leaves the old timeouts in place |
| swaync | `--reload-config` and `--reload-css` if running; it reloads in place, so the notification history survives |
| ssh | authorise agent keys, then install `system/` |
| firewall | ufw default deny inbound, allow outbound, ssh rate-limited (`limit 22/tcp`) |
| cache | enable `paccache.timer` |

Files installed under `/etc` come from `system/linux/etc/`:

| File | Effect |
|---|---|
| `ssh/sshd_config.d/99-hardening.conf` | key-only auth, no root login, `AllowUsers nick`, modern KEX/ciphers/MACs, no forwarding |
| `sysctl.d/99-hardening.conf` | `kptr_restrict`, kexec disabled, no redirects or source routing, log martians, `suid_dumpable = 0` |
| `security/faillock.conf` | 5 failures per 15 min, 15 min lockout |
| `docker/daemon.json` | bind published ports to `127.0.0.1`, live-restore, capped json logs |

`./setup.sh --diff-system` previews these without writing.

## Rough edges

Present in the config and not what a reader would guess:

- **The palette is not file-watched.** `Theme.qml` reads `colors.json` at
  startup and on IPC only, so editing that file by hand changes nothing until
  `qs ipc call theme-manager reload`. Qt apps only pick up a new palette when
  they restart.
- **Hardcoded `/home/nick` paths** remain in `qt6ct.conf`, whose
  `color_scheme_path` takes neither `~` nor an env var, and `AllowUsers nick` in
  the sshd drop-in. Change these first if the repo is reused.
- **`Config.qml`'s built-in defaults are smaller than `bar.json`** — no Launcher,
  NowPlaying, Updates or PowerProfile. A missing or malformed `bar.json` yields a
  visibly reduced bar rather than an error.
- **`hyprctl` exits 0 even when the Lua call fails**, so `hypr-lid.sh` and
  `hypr-monitors.sh` parse output for `error*` rather than checking the status.
  Anything new here must do the same.
- Both mute keys carry `repeating = true`, so holding one flips the state
  repeatedly.
- The `move-hyprland-run` window rule matches class `hyprland-run`, which no
  installed package provides — hyprlauncher is the launcher in use.
- `Wallpapers.setRandom()` is never called; `SUPER+CTRL+W` runs the script
  directly.
