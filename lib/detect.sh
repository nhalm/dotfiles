#!/usr/bin/env bash
# Platform detection. Sets, for the rest of the setup:
#
#   OS_FAMILY    darwin | linux          -- launchd vs systemd, /Applications vs /opt
#   DISTRO       macos | arch | debian…  -- which package manager speaks
#   DISTRO_LIKE  ID_LIKE from os-release -- lets derivatives reuse a parent's config
#   CPU_ARCH     uname -m
#
# The two axes are deliberately separate: most differences are one or the other,
# rarely both, so a new distro usually only needs a package list.

detect_platform() {
	CPU_ARCH="$(uname -m)"
	DISTRO_LIKE=""

	case "$(uname -s)" in
	Darwin)
		OS_FAMILY="darwin"
		DISTRO="macos"
		;;
	Linux)
		OS_FAMILY="linux"
		if [ -r /etc/os-release ]; then
			# shellcheck disable=SC1091
			DISTRO="$(. /etc/os-release && echo "${ID:-unknown}")"
			DISTRO_LIKE="$(. /etc/os-release && echo "${ID_LIKE:-}")"
		else
			DISTRO="unknown"
		fi
		;;
	*)
		echo "unsupported platform: $(uname -s)" >&2
		return 1
		;;
	esac

	export OS_FAMILY DISTRO DISTRO_LIKE CPU_ARCH
}

# Echo the platform dirs to consult, nearest-last, skipping any that don't exist.
# A derivative with no directory of its own falls back to what its ID_LIKE names,
# so e.g. EndeavourOS reuses platform/linux/arch without any new files.
platform_dirs() {
	local root="$1" d
	[ -d "$root/$OS_FAMILY" ] && echo "$root/$OS_FAMILY"
	[ "$OS_FAMILY" = "darwin" ] && return 0

	if [ -d "$root/$OS_FAMILY/$DISTRO" ]; then
		echo "$root/$OS_FAMILY/$DISTRO"
		return 0
	fi
	for d in $DISTRO_LIKE; do
		if [ -d "$root/$OS_FAMILY/$d" ]; then
			echo "$root/$OS_FAMILY/$d"
			return 0
		fi
	done
	return 0
}

# Stow packages to link, in order: shared config, then OS family, then distro.
# Only those that exist are returned.
stow_packages_for_platform() {
	local dotfiles="$1" p d
	for p in shared "$OS_FAMILY"; do
		[ -d "$dotfiles/$p" ] && echo "$p"
	done
	[ "$OS_FAMILY" = "darwin" ] && return 0

	if [ -d "$dotfiles/$DISTRO" ]; then
		echo "$DISTRO"
		return 0
	fi
	for d in $DISTRO_LIKE; do
		if [ -d "$dotfiles/$d" ]; then
			echo "$d"
			return 0
		fi
	done
	return 0
}
