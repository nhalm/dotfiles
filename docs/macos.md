# macOS

AeroSpace tiling, sketchybar in place of the menu bar, and Karabiner turning
caps lock into a modifier. The config is the `macos` stow package; packages are
`install/Brewfile`.

## Keyboard

Karabiner maps **caps lock to ⌘⌃⌥**. Setup copies `install/karabiner.json` into place once, since Karabiner rewrites the file itself. Leaving out Shift means caps+Shift is a
second layer: caps acts on the focus, caps+Shift on the window.

| Chord | Action |
|---|---|
| `caps+1..6` / `caps+Shift+1..6` | focus workspace / move window there |
| `caps+h/j/k/l` / `caps+Shift+h/j/k/l` | focus / move window |
| `caps+Tab` | previous workspace |
| `caps+Shift+Tab`, `caps+M` | move workspace to the next monitor |
| `caps+w` | wallpaper picker |
| `Alt+minus` / `Alt+equal` | shrink / grow |
| `Alt+comma` / `Alt+slash` | accordion / tiles |
| `Alt+semicolon` | service mode: join, flatten, float, volume; `esc` reloads |

`Alt+h/j/k/l` is left to herdr-splits, which resizes Neovim splits and herdr
panes. The full set is in `aerospace.toml`.

Workspaces 1–6 are persistent, so sketchybar always shows them. Apps are
assigned to workspaces with `on-window-detected` rules in `aerospace.toml`.

## Bar

sketchybar runs its Lua config under mise's Lua 5.5, which SbarLua is built
against. Workspaces sit on the left, following `aerospace subscribe`; calendar,
weather, battery, volume, performance, Wi-Fi, Bluetooth, media and wallpaper
items on the right.

Clicking an item opens a popup from
[barpop](https://github.com/nhalm/barpop), a SwiftUI app setup clones to
`~/.local/share/barpop` and builds; `helpers/barpop.lua` starts it with
sketchybar. Weather uses `helpers/location.sh`, which caches the last
CoreLocation fix. The Wi-Fi name needs `ipconfig setverbose 1`, from host-setup's
`macos-system`.

Setup hides the system menu bar (`_HIHideMenuBar`), the one macOS default the
repo writes.

## Theming

`wallpaper.sh <image>|--restore` sets the desktop picture, runs matugen and
reloads sketchybar, barpop, ghostty, Neovim and the window borders. The prompt
picks up the change at the next prompt; Zen at its next start, or live with
host-setup's `zen` module. Light/dark follows the system appearance.

`caps+w` opens barpop's picker: type to filter, hover to preview a palette,
return to apply.

## Other setup

`install/macos.sh` also links the ghostty CLI and the docker compose plugin,
turns off colima's `~/.ssh/config` include (that file is linked into this repo),
builds SbarLua, and starts sketchybar and borders as brew services. Colima runs
the docker daemon; `docker` is the CLI only.
