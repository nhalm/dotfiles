# macOS-specific interactive setup, sourced by .zshrc before compinit.

# Must land on fpath before .zshrc's compinit, which is why the OS fragment
# is sourced above it.
if (( $+commands[brew] )); then
	fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
fi

# BSD ls takes -G for colour; GNU's --color=auto is a parse error here.
alias ls='ls -G'
alias ll='ls -lahG'

# mmdc (Mermaid in nvim) has no bundled headless Chrome.
export PUPPETEER_EXECUTABLE_PATH="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
