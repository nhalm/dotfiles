return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    -- Enable the modules we want to use
    dashboard = { enabled = true },
    zen = { enabled = false },
    image = {
      enabled = true,
      doc = {
        inline = false,
        float = true,
        max_width = 120,
        max_height = 60,
      },
    },
    lazygit = { enabled = false },
    picker = {
      enabled = true,
      hidden = true,
      ui_select = true,
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          tree = true,
          follow_file = true,
          win = {
            list = {
              keys = {
                ["t"] = "tab",
              },
            },
          },
        },
      },
    },
    explorer = {
      enabled = true,
      replace_netrw = true,
    },
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
    {
      "<leader>bd",
      function()
        Snacks.dashboard()
      end,
      desc = "Dashboard",
    },

    -- File explorer
    {
      "<leader>e",
      function()
        Snacks.explorer()
      end,
      desc = "Explorer",
    },

    -- Picker (telescope replacement)
    {
      "<leader>ff",
      function()
        Snacks.picker.files()
      end,
      desc = "Find Files",
    },
    {
      "<leader>fg",
      function()
        Snacks.picker.grep()
      end,
      desc = "Live Grep",
    },
    {
      "<leader>fb",
      function()
        Snacks.picker.buffers()
      end,
      desc = "Find Buffers",
    },
    {
      "<leader>fh",
      function()
        Snacks.picker.help()
      end,
      desc = "Help Pages",
    },
    {
      "<leader>fr",
      function()
        Snacks.picker.recent()
      end,
      desc = "Recent Files",
    },
    {
      "<leader>fc",
      function()
        Snacks.picker.colorschemes()
      end,
      desc = "Colorschemes",
    },
    {
      "<leader>fk",
      function()
        Snacks.picker.keymaps()
      end,
      desc = "Find Keymaps",
    },

    -- Git
    {
      "<leader>gb",
      function()
        Snacks.git.browse()
      end,
      desc = "Git Browse",
    },
    {
      "<leader>gl",
      function()
        Snacks.git.log()
      end,
      desc = "Git Log",
    },

    -- Terminal (replace our basic terminal keymaps)
    {
      "<leader>tt",
      function()
        Snacks.terminal()
      end,
      desc = "Terminal",
      mode = { "n", "t" },
    },
    {
      "<leader>th",
      function()
        Snacks.terminal.split()
      end,
      desc = "Terminal Split",
    },
    {
      "<leader>tv",
      function()
        Snacks.terminal.vsplit()
      end,
      desc = "Terminal Vsplit",
    },
  },
}
