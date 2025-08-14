return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    -- Enable the modules we want to use
    dashboard = { enabled = true },
    zen = { enabled = true },
    picker = { enabled = true },
    explorer = { enabled = true },
    terminal = { enabled = true },
    notifier = { enabled = true },
    git = { enabled = true },
    scroll = { enabled = true },
    words = { enabled = true },
    dim = { enabled = true },
    bigfile = { enabled = true },
  },
  keys = {
    -- Dashboard
    { "<leader>bd", function() Snacks.dashboard() end, desc = "Dashboard" },
    
    -- Zen mode
    { "<leader>z", function() Snacks.zen() end, desc = "Toggle Zen Mode" },
    
    -- File explorer
    { "<leader>e", function() Snacks.explorer() end, desc = "Explorer" },
    
    -- Picker (telescope replacement)
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    { "<leader>fg", function() Snacks.picker.grep() end, desc = "Live Grep" },
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Find Buffers" },
    { "<leader>fh", function() Snacks.picker.help() end, desc = "Help Pages" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent Files" },
    { "<leader>fc", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
    { "<leader>fk", function() Snacks.picker.keymaps() end, desc = "Find Keymaps" },
    
    -- Git
    { "<leader>gb", function() Snacks.git.browse() end, desc = "Git Browse" },
    { "<leader>gl", function() Snacks.git.log() end, desc = "Git Log" },
    
    -- Terminal (replace our basic terminal keymaps)
    { "<leader>tt", function() Snacks.terminal() end, desc = "Terminal" },
    { "<leader>th", function() Snacks.terminal.split() end, desc = "Terminal Split" },
    { "<leader>tv", function() Snacks.terminal.vsplit() end, desc = "Terminal Vsplit" },
  },
}