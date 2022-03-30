local M = {}

local lsputils = require("config.lsp.utils")

function M.config(install_server)
  return {
    settings = {
      phpactor = {
        cmd = { "phpactor", "language-server" },
        filetypes = { "php" },
        root_dir = root_pattern("composer.json", ".git"),
      }
    }
end

function M.setup(install_server)
  print(vim.inspect(install_server))
  lsputils.setup_server("phpactor", M.config(install_server))
end

return M
