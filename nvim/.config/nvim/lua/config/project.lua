local M = {}

function M.setup()
  require("project_nvim").setup {}

  vim.g.respect_buf_cwd = 1

  require("nvim-tree").setup {
    update_cwd = true,
    update_focused_file = {
      enable = true,
      update_cwd = true,
    },
  }

  require("telescope").load_extension "projects"
end

return M
