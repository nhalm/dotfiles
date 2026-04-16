return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300  -- Faster response
  end,
  opts = {
    preset = "modern",
    delay = 200,  -- Faster trigger
    expand = 1,   -- Expand sub-groups
    notify = false,
    
    -- Window styling
    win = {
      border = "rounded",
      padding = { 1, 2 },
      wo = {
        winblend = 10,  -- Slight transparency
      },
    },
    
    -- Layout configuration
    layout = {
      width = { min = 20 },
      spacing = 3,
    },
    
    -- Icons and styling
    icons = {
      breadcrumb = "»",
      separator = "➜",
      group = "+",
      ellipsis = "…",
      mappings = true,
      rules = {
        -- File operations
        { pattern = "find", icon = "󰈞", color = "cyan" },
        { pattern = "file", icon = "󰈙", color = "cyan" },
        { pattern = "grep", icon = "󰊄", color = "cyan" },
        { pattern = "buffer", icon = "󰛨", color = "blue" },
        
        -- Git operations  
        { pattern = "git", icon = "󰊢", color = "orange" },
        { pattern = "browse", icon = "󰖟", color = "orange" },
        { pattern = "log", icon = "󰦚", color = "orange" },
        
        -- Terminal
        { pattern = "terminal", icon = "󰆍", color = "green" },
        
        -- LSP
        { pattern = "lsp", icon = "󰒋", color = "yellow" },
        { pattern = "diagnostic", icon = "󰒡", color = "red" },
        { pattern = "reference", icon = "󰆽", color = "yellow" },
        { pattern = "definition", icon = "󰆧", color = "yellow" },
        
        -- Window management
        { pattern = "split", icon = "󰘞", color = "purple" },
        { pattern = "tab", icon = "󰓩", color = "purple" },
        { pattern = "window", icon = "󰖲", color = "purple" },
        { pattern = "resize", icon = "󰩨", color = "purple" },
        
        -- General
        { pattern = "toggle", icon = "󰔡", color = "magenta" },
        { pattern = "fold", icon = "󰘖", color = "magenta" },
        { pattern = "explorer", icon = "󰙅", color = "green" },
      },
    },
    
    -- Disable some noisy default mappings
    disable = {
      bt = {},
      ft = {},
    },
    
    -- Group configurations
    spec = {
      { "<leader>f", group = " Find", icon = "󰈞" },
      { "<leader>g", group = " Git", icon = "󰊢" },
      { "<leader>s", group = " Split/Window", icon = "󰘞" },
      { "<leader>t", group = " Terminal/Tab", icon = "󰆍" },
      { "<leader>c", group = " Code", icon = "󰒋" },
      { "<leader>w", group = " Workspace", icon = "󰖲" },
      { "<leader>r", group = " Rename/Resize", icon = "󰑕" },
      { "<leader>b", group = " Buffer", icon = "󰛨" },
      { "<leader>z", group = " Fold", icon = "󰘖" },
    },
  },
}
