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

mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers" "$HOME/Videos/Recordings"

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

# sshd on a laptop is almost always an accident. This machine has no
# ~/.ssh/authorized_keys, so the only way in is the password prompt -- and
# OpenSSH ships PasswordAuthentication on by default. ufw drops inbound 22, so
# this is defence in depth rather than an open door, but the service should not
# be running at all unless it is wanted.
#
# Not disabled automatically: that is a judgement call about how the machine is
# used, and setup.sh should not silently turn off a service you rely on.
if systemctl is-enabled --quiet sshd.service 2>/dev/null; then
	if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
		cat <<-'WARN'

			  WARNING: sshd is enabled but ~/.ssh/authorized_keys is empty or missing.
			  Nothing can log in by key, so the only path is password auth.

			  If you do not need inbound SSH (you almost certainly do not on a laptop):
			      sudo systemctl disable --now sshd.service

			  If you do need it, add your public key to ~/.ssh/authorized_keys first,
			  then the drop-in this repo installs at
			  /etc/ssh/sshd_config.d/99-hardening.conf will turn password auth off.

		WARN
	fi
fi
