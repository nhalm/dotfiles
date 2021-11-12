local M = {}

local lsputils = require("config.lsp.utils")

function M.config(install_server)
  return {
    -- https://github.com/golang/tools/blob/master/gopls/doc/settings.md
    experimentalPostfixCompletions = true,
    analyses = { unusedparams = true, unreachable = true, httpresponse = true, nilness = true, shadow = true,  },
    codelenses = { generate = true, gc_details = true, test = true, tidy = true },
    usePlaceholders = true,
    completeUnimported = true,
    staticcheck = true,
    matcher = "fuzzy",
    -- experimentalDiagnosticsDelay = "500ms",
    symbolMatcher = "fuzzy",
    gofumpt = true,
    buildFlags = { "-tags", "integration" },
    cmd = install_server._default_options.cmd,
  }
end


function goimports(timeout_ms)
    local context = { only = { "source.organizeImports" } }
    vim.validate { context = { context, "t", true } }

    local params = vim.lsp.util.make_range_params()
    params.context = context

    -- See the implementation of the textDocument/codeAction callback
    -- (lua/vim/lsp/handler.lua) for how to do this properly.
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, timeout_ms)
    if not result or next(result) == nil then return end
    local actions = result[1].result
    if not actions then return end
    local action = actions[1]

    -- textDocument/codeAction can return either Command[] or CodeAction[]. If it
    -- is a CodeAction, it can have either an edit, a command or both. Edits
    -- should be executed first.
    if action.edit or type(action.command) == "table" then
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit)
      end
      if type(action.command) == "table" then
        vim.lsp.buf.execute_command(action.command)
      end
    else
      vim.lsp.buf.execute_command(action)
    end
end

function M.config_go() 
  config = {
    goimport = 'gopls', -- if set to 'gopls' will use golsp format
    gofmt = 'gopls', -- if set to gopls will use golsp format
    max_line_len = 120,
    tag_transform = false,
    comment_placeholder = '   ',
    lsp_cfg = true, -- false: use your own lspconfig
    lsp_gofumpt = false, -- true: set default gofmt in gopls format to gofumpt
    lsp_on_attach = true, -- use on_attach from go.nvim
    -- dap_debug = true,
  }

  vim.api.nvim_exec([[ autocmd BufWritePre *.go lua goimports(1000) ]], false)
--   require('go').setup(config)

  -- local protocol = require('vim.lsp.protocol')

  -- vim.cmd("autocmd BufWritePre *.go :silent! lua require('go.format').gofmt()")


  -- Format on save
  -- vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').gofmt() ]], false)

  -- Import on save
  -- vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').goimport() ]], false)
end

function M.setup(install_server)
  lsputils.setup_server("gopls", M.config(install_server))
  M.config_go()
end

return M
