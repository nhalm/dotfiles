local M = {}

local lsp_providers = {
--    bashls = true,
 --   gopls = true,
 --   sumneko_lua = true,
   -- yamlls = true,
}

local function setup_servers()
    print("aaa")
    local lsp_installer = require("nvim-lsp-installer")

    require("config.lsp.null-ls").setup()

    -- lsp_installer.on_server_ready(function(server)
-- --        if server.name == "sumneko_lua" then
    --         require("config.lsp." .. server.name).setup(server)
-- --        end
    -- end)
   lsp_installer.on_server_ready(function(server)
       print(server.name)
       if lsp_providers[server.name] then
           require("config.lsp." .. server.name).setup(server)
       else
           local opts = {}
           server:setup(opts)
       end
   end)
--    local servers = {'pyright', 'gopls'}
--    for _, lsp in ipairs(servers) do
--        nvim_lsp[lsp].setup {
--            on_attach = on_attach
--        }
--    end
end

function M.setup()
    setup_servers()
end

return M
