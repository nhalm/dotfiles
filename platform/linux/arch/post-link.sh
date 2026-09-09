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

# Generate the palette now, so nothing renders with the hardcoded fallbacks
# before a wallpaper has ever been chosen.
if [ ! -s "${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper" ]; then
	echo "seeding a wallpaper and its palette..."
	"$HOME/.local/scripts/wallpaper.sh" --random || echo "  no wallpaper set; the picker will do it"
fi

# Writes the gtk settings.ini files, which carry the light/dark mode.
echo "applying the theme mode..."
"$HOME/.local/scripts/theme-mode.sh" --apply >/dev/null || echo "  theme mode not applied"

# hypridle reads hypridle.conf once, at startup. Re-linking the config leaves
# the running daemon on its old timeouts, silently, until the next login.
if pgrep -x hypridle >/dev/null 2>&1; then
	echo "restarting hypridle to pick up its config..."
	pkill -x hypridle
	setsid -f hypridle >/dev/null 2>&1
fi

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

echo "==> ssh access"
authorize_ssh_keys
echo

echo "==> system config"
install_system_files

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

if systemctl list-unit-files paccache.timer >/dev/null 2>&1; then
	if systemctl is-enabled --quiet paccache.timer 2>/dev/null; then
		echo "paccache.timer already enabled"
	else
		echo "enabling paccache.timer..."
		sudo systemctl enable --now paccache.timer
	fi
fi

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

if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
	cat <<-'WARN'

		  ACTION NEEDED: sshd accepts password authentication from any source.

		  No key could be authorised, so the ssh hardening drop-in was skipped --
		  installing it would have locked you out. Sign in to 1Password, enable
		  its ssh agent, and re-run ./setup.sh.

	WARN
fi
