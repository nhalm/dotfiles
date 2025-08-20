local opt = vim.opt -- for conciseness

-- line numbers
opt.relativenumber = true -- show relative line numbers
opt.number = true -- shows absolute line number on cursor line (when relative number is on)

-- tabs & indentation
opt.tabstop = 2 -- 2 spaces for tabs (prettier default)
opt.shiftwidth = 2 -- 2 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one

-- line wrapping
opt.wrap = false -- disable line wrapping

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

-- cursor line
opt.cursorline = true -- highlight the current cursor line

-- appearance

-- turn on termguicolors for nightfly colorscheme to work
-- (have to use iterm2 or any other true color terminal)
opt.termguicolors = true
opt.background = "dark" -- colorschemes that can be light or dark will be made dark
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- backspace
opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- clipboard
opt.clipboard:append "unnamedplus" -- use system clipboard as default register

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

-- turn off swapfile
opt.swapfile = false

-- turn on backup copy for inotify
-- opt.backupcopy = "yes"

-- session options for auto-session
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Disable providers we don't use
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Set Python host program (will be configured by setup script)
local pyenv_root = vim.fn.expand("~/.pyenv")
local neovim_python = pyenv_root .. "/versions/neovim/bin/python"
if vim.fn.filereadable(neovim_python) == 1 then
  vim.g.python3_host_prog = neovim_python
end

vim.filetype.add({
  extension = {
    mdx = "markdown"
  },
  filename = {
    [".luacheckrc"] = "conf"
  }
})
