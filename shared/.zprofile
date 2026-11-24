# Login shells. Environment only -- interactive setup lives in .zshrc, PATH in
# .zshenv.

# Restores .zshenv's PATH order after /etc/zprofile (path_helper on macOS).
source "${ZDOTDIR:-$HOME}/.zshenv"

export EDITOR=nvim
export VISUAL=nvim

# Consumed by the sketchybar git widget on macOS; kept here so scripts shared
# between machines can rely on it.
export PROJECTS_DIR="$HOME/work:$HOME/personal:$HOME/dev"

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

