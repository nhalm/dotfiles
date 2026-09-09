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

`programs.lua` is not loaded here — `keybinds.lua` requires it. It is the single
place terminal, launcher, browser and file manager are named:

| Key | Value |
|---|---|
| `terminal` | ghostty |
| `menu` | hyprlauncher |
| `browser` | firefox |
| `fileManager` | nemo |
| `colorPicker` | hyprpicker -a |
| `audioMixer` | pavucontrol — the app the `float-audio-mixer` rule exists for |

### What starts with the session

`autostart.lua`, in order:

| Command | Purpose |
|---|---|
| `wallpaper.sh --restore` | last wallpaper, and the palette derived from it; starts the wallpaper daemon itself |
| `qs -d` | quickshell: bar, sidebar, overview, wallpaper picker |
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
| Sidebar (quick settings), overview, wallpaper picker | quickshell |
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

swaync and the quickshell sidebar both offer DND, Wi-Fi, bluetooth and media
controls. They are independent panels: `SUPER+N` opens swaync's, `SUPER+A` opens
quickshell's.

`modules/Network.qml` and `modules/Bluetooth.qml` exist but are not listed in
`bar.json`, so they never load. Network and bluetooth status come from the
sidebar only.

## Keybindings

`SUPER` throughout; `SUPER+SHIFT` acts on the window rather than the focus.

### Launching

| Chord | Action |
|---|---|
| `SUPER+T` | ghostty |
| `SUPER+R` | hyprlauncher |
| `SUPER+E` | nemo |
| `SUPER+B` | firefox |
| `SUPER+SHIFT+C` | `hyprpicker -a` |

### Windows

| Chord | Action |
|---|---|
| `SUPER+h/j/k/l` | focus left/down/up/right |
| `SUPER+SHIFT+h/j/k/l` | move window |
| `SUPER+C` | close |
| `SUPER+F` | float this window |
| `SUPER+SHIFT+F` | float or re-tile **every** window on the workspace |
| `SUPER+P` | pseudo |
| `SUPER+V` | togglesplit (dwindle only) |
| `SUPER+minus` / `SUPER+equal` | resize −50 / +50, repeatable |
| `SUPER+mouse:272` / `mouse:273` | drag / resize |
| `SUPER+M` | `hyprshutdown` (session dialog) |
| `SUPER+Escape` | `loginctl lock-session` |

### Workspaces

| Chord | Action |
|---|---|
| `SUPER+1`…`SUPER+9`, `SUPER+0` | focus workspace 1–9, 10 |
| `SUPER+SHIFT+1`…`0` | move window to that workspace |
| `SUPER+Tab` | overview (`qs ipc call overview toggle`) |
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

`CTRL+SHIFT` + digit, matching CleanShot X on the Mac — `SUPER+SHIFT+<digit>` is
taken by move-to-workspace. Output goes to `~/Pictures/Screenshots`.

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

## Input

`kb_layout = "us"` with no remapping — there is no keyd or kanata equivalent of
the Mac's Karabiner setup. Natural scroll on both mouse and touchpad,
`follow_mouse = 1`, sensitivity −0.1, tap-to-click `lrm`, disable-while-typing.
One gesture: three-finger horizontal swipe switches workspace.

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
| `NowPlaying` | MPRIS title, collapses when nothing plays | play/pause |
| `Volume` | sink icon + percent | L mute, R pavucontrol, wheel ±5% |
| `Battery` | percent, warn under 20% — hidden on AC | — |
| `Clock` | `ddd dd MMM  HH:mm` | month calendar popup |
| `Updates` | `checkupdates` count, hidden at zero, polled every 30 min | ghostty running `sudo pacman -Syu` |
| `PowerProfile` | current profile | cycle power-saver → balanced → performance |
| `Tray` | SystemTray items | L activate, R menu |
| `Notifications` | swaync count / DND glyph | L control center, R toggle DND |
| `PowerMenu` | power glyph | lock, suspend, log out, reboot, shut down |

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

The sidebar closes on click-away or `Escape`, and nothing in it polls while it
is closed. The wallpaper picker previews the palette of whatever is highlighted,
so the whole shell retints as you scroll; applying keeps the previewed colours
rather than reverting and regenerating them.

## Theming

matugen derives a Material palette from the wallpaper. One command drives it:

```bash
wallpaper.sh <image>     # a specific image
wallpaper.sh --random
wallpaper.sh --restore   # what autostart runs
```

Choosing one interactively is the carousel's job — `SUPER+W`, or the sidebar's
Wallpaper button, both of which are `qs ipc call wallpaper toggle`. The script
takes no interactive mode; with no argument it prints usage and exits 1.

It sets the wallpaper with `awww`, runs `matugen image … -m <mode>`, records the
path in `~/.local/state/wallpaper`, then reloads each consumer:

