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

# 1Password SSH agent. Here rather than in an interactive rc because git run
# from a script, a launchd job or a GUI-launched editor needs the agent too;
# with it in .zshrc those all fall back to the system agent, which holds no
# keys. The socket path differs per OS, so take whichever exists.
for _sock in \
	"$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" \
	"$HOME/.1password/agent.sock"; do
	if [[ -S $_sock ]]; then
		export SSH_AUTH_SOCK="$_sock"
		break
	fi
done
unset _sock

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
