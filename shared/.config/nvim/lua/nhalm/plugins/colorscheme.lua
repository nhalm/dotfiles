-- tokyonight, with its backgrounds and accents taken from the matugen palette
-- when one has been rendered. :MatugenReload re-reads it; wallpaper.sh calls
-- that over nvim's socket after every render.
local PALETTE = vim.fs.joinpath(
  vim.env.XDG_STATE_HOME or vim.fs.joinpath(vim.env.HOME, ".local", "state"),
  "matugen",
  "nvim-colors.lua"
)

local function palette()
  local ok, p = pcall(dofile, PALETTE)
  if ok and type(p) == "table" and p.bg then
    return p
  end
end

local function apply()
  local p = palette()

  require("tokyonight").setup {
    style = "storm",
    -- The cache would serve the previous wallpaper's colours.
    cache = false,
    -- Painting a background here would sit opaque on top of Ghostty's, which
    -- is the same colour at background-opacity. Letting it through keeps one
    -- surface behind the terminal and the editor.
    transparent = true,
    styles = {
      sidebars = "transparent",
      floats = "transparent",
    },
    on_colors = function(c)
      if not p then
        return
      end
      c.bg = p.bg
      c.bg_dark = p.bg_dark
      c.bg_float = p.bg_float
      c.bg_popup = p.bg_float
      c.bg_sidebar = p.bg_dark
      c.bg_statusline = p.bg_dark
      c.bg_visual = p.bg_visual
      c.fg_gutter = p.fg_gutter
      c.border = p.border
      c.border_highlight = p.primary
    end,
    on_highlights = function(hl, _)
      if not p then
        return
      end
      hl.CursorLineNr = { fg = p.primary, bold = true }
      hl.FloatBorder = { fg = p.border, bg = "NONE" }
      hl.WinSeparator = { fg = p.border }
      hl.PmenuSel = { bg = p.bg_visual, fg = p.on_primary }
      hl.TabLineSel = { bg = p.primary, fg = p.on_primary }
    end,
  }

  vim.cmd.colorscheme "tokyonight-storm"
end

return {
  "folke/tokyonight.nvim",
  priority = 1000,
  config = function()
    apply()
    vim.api.nvim_create_user_command("MatugenReload", apply, {
      desc = "Re-read the matugen palette and re-apply the colorscheme",
    })
  end,
}
