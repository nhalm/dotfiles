vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])

return require('packer').startup(function(use)

    -- packer manages itself
    use {'wbthomason/packer.nvim', opt = true}

    use {'tpope/vim-dispatch'}
    use {'tpope/vim-fugitive'}
    use {'tpope/vim-commentary'}
    use {'tpope/vim-unimpaired'}
    use {'tpope/vim-vinegar'}
    use {'tpope/vim-sleuth'}

    use {
        "folke/which-key.nvim",
        config = function()
            require("config.which_key").setup()
        end,
    }

    -- LSP
    use {'folke/lua-dev.nvim'}
    use {'williamboman/nvim-lsp-installer'}

    use {
        'neovim/nvim-lspconfig',
        -- opt = true,
        event = "BufRead",
        config = function()
            require("config.lsp").setup()
        end,
    }
    use {
        "tami5/lspsaga.nvim",
        config = function()
            require("config.lspsaga").setup()
            -- require("lspsaga").setup()
        end
    }

    use {
        "onsails/lspkind-nvim",
        config = function()
            require("lspkind").init()
        end,
    }
    use {'ray-x/lsp_signature.nvim'}

    -- Completion - use either one of this
    use {
        "hrsh7th/nvim-cmp",
        -- event = "BufRead",
        requires = {
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-nvim-lua",
            "quangnguyen30192/cmp-nvim-ultisnips",
            "octaltree/cmp-look",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-calc",
            "f3fora/cmp-spell",
            "hrsh7th/cmp-emoji",
        },
        config = function()
            require("config.cmp").setup()
        end,
    }
     -- Better syntax
    use {
        'nvim-treesitter/nvim-treesitter',
--        event = "BufRead",
        run = ":TSUpdate",
        config = function()
            require("config.treesitter").setup()
        end,
        requires = {
            {"p00f/nvim-ts-rainbow", event = "BufRead"},
        },
    }

    -- color scheme
    use {
      "kyazdani42/nvim-web-devicons",
      config = function()
        require("nvim-web-devicons").setup({default = true})
      end,
    }
    use {'kaicataldo/material.vim'}
    use {
        'nvim-lualine/lualine.nvim',
        event = "VimEnter",
        config = function()
            require("config.lualine").setup()
        end,
    }
    -- Fuzzy finder
    use {
        'nvim-telescope/telescope.nvim',
        requires = {{'nvim-lua/plenary.nvim'}}
    }

  use {
    "akinsho/nvim-bufferline.lua",
    config = function()
      require("config.bufferline").setup()
    end,
    event = "BufReadPre",
  }
  
end)
