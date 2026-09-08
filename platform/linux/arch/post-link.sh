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
