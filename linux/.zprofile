# Login shells. Environment only -- interactive setup lives in .zshrc.

typeset -U path PATH

export EDITOR=nvim
export VISUAL=nvim

# Consumed by the sketchybar git widget on macOS; kept here so scripts shared
# between machines can rely on it.
export PROJECTS_DIR="$HOME/work:$HOME/personal:$HOME/dev"

export GOPATH="$HOME/go"

path=(
	"$HOME/.local/bin"
	"$GOPATH/bin"
	$path
)

# mise shims for processes that never source a shell rc (systemd units, GUI
# launchers). Interactive shells use `mise activate` in .zshrc instead, which
# always resolves the right version.
[[ -d $HOME/.local/share/mise/shims ]] && path+=("$HOME/.local/share/mise/shims")

export PATH
