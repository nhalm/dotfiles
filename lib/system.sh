#!/usr/bin/env bash

_system_file_allowed() {
	case "$1" in
	/etc/ssh/sshd_config.d/*)
		if [ -s "$HOME/.ssh/authorized_keys" ]; then
			return 0
		fi
		echo "  skipping sshd_config.d: ~/.ssh/authorized_keys is empty" >&2
		return 1
		;;
	esac
	return 0
}

_system_file_pairs() {
	local root="$DOTFILES/system/$OS_FAMILY" src dest
	[ -d "$root" ] || return 0
	while IFS= read -r src; do
		dest="${src#"$root"}"
		printf '%s\t%s\n' "$src" "$dest"
	done < <(find "$root" -type f ! -name '*.md' | sort)
}

diff_system_files() {
	local src dest changed=0
	while IFS=$'\t' read -r src dest; do
		[ -n "$src" ] || continue
		if ! _system_file_allowed "$dest" 2>/dev/null; then
			echo "  - $dest (skipped -- precondition not met)"
		elif [ ! -e "$dest" ]; then
			echo "  + $dest (new)"
			changed=1
		elif ! cmp -s "$src" "$dest" 2>/dev/null; then
			echo "  ~ $dest (differs)"
			changed=1
		fi
	done < <(_system_file_pairs)
	[ "$changed" = 0 ] && echo "  system files already up to date"
	return 0
}

install_system_files() {
	local src dest srcs=() dests=() i

	while IFS=$'\t' read -r src dest; do
		[ -n "$src" ] || continue
		cmp -s "$src" "$dest" 2>/dev/null && continue
		_system_file_allowed "$dest" || continue
		srcs+=("$src")
		dests+=("$dest")
	done < <(_system_file_pairs)

	if [ ${#srcs[@]} -eq 0 ]; then
		echo "system files already up to date"
		return 0
	fi

	echo "these files under / will be written (may prompt for your password):"
	for i in "${!dests[@]}"; do
		echo "  ${dests[$i]}"
	done

	local wrote_sysctl=0 wrote_sshd=0 wrote_docker=0
	for i in "${!srcs[@]}"; do
		if sudo install -D -o root -g root -m 0644 "${srcs[$i]}" "${dests[$i]}"; then
			echo "  installed ${dests[$i]}"
			case "${dests[$i]}" in
			/etc/sysctl.d/*) wrote_sysctl=1 ;;
			/etc/ssh/sshd_config.d/*) wrote_sshd=1 ;;
			/etc/docker/*) wrote_docker=1 ;;
			esac
		else
			echo "  failed to install ${dests[$i]}" >&2
		fi
	done

	if [ "$wrote_sysctl" = 1 ]; then
		echo "reloading sysctl..."
		sudo sysctl --system >/dev/null && echo "  sysctl reloaded"
	fi

	if [ "$wrote_sshd" = 1 ] && systemctl is-active --quiet sshd 2>/dev/null; then
		if sudo sshd -t; then
			echo "reloading sshd..."
			sudo systemctl reload sshd && echo "  sshd reloaded (existing sessions keep running)"
		else
			echo "  sshd rejected the new config; NOT reloading" >&2
			echo "  the running daemon keeps its old settings until this is fixed" >&2
		fi
	fi

	if [ "$wrote_docker" = 1 ] && systemctl is-active --quiet docker 2>/dev/null; then
		echo "  docker config changed -- restart to apply, when convenient:"
		echo "      sudo systemctl restart docker"
	fi
}
