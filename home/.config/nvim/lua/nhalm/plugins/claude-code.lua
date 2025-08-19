return {
  "coder/claudecode.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("claudecode").setup({
      command = "claude",
      terminal = {
        auto_close = false,
        provider = "snacks",
        snacks_win_opts = {
          position = "float",
          width = 0.8,
          height = 0.8,
          border = "rounded",
        },
      },
      diff = {
        auto_close_on_accept = false,
        open_in_current_tab = true,
        enabled = false,
      },
    })
  end,
}
