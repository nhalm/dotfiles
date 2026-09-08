return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
      "windwp/nvim-ts-autotag",
    },
    config = function()
      require("nvim-treesitter").setup()

      -- Install parsers (no-op if already installed)
      require("nvim-treesitter").install({
        "json",
        "javascript",
        "typescript",
        "tsx",
        "yaml",
        "html",
        "css",
        "prisma",
        "markdown",
        "markdown_inline",
        "svelte",
        "graphql",
        "bash",
        "lua",
        "vim",
        "dockerfile",
        "gitignore",
        "query",
        "regex",
        "latex",
        "scss",
        "typst",
        "vue",
        "elixir",
        "heex",
        "eex",
      })

      -- Textobjects setup
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      local ts_select = require("nvim-treesitter-textobjects.select")
      local ts_move = require("nvim-treesitter-textobjects.move")
      local ts_swap = require("nvim-treesitter-textobjects.swap")
      local ts_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")

      -- Select keymaps
      local select_maps = {
        { "a=", "@assignment.outer", "Select outer part of an assignment" },
        { "i=", "@assignment.inner", "Select inner part of an assignment" },
        { "l=", "@assignment.lhs", "Select left hand side of an assignment" },
        { "r=", "@assignment.rhs", "Select right hand side of an assignment" },
        { "a:", "@property.outer", "Select outer part of an object property" },
        { "i:", "@property.inner", "Select inner part of an object property" },
        { "l:", "@property.lhs", "Select left part of an object property" },
        { "r:", "@property.rhs", "Select right part of an object property" },
        { "aa", "@parameter.outer", "Select outer part of a parameter/argument" },
        { "ia", "@parameter.inner", "Select inner part of a parameter/argument" },
        { "ai", "@conditional.outer", "Select outer part of a conditional" },
        { "ii", "@conditional.inner", "Select inner part of a conditional" },
        { "al", "@loop.outer", "Select outer part of a loop" },
        { "il", "@loop.inner", "Select inner part of a loop" },
        { "af", "@call.outer", "Select outer part of a function call" },
        { "if", "@call.inner", "Select inner part of a function call" },
        { "am", "@function.outer", "Select outer part of a method/function definition" },
        { "im", "@function.inner", "Select inner part of a method/function definition" },
        { "ac", "@class.outer", "Select outer part of a class" },
        { "ic", "@class.inner", "Select inner part of a class" },
      }

      for _, map in ipairs(select_maps) do
        local key, query, desc = map[1], map[2], map[3]
        vim.keymap.set({ "x", "o" }, key, function()
          ts_select.select_textobject(query, "textobjects")
        end, { desc = desc })
      end

      -- Move keymaps
      local move_maps = {
        { "]f", "goto_next_start", "@call.outer", "Next function call start" },
        { "]m", "goto_next_start", "@function.outer", "Next method/function def start" },
        { "]c", "goto_next_start", "@class.outer", "Next class start" },
        { "]i", "goto_next_start", "@conditional.outer", "Next conditional start" },
        { "]l", "goto_next_start", "@loop.outer", "Next loop start" },
        { "]F", "goto_next_end", "@call.outer", "Next function call end" },
        { "]M", "goto_next_end", "@function.outer", "Next method/function def end" },
        { "]C", "goto_next_end", "@class.outer", "Next class end" },
        { "]I", "goto_next_end", "@conditional.outer", "Next conditional end" },
        { "]L", "goto_next_end", "@loop.outer", "Next loop end" },
        { "[f", "goto_previous_start", "@call.outer", "Prev function call start" },
        { "[m", "goto_previous_start", "@function.outer", "Prev method/function def start" },
        { "[c", "goto_previous_start", "@class.outer", "Prev class start" },
        { "[i", "goto_previous_start", "@conditional.outer", "Prev conditional start" },
        { "[l", "goto_previous_start", "@loop.outer", "Prev loop start" },
        { "[F", "goto_previous_end", "@call.outer", "Prev function call end" },
        { "[M", "goto_previous_end", "@function.outer", "Prev method/function def end" },
        { "[C", "goto_previous_end", "@class.outer", "Prev class end" },
        { "[I", "goto_previous_end", "@conditional.outer", "Prev conditional end" },
        { "[L", "goto_previous_end", "@loop.outer", "Prev loop end" },
      }

      for _, map in ipairs(move_maps) do
        local key, fn_name, query, desc = map[1], map[2], map[3], map[4]
        vim.keymap.set({ "n", "x", "o" }, key, function()
          ts_move[fn_name](query, "textobjects")
        end, { desc = desc })
      end

      -- Swap keymaps
      vim.keymap.set("n", "<leader>na", function() ts_swap.swap_next("@parameter.inner") end, { desc = "Swap parameter with next" })
      vim.keymap.set("n", "<leader>n:", function() ts_swap.swap_next("@property.outer") end, { desc = "Swap property with next" })
      vim.keymap.set("n", "<leader>nm", function() ts_swap.swap_next("@function.outer") end, { desc = "Swap function with next" })
      vim.keymap.set("n", "<leader>pa", function() ts_swap.swap_previous("@parameter.inner") end, { desc = "Swap parameter with prev" })
      vim.keymap.set("n", "<leader>p:", function() ts_swap.swap_previous("@property.outer") end, { desc = "Swap property with prev" })
      vim.keymap.set("n", "<leader>pm", function() ts_swap.swap_previous("@function.outer") end, { desc = "Swap function with prev" })

      -- Repeatable moves with ; and ,
      vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
      vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)
      vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
      vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
      vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
      vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })

      -- enable nvim-ts-context-commentstring plugin for commenting tsx and jsx
      require("ts_context_commentstring").setup({})
    end,
  },
}
