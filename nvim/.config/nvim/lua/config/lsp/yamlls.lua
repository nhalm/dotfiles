local M = {}

local lsputils = require("config.lsp.utils")

function M.config(install_server)
  return {
    -- filetypes = { "yaml", "yaml.docker-compose" },
    -- on_attach = on_attach,
    settings = {
      schemaStore = {
        url = "https://www.schemastore.org/api/json/catalog.json",
        enable = true,
      },
      --schemaDownload = {
      --  enable = true,
      --},
    }
  }
end

function M.setup(install_server)
   -- lsputils.setup_server("yamlls", M.config(install_server))
    --- local config = M.config(installed_server)
    -- local yamlls = require("yamlls").setup(config)
    --local yamlls = require("yamlls").setup()
    local lspconfig = require "lspconfig"

    lspconfig.yamlls.setup(M.config(install_server))
end

return M
