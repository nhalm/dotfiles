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

# brightnessctl ships a udev rule that chgrps /sys/class/backlight/*/brightness
# to the video group; without membership the XF86MonBrightness keys silently
# fail on a root-owned, 644 file.
if command -v brightnessctl >/dev/null 2>&1; then
	if id -nG "$USER" | tr ' ' '\n' | grep -qx video; then
		echo "already in the video group"
	else
		echo "adding $USER to the video group for backlight control (takes effect at next login)..."
		sudo usermod -aG video "$USER"
	fi
fi
