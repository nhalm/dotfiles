
local M = {}

local lsputils = require "config.lsp.utils"

-- DATA_PATH = vim.fn.stdpath "data"

function M.config(installed_server)
    print(vim.inspect(installed_server.name))
    print(vim.inspect(installed_server._default_options.cmd))

    config = {
        library = { vimruntime = true, types = true, plugins = true },
        lspconfig = {
            capabilities = lsputils.get_capabilities(),
            on_attach = lsputils.lsp_attach,
            on_init = lsputils.lsp_init,
            on_exit = lsputils.lsp_exit,
            cmd = installed_server._default_options.cmd,
            settings = {
                Lua = {
                    runtime = {
                        version = "LuaJIT",
                        path = vim.split(package.path, ";"),
                    },
                    diagnostics = { globals = { "vim" } },
                    workspace = {
                        library = {
                            [vim.fn.expand "$VIMRUNTIME/lua"] = true,
                            [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"] = true,
                        },
                        maxPreload = 100000,
                        preloadFileSize = 1000,
                    },
                },
            },
        },
    }

    return config
end

function M.setup(installed_server)
    local config = M.config(installed_server)
    local luadev = require("lua-dev").setup(config)
    local lspconfig = require "lspconfig"
--    print(vim.inspect(luadev))
    lspconfig.sumneko_lua.setup(luadev)
end

return M
