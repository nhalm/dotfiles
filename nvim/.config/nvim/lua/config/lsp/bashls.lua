local M = {}

local lsputils = require("config.lsp.utils")

function M.config(install_server)
  return {
    cmd = install_server._default_options.cmd,
    cmd_env = {
      GLOB_PATTERN = "*@(.sh|.inc|.bash|.command)"
    },
    filetypes = { "sh" },
  }
end

function M.setup(install_server)
  lsputils.setup_server("bashls", M.config(install_server))
end

return M
