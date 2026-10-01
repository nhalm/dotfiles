#!/bin/sh
# Prints "lat,lon|City, ST". CoreLocation sometimes cannot get a fix; the last
# good one is kept so weather does not fall back to IP geolocation.
state="${XDG_STATE_HOME:-$HOME/.local/state}/barpop/location"
PATH="/opt/homebrew/bin:$PATH"

fix="$(CoreLocationCLI --format "%latitude,%longitude|%locality, %administrativeArea" 2>/dev/null | tr -d '\n')"
case "$fix" in
[0-9-]*,[0-9-]*"|"*)
	mkdir -p "$(dirname "$state")"
	printf '%s\n' "$fix" >"$state"
	printf '%s\n' "$fix"
	;;
*) cat "$state" 2>/dev/null ;;
esac
