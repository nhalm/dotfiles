local M = {}

local lsputils = require("config.lsp.utils")

function M.config(install_server)
  return {
    settings = {
      intelephense = {
        cmd = { "intelephense", "--stdio" },
        filetypes = { "php" },
        root_dir = root_pattern("composer.json", ".git"),
      }
    }
end

function M.setup(install_server)
  lsputils.setup_server("intelephense", M.config(install_server))
end

return M