| Template | Output | Consumer | Reload |
|---|---|---|---|
| `colors.json` | `~/.local/state/matugen/colors.json` | quickshell `Theme.qml` | `qs ipc call theme-manager reload` |
| `hyprland-colors.lua` | `~/.config/hypr/matugen-colors.lua` | `looks.lua` | borders applied live by `hyprctl eval` |
| `ghostty-colors` | `~/.config/ghostty/colors` | `config-file = ?colors` | new windows |
| `colors.css` | `~/.config/swaync/colors.css` | swaync glass theme | `swaync-client --reload-css` |
| `gtk-colors.css` | `~/.config/gtk-3.0/colors.css` and `gtk-4.0/colors.css` | both `gtk.css` files | `color-scheme` bounce |
| `hyprlock-colors.conf` | `~/.local/state/matugen/hyprlock-colors.conf` | `hyprlock.conf` | next lock |
| `qtct-colors.conf` | `~/.local/state/matugen/qtct-colors.conf` | qt6ct | app restart |
| `fuzzel-colors.ini` | `~/.config/fuzzel/colors.ini` | `fuzzel.ini` | next launch |
| `starship.toml` | `~/.local/state/matugen/starship.toml` | `STARSHIP_CONFIG`, set by `os.zsh` | next prompt |
| `btop.theme` | `~/.config/btop/themes/matugen.theme` | btop — nothing in the repo selects it | — |

Borders are applied with a single `hyprctl eval` rather than a config reload,
because a reload re-applies the monitor rules and makes every display flicker.

Light/dark lives in `~/.local/state/matugen/mode`, written only by
`theme-mode.sh` (`SUPER+SHIFT+W`). It also writes both `gtk-3.0/settings.ini`
and `gtk-4.0/settings.ini` — those carry the mode, so a stowed copy would be
wrong in one of them, and matugen cannot render them because templates see
colours but not the mode. `gtk-theme-name` stays `Adwaita` in both modes: the
generated `colors.css` overrides every libadwaita named colour, so the stock
theme's own palette never shows. Then it re-runs `wallpaper.sh --restore`.

Two hardcoded TokyoNight fallbacks remain, and both exist because something must
render before matugen has ever run: the property defaults in `Theme.qml`, and
`hypr/colors.lua` for the border colours. Neither is normally reached — Arch
post-link seeds a wallpaper, so the generated palette exists from setup onward.

Ghostty's `theme = TokyoNight Storm` is not a fallback: `config-file = ?colors`
is optional and that file only exists on Arch, so the base theme is what macOS
actually uses.

