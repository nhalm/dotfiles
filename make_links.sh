#!/usr/bin/env bash
# Re-link the stow packages for this platform without touching packages.
# Thin wrapper; the logic lives in lib/common.sh.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup.sh" --link-only
