-- Ctrl+hjkl walks nvim splits and crosses into herdr panes at the edge;
-- Alt+hjkl resizes whichever is focused. Both halves need the matching
-- plugin_action bindings in ~/.config/herdr/config.toml.
--
-- Only loads inside herdr. Outside it, core/keymaps.lua keeps the same keys
-- on plain window moves.
return {
  "lmilojevicc/herdr-splits.nvim",
  cond = vim.env.HERDR_ENV == "1",
  event = "VeryLazy",
  opts = {
    at_edge = "wrap",
    nav_at_edge = "wrap",
    unzoom_on_nav = true,
    ignored_buftypes = { "nofile", "quickfix", "prompt", "help", "terminal" },
    ignored_filetypes = {
      "NvimTree",
      "neo-tree",
      "snacks_dashboard",
      "snacks_explorer",
      "snacks_picker",
      "aerial",
      "Outline",
      "Trouble",
      "quickfix",
    },
  },
  keys = {
    { "<C-h>", function() require("herdr-splits").move_cursor_left() end, desc = "Navigate left" },
    { "<C-j>", function() require("herdr-splits").move_cursor_down() end, desc = "Navigate down" },
    { "<C-k>", function() require("herdr-splits").move_cursor_up() end, desc = "Navigate up" },
    { "<C-l>", function() require("herdr-splits").move_cursor_right() end, desc = "Navigate right" },
    { "<M-h>", function() require("herdr-splits").resize_left() end, desc = "Resize left" },
    { "<M-j>", function() require("herdr-splits").resize_down() end, desc = "Resize down" },
    { "<M-k>", function() require("herdr-splits").resize_up() end, desc = "Resize up" },
    { "<M-l>", function() require("herdr-splits").resize_right() end, desc = "Resize right" },
  },
}
