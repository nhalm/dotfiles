local M = {}

function M.setup()
    local cmd = vim.cmd
    local g = vim.g

    cmd [[
        if (has('termguicolors'))
            set termguicolors
        endif
    ]]

    g.material_terminal_italics = 1
    g.material_theme_style = ' palenight'
    cmd 'colorscheme material'

end

return M
