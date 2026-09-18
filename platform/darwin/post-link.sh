# macOS steps that need the stowed configs in place.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- wallpapers ---------------------------------------------------------
# Cloned over https by git_public, so this needs no key.
install_wallpapers

# --- docker compose plugin ----------------------------------------------
if have docker-compose; then
	mkdir -p "$HOME/.docker/cli-plugins"
	ln -sfn "$(brew --prefix)/bin/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
	echo "docker compose plugin configured"
fi

# --- config checks ------------------------------------------------------
# Validate what stow just linked, so a syntax error surfaces here rather than
# the next time the app starts.

# luac comes from the mise-managed lua, whose shims are not on PATH during setup.
if command -v mise >/dev/null 2>&1 && mise which luac >/dev/null 2>&1; then
	lua_bad=0
	while IFS= read -r f; do
		mise exec -- luac -p "$f" || lua_bad=1
	done < <(find "$HOME/.config/sketchybar" -name '*.lua' 2>/dev/null)
	if [ "$lua_bad" -eq 0 ]; then
		echo "sketchybar lua ok"
	else
		echo "  sketchybar will not start until the errors above are fixed"
	fi
	unset lua_bad
fi

# aerospace answers only while the app is running. It is installed by gui.sh and
# starts at login, so on a first install there is nothing to ask yet.
if have aerospace; then
	if ! aerospace list-workspaces --all >/dev/null 2>&1; then
		echo "aerospace not running, skipping config check"
	elif aerospace reload-config >/dev/null 2>&1; then
		echo "aerospace config ok"
	else
		echo "aerospace config REJECTED:"
		aerospace reload-config 2>&1 | sed 's/^/  /'
	fi
fi

brew cleanup || true
