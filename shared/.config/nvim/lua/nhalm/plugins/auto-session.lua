return {
  "rmagatti/auto-session",
  config = function()
    local auto_session = require("auto-session")

    auto_session.setup({
      auto_restore = false, -- Updated config name
      suppressed_dirs = { "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/" }, -- Updated config name
    })

    -- Fix sessionoptions to include localoptions for proper filetype/highlighting restoration
    vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

    local keymap = vim.keymap

    keymap.set("n", "<leader>wr", "<cmd>SessionRestore<CR>", { desc = "Restore session for cwd" }) -- restore last workspace session for current directory
    keymap.set("n", "<leader>ws", "<cmd>SessionSave<CR>", { desc = "Save session for auto session root dir" }) -- save workspace session for current working directory
  end,
}
