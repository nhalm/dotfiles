local M = {}

function M.setup()
    local cmp = require("cmp")

    local formattingFunc = function(entry, vim_item)
        -- fancy icons and a name of kind
        vim_item.kind = require("lspkind").presets.default[vim_item.kind] .. " " .. vim_item.kind
        -- set a name for each source
        vim_item.menu = ({
            buffer = "[Buffer]",
            nvim_lsp = "[LSP]",
            -- ultisnips = "[UltiSnips]",
            nvim_lua = "[Lua]",
            cmp_tabnine = "[TabNine]",
            look = "[Look]",
            path = "[Path]",
            spell = "[Spell]",
            calc = "[Calc]",
            emoji = "[Emoji]",
            treesitter = "[treesitter]",
        })[entry.source.name]

        return vim_item
    end

    local mappings =  {
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-k>"] = cmp.mapping.select_prev_item(),
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-j>"] = cmp.mapping.select_next_item(),
        ["<C-d>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-e>"] = cmp.mapping.close(),
        ["<CR>"] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Insert,
            select = true,
        },
        ["<C-Space>"] = cmp.mapping(
            function(fallback)
                if cmp.visible() then
                    if vim.fn["UltiSnips#CanExpandSnippet"]() == 1 then
                        return press "<C-R>=UltiSnips#ExpandSnippet()<CR>"
                    end

                    cmp.select_next_item()
                elseif has_any_words_before() then
                    press "<Space>"
                else
                    fallback()
                end
            end, {
            "i",
            "s",
        }),
--        ["<Tab>"] = cmp.mapping(
--            function(fallback)
--                if vim.fn.complete_info()["selected"] == -1 and vim.fn["UltiSnips#CanExpandSnippet"]() == 1 then
--                    press "<C-R>=UltiSnips#ExpandSnippet()<CR>"
--                elseif vim.fn["UltiSnips#CanJumpForwards"]() == 1 then
--                    press "<ESC>:call UltiSnips#JumpForwards()<CR>"
--                elseif cmp.visible() then
--                    cmp.select_next_item()
--                elseif has_any_words_before() then
--                    press "<Tab>"
--                else
--                    fallback()
--                end
--            end, {
--            "i",
--            "s",
--        }),
        ["<S-Tab>"] = cmp.mapping(
            function(fallback)
                if vim.fn["UltiSnips#CanJumpBackwards"]() == 1 then
                    press "<ESC>:call UltiSnips#JumpBackwards()<CR>"
                elseif cmp.visible() then
                    cmp.select_prev_item()
                else
                    fallback()
                end
            end, {
            "i",
            "s",
        }),
        }

    local snippets = {
        expand = function(args)
            vim.fn["UltiSnips#Anon"](args.body)
        end,
    }

    local sources =  {
        { name = "buffer" },
        { name = "nvim_lsp" },
        -- { name = "ultisnips" },
        { name = "nvim_lua" },
        { name = "path" },
        { name = "emoji" },
        { name = "treesitter" },
        -- { name = "neorg" },
        { name = "crates" },
        -- { name = "look" },
        -- { name = "calc" },
        -- { name = "spell" },
        -- {name = 'cmp_tabnine'}
    }


    local config = {
    formatting = {
        format = formattingFunc
    },
    mapping = mappings,
    snippet = snippets,
    sources = sources,
    completion = { completeopt = "menu,menuone,noinsert" },
    }

    cmp.setup(config)
end

return M
