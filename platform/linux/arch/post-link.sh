# Arch steps that need the stowed configs, or that touch system services.
# Sourced by setup.sh after linking.

# Docker replaces the Colima VM used on macOS -- the daemon runs natively here.
if command -v docker >/dev/null 2>&1; then
	if ! systemctl is-enabled --quiet docker.service 2>/dev/null; then
		echo "enabling docker.service..."
		sudo systemctl enable --now docker.service
	else
		echo "docker.service already enabled"
	fi

	if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
		echo "already in the docker group"
	else
		echo "adding $USER to the docker group (takes effect at next login)..."
		sudo usermod -aG docker "$USER"
	fi
fi

# brightnessctl normally sets brightness through logind (it links libsystemd),
# which needs no special permissions for the active session -- so this group is
# only a fallback for a build without logind support, or a non-systemd setup.
# Harmless either way; video is standard for DRM access on a desktop.
if command -v brightnessctl >/dev/null 2>&1; then
	if id -nG "$USER" | tr ' ' '\n' | grep -qx video; then
		echo "already in the video group"
	else
		echo "adding $USER to the video group for backlight control (takes effect at next login)..."
		sudo usermod -aG video "$USER"
	fi
fi

# ly is the display manager; the templated unit is bound to tty2.
if command -v ly >/dev/null 2>&1; then
	if systemctl is-enabled --quiet ly@tty2.service 2>/dev/null; then
		echo "ly@tty2.service already enabled"
	else
		echo "enabling ly@tty2.service..."
		sudo systemctl enable ly@tty2.service
	fi
fi

# bluez ships bluetooth.service disabled; blueman needs it running to see the
# adapter at all.
if command -v bluetoothctl >/dev/null 2>&1; then
	if systemctl is-enabled --quiet bluetooth.service 2>/dev/null; then
		echo "bluetooth.service already enabled"
	else
		echo "enabling bluetooth.service..."
		sudo systemctl enable --now bluetooth.service
	fi
fi

mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Recordings"

install_wallpapers

# blueman-applet runs for its pairing agent, not its tray icon: without an
# agent, BlueZ has nothing to answer pairing confirmations and bonding fails
# with AuthenticationFailed. Network and bluetooth status live in the sidebar.
if command -v blueman-applet >/dev/null 2>&1; then
	current="$(gsettings get org.blueman.general plugin-list 2>/dev/null)"
	if [ "$current" = "['!StatusNotifierItem']" ]; then
		echo "blueman tray icon already disabled"
	else
		echo "disabling the blueman tray icon..."
		gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"
	fi
fi

# ------------------------------------------------------------ hardening ----

# Kernel sysctls and other root-owned config. Copied rather than symlinked --
# see lib/system.sh for why.
echo "==> system config"
install_system_files

# Default-deny inbound. Nothing on a laptop should be reachable from the
# network; anything that genuinely needs to be gets an explicit `ufw allow`.
if command -v ufw >/dev/null 2>&1; then
	if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
		echo "ufw already active"
	else
		echo "enabling ufw (default deny inbound, allow outbound)..."
		sudo ufw --force default deny incoming
		sudo ufw --force default allow outgoing
		sudo ufw --force enable
	fi
	sudo systemctl enable --now ufw.service >/dev/null 2>&1 || true
fi

# Weekly prune of the package cache, keeping the last 3 versions. Not security
# in itself -- but a full /var stops upgrades, and an unupgradable machine is
# an unpatched one. paccache ships with pacman-contrib, already installed.
if systemctl list-unit-files paccache.timer >/dev/null 2>&1; then
	if systemctl is-enabled --quiet paccache.timer 2>/dev/null; then
		echo "paccache.timer already enabled"
	else
		echo "enabling paccache.timer..."
		sudo systemctl enable --now paccache.timer
	fi
fi

# Inbound SSH is wanted on this machine, so 22 stays open -- but rate-limited
# rather than wide open. ufw's `limit` drops a source IP that opens more than
# 6 connections in 30s, which makes password/key brute-forcing impractical
# without affecting a human logging in.
#
# To go further and restrict SSH to the local network:
#   sudo ufw delete limit 22/tcp
#   sudo ufw allow from 192.168.0.0/16 to any port 22 proto tcp
if command -v ufw >/dev/null 2>&1; then
	if sudo ufw status | grep -q '^22.*LIMIT'; then
		echo "ssh already rate-limited"
	elif sudo ufw status | grep -q '^22.*ALLOW'; then
		echo "replacing the open ssh rule with a rate-limited one..."
		sudo ufw delete allow 22 >/dev/null 2>&1 || true
		sudo ufw delete allow 22/tcp >/dev/null 2>&1 || true
		sudo ufw limit 22/tcp
	else
		echo "adding a rate-limited ssh rule..."
		sudo ufw limit 22/tcp
	fi
fi

# The sshd hardening drop-in disables password authentication, and
# install_system_files refuses to install it until a key is authorised (see
# _system_file_allowed in lib/system.sh). Say so here too, because a machine
# that accepts passwords from the whole network is the single biggest exposure
# on this host until it is fixed.
if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
	cat <<-'WARN'

		  ACTION NEEDED: sshd accepts password authentication from any source.

		  ~/.ssh/authorized_keys is empty, so the ssh hardening drop-in was
		  skipped -- installing it would have locked you out.

		  Fix, in this order:
		    1. ssh-add -L > ~/.ssh/authorized_keys
		       chmod 600 ~/.ssh/authorized_keys
		    2. Verify key login works from another machine, in a session you
		       keep open.
		    3. Re-run ./setup.sh -- the drop-in installs and passwords stop
		       being accepted.

	WARN
fi
