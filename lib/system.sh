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
		if [ ! -e "$dest" ]; then
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

	local wrote_sysctl=0
	for i in "${!srcs[@]}"; do
		if sudo install -D -o root -g root -m 0644 "${srcs[$i]}" "${dests[$i]}"; then
			echo "  installed ${dests[$i]}"
			case "${dests[$i]}" in
			/etc/sysctl.d/*) wrote_sysctl=1 ;;
			esac
		else
			echo "  failed to install ${dests[$i]}" >&2
		fi
	done

	# Apply now rather than only at next boot.
	if [ "$wrote_sysctl" = 1 ]; then
		echo "reloading sysctl..."
		sudo sysctl --system >/dev/null && echo "  sysctl reloaded"
	fi
}
