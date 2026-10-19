# Login shells. Environment only -- interactive setup lives in .zshrc.

typeset -U path PATH

# Homebrew, where it exists. Must run before the path array below: shellenv
# prepends the prefix, and typeset -U then keeps a single copy of each entry.
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

export EDITOR=nvim
export VISUAL=nvim

# Consumed by the sketchybar git widget on macOS; kept here so scripts shared
# between machines can rely on it.
export PROJECTS_DIR="$HOME/work:$HOME/personal:$HOME/dev"

export GOPATH="$HOME/go"

# Linux: gcr's agent, which unlocks the key from the login keyring. macOS:
# launchd's agent, which a login item fills from Keychain.
if [[ -n $XDG_RUNTIME_DIR && -S $XDG_RUNTIME_DIR/gcr/ssh ]]; then
	export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
elif [[ $OSTYPE == darwin* ]]; then
	# Always launchd's agent, even when the pane inherited another one (herdr
	# forwards its attaching client's agent, which can't use this Mac's key).
	_agent=(/private/{var/run,tmp}/com.apple.launchd.*/Listeners(N=U[1]))
	(( $#_agent )) && export SSH_AUTH_SOCK=$_agent[1]
	unset _agent
fi

path=(
	"$HOME/.local/bin"
	"$GOPATH/bin"
	$path
)

# openjdk is keg-only: brew will not symlink it, because macOS ships its own
# java wrappers. Guarded on the directory, so it is a no-op elsewhere.
[[ -d /opt/homebrew/opt/openjdk/bin ]] && path=("/opt/homebrew/opt/openjdk/bin" $path)

# mise shims for processes that never source a shell rc (systemd units, GUI
# launchers). Interactive shells use `mise activate` in .zshrc instead, which
# always resolves the right version.
[[ -d $HOME/.local/share/mise/shims ]] && path+=("$HOME/.local/share/mise/shims")

export PATH
