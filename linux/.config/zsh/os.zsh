# Linux-specific interactive setup, sourced by .zshrc.

# GNU coreutils colour flags; BSD ls on macOS uses -G instead.
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias diff='diff --color=auto'

# Wayland clipboard, so `pbcopy`-style muscle memory keeps working.
if (( $+commands[wl-copy] )); then
	alias pbcopy='wl-copy'
	alias pbpaste='wl-paste'
fi

# mmdc (Mermaid in nvim) has no bundled headless Chrome.
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