Wallpapers come from [nhalm/wallpapers](https://github.com/nhalm/wallpapers),
cloned to `~/Pictures/Wallpapers` by the Arch post-link step. `WALLPAPER_REPO`
and `WALLPAPER_DIR` override source and destination.

## Monitors

Placement is never stored. `monitors_default.lua` picks a variant and each
variant file is a single catch-all rule (`output = ""`) with `position = "auto"`,
which packs displays left-to-right with no gaps — so an unfamiliar monitor works
with no rule written for it, and no coordinates can go stale when a scale
changes.

Pick a variant by writing its name to `~/.config/hypr/monitor-variant`; an
unknown name falls back to `scale-125`:

| Variant | Mode | Scale |
|---|---|---|
| `preferred` | preferred | 1 |
| `scale-125` (default) | preferred | 1.25 |
| `scale-150` | preferred | 1.5 |
| `highres` | highest available | auto |

The internal panel is then pinned separately, on the last line and
unconditionally: `eDP-1`, preferred mode, scale 1.25. So the variant only ever
affects **external** displays — the panel is always 1.25× unless `monitors.lua`
overrides it. The same value is repeated as `HYPR_INTERNAL_SCALE` in
`hypr-lid.sh`.

Anything needing a specific arrangement — ordering two identical displays —
goes in `~/.config/hypr/monitors.lua`, which nwg-displays writes. That file is
untracked and unstowed; `hyprland.lua` `pcall`s it after the defaults so it
overrides them and is simply absent on a fresh machine. Tick **"use monitor
descriptions"** in nwg-displays so its rules match on description rather than
connector name.

`hypr-monitors.sh` re-packs enabled monitors left-to-right from x=0 using each
one's real logical width, matching on description because connector names are
not stable across boots. Only the lid-closed path calls it.

## Lid and clamshell

Closing the lid disables the internal panel and leaves the externals running,
but only while another display is connected — otherwise Hyprland would be left
with no output. That case needs no handling: logind selects
`HandleLidSwitchDocked` (default `ignore`) whenever more than one display is
connected, so an undocked lid close still suspends.

The disable happens twice, deliberately:

- `lid.lua`, at config parse time. Every reload re-applies `monitors.lua` and
  re-enables the panel; reacting afterwards from an async exec loses the race and
  puts windows back on a shut screen.
- `hypr-lid.sh`, from the two `switch:` binds and from `sync` at every config
  load.

`hypr-lid.sh` reads the kernel lid state from `/proc/acpi/button/lid/*/state`
rather than trusting which switch edge fired, which has been unreliable for lids
in the Lua config; the passed argument is only a fallback for when `/proc/acpi`
is unreadable. It uses `hyprctl eval`, never `hyprctl keyword` — a
Lua-configured Hyprland rejects `keyword` outright while still exiting 0.

On close it records the panel's workspace, disables the output, re-packs the
remaining monitors (Hyprland migrates the workspace but leaves the receiving
monitor showing its own, so windows arrive hidden), re-focuses that workspace,
and locks the session. On open it runs `hyprctl reload`, which restores the saved
nwg-displays layout exactly instead of fighting it with `position = auto`.

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
| 1800s | `suspend-if-on-battery.sh` — suspends only on battery; on AC the machine is docked and stays up |

Powering the outputs down goes through `wlopm` rather than Hyprland's own
dispatcher. `hl.dsp.dpms` ignores its argument and toggles every monitor, so a
monitor that changed state on its own — as happens during lock — desyncs
permanently with no way back, and `hyprctl dispatch dpms off` is rejected
outright by the Lua parser. `wlopm` speaks `zwlr_output_power_manager_v1`, which
Hyprland advertises, and takes an explicit `--off` / `--on`.

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

No systemd units ship for these; the long-running ones start from `autostart.lua`.

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

`os.zsh` exports `SSH_AUTH_SOCK` for the 1Password agent, sets GNU colour
aliases, and maps `pbcopy`/`pbpaste` onto `wl-copy`/`wl-paste`.

`.zprofile` holds environment only: `EDITOR`/`VISUAL` as nvim, `GOPATH`,
`PROJECTS_DIR`, `~/.local/bin` and the mise shims on `PATH`.

The starship prompt is two lines — directory, repo name when below the repo
root, branch, git state and status, then right-aligned language versions, docker
context and command duration over 2s. Exit status shows only through the prompt
character's colour.

Its palette comes from the wallpaper: the config lives as a matugen template at
`arch/.config/matugen/templates/starship.toml`, renders to
`~/.local/state/matugen/starship.toml`, and `os.zsh` points `STARSHIP_CONFIG`
at that file when it exists. Edit the template, never the output. The success
character keeps a fixed green — Material has no success role, and a
wallpaper-derived one could land on red, which is the failure colour.

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

`aur.txt` holds only `1password` and `1password-cli`, installed through yay with
the PKGBUILD diff prompt kept.

`network-manager-applet` is installed for `nm-connection-editor`; the applet
itself is never started.

## System state set by post-link

| Step | Detail |
|---|---|
| docker | enable `docker.service`, add the user to the `docker` group |
| backlight | add the user to `video` — a fallback only; brightnessctl goes through logind, which needs no permissions on `/sys/class/backlight` for the active session |
| display manager | enable `ly@tty2.service` |
| bluetooth | enable `bluetooth.service`; bluez ships it disabled and blueman cannot see the adapter without it |
| blueman | `gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"` — pairing agent without a tray icon |
| directories | `~/Pictures/Screenshots`, `~/Videos/Recordings` |
| wallpapers | clone or update `~/Pictures/Wallpapers`, then pick one at random if none is recorded, so the generated palette exists before anything reads it |
| theme mode | `theme-mode.sh --apply`, which writes the two `settings.ini` files |
| ssh | authorise agent keys, then install `system/` |
| firewall | ufw default deny inbound, allow outbound, ssh rate-limited (`limit 22/tcp`) |
| cache | enable `paccache.timer` |

Two separate ufw blocks run, with the `paccache.timer` step between them; the
second is the one that rate-limits ssh.

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

- **The palette is not file-watched.** `Theme.qml` reads `colors.json` with a
  `cat` process at startup and on IPC only, so editing that file by hand changes
  nothing until `qs ipc call theme-manager reload`. quickshell, swaync and
  hyprland and gtk are each reloaded explicitly; Qt apps only pick up a new
  palette when they restart.
- **The ghostty palette ignores light mode.** Its matugen template reads
  `.dark.hex` for every colour, so the terminal stays dark when everything else
  flips.
- **Hardcoded `/home/nick` paths** remain in `qt6ct.conf`, whose
  `color_scheme_path` takes neither `~` nor an env var, and `AllowUsers nick` in
  the sshd drop-in. These are the files to change first if the repo is reused.
- **`Config.qml`'s built-in defaults are smaller than `bar.json`** — no Launcher,
  NowPlaying, Updates or PowerProfile. A missing or malformed `bar.json`
  therefore yields a visibly reduced bar rather than an error.
- **`hyprctl` exits 0 even when the Lua call fails**, which is why both
  `hypr-lid.sh` and `hypr-monitors.sh` parse output for `error*` rather than
  checking the status. Anything new here must do the same.
- Both mute keys carry `repeating = true`, so holding one flips the state
  repeatedly.
- The `move-hyprland-run` window rule matches class `hyprland-run`, which no
  installed package provides — hyprlauncher is the launcher in use.
- `Wallpapers.setRandom()` is never called; `SUPER+CTRL+W` runs the script
  directly.
