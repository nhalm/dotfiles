#!/usr/bin/env bash
# Config that lives outside $HOME.
#
# stow links into $HOME, which does not work for /etc: those files are
# root-owned, and symlinking them at a user-writable path in this repo would
# mean anything able to write the repo can rewrite root's config. So these are
# *copied* into place with `sudo install`, and only when the content differs.
#
# Layout mirrors the destination, rooted per OS family:
#
#   system/linux/etc/sysctl.d/99-hardening.conf  ->  /etc/sysctl.d/99-hardening.conf
#
# Everything installs 0644 root:root, which is correct for every drop-in we
# ship (sysctl.d, sshd_config.d, modprobe.d, udev rules). If something ever
# needs a different mode, it does not belong in this mechanism.

# Some files are unsafe to install until a precondition holds. Returns non-zero
# to skip a file, having explained why.
#
# The sshd drop-in turns off password authentication. Installing it before any
# key is authorised would lock this account out of SSH entirely -- and on a
# machine reached over the network, that is not recoverable remotely.
_system_file_allowed() {
	case "$1" in
	/etc/ssh/sshd_config.d/*)
		if [ -s "$HOME/.ssh/authorized_keys" ]; then
			return 0
		fi
		cat >&2 <<-'MSG'
			  SKIPPING /etc/ssh/sshd_config.d/99-hardening.conf
			    It sets PasswordAuthentication no, and ~/.ssh/authorized_keys is
			    empty or missing -- installing it would lock you out of SSH.

			    Authorise a key first, then re-run ./setup.sh:
			      ssh-add -L > ~/.ssh/authorized_keys     # keys from the 1Password agent
			      chmod 600 ~/.ssh/authorized_keys
			    Verify you can log in with it from another machine BEFORE re-running.
		MSG
		return 1
		;;
	esac
	return 0
}

# Echo "src<TAB>dest" for every system file that applies to this platform.
_system_file_pairs() {
	local root="$DOTFILES/system/$OS_FAMILY" src dest
	[ -d "$root" ] || return 0
	# -name '*.md' is excluded: documentation lives alongside the tree it
	# describes, and must not be installed into /etc.
	while IFS= read -r src; do
		dest="${src#"$root"}"
		printf '%s\t%s\n' "$src" "$dest"
	done < <(find "$root" -type f ! -name '*.md' | sort)
}

# Show what install_system_files would change, without touching anything.
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

# Copy the system files into place. Idempotent: files that already match are
# left alone, so a re-run needs no sudo at all if nothing changed.
#
# Every file we ship is world-readable once installed, so the comparison needs
# no privileges -- only the write does.
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

	# Apply now rather than at next boot. A file installed but not loaded is
	# worse than one not installed: --diff-system reports it as done.
	if [ "$wrote_sysctl" = 1 ]; then
		echo "reloading sysctl..."
		sudo sysctl --system >/dev/null && echo "  sysctl reloaded"
	fi

	# Validate before reloading: a config sshd rejects would take the service
	# down, and this is a machine reached over ssh.
	if [ "$wrote_sshd" = 1 ] && systemctl is-active --quiet sshd 2>/dev/null; then
		if sudo sshd -t; then
			echo "reloading sshd..."
			sudo systemctl reload sshd && echo "  sshd reloaded (existing sessions keep running)"
		else
			echo "  sshd rejected the new config; NOT reloading" >&2
			echo "  the running daemon keeps its old settings until this is fixed" >&2
		fi
	fi

	# Not restarted automatically: it stops every running container, which is
	# not something a config sync should decide to do.
	if [ "$wrote_docker" = 1 ] && systemctl is-active --quiet docker 2>/dev/null; then
		echo "  docker config changed -- restart to apply, when convenient:"
		echo "      sudo systemctl restart docker"
	fi
}
