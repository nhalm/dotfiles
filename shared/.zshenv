# Every zsh, login or not, interactive or not: PATH only. .zprofile sources it
# again after macOS's /etc/zprofile, whose path_helper puts system paths first.

typeset -U path PATH fpath FPATH

# Homebrew, where it exists. shellenv once per environment (it also grows
# INFOPATH), the prefix moved to the front on every pass.
if [[ -x /opt/homebrew/bin/brew ]]; then
	[[ -n $HOMEBREW_PREFIX ]] || eval "$(/opt/homebrew/bin/brew shellenv)"
	path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
fi

export GOPATH="$HOME/go"

path=(
	"$HOME/.local/bin"
	"$GOPATH/bin"
	$path
)

# openjdk is keg-only: brew will not symlink it, because macOS ships its own
# java wrappers. Guarded on the directory, so it is a no-op elsewhere.
[[ -d /opt/homebrew/opt/openjdk/bin ]] && path=("/opt/homebrew/opt/openjdk/bin" $path)

# mise shims first, for every zsh (mise docs: shims, then `mise activate` in
# .zshrc for interactive shells). Dropped before the eval, which prints nothing
# when the directory is already on PATH, so each pass moves them to the front.
path=(${path:#$HOME/.local/share/mise/shims})
(( $+commands[mise] )) && eval "$(mise activate zsh --shims)"

export PATH
