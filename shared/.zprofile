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
# launchd's agent, loaded from Keychain (setup stores the passphrase there).
if [[ -n $XDG_RUNTIME_DIR && -S $XDG_RUNTIME_DIR/gcr/ssh ]]; then
	export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
elif [[ $OSTYPE == darwin* ]]; then
	ssh-add -l >/dev/null 2>&1 || /usr/bin/ssh-add --apple-load-keychain -q 2>/dev/null
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
