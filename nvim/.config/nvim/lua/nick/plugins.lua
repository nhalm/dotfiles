local M = {}

local packer_bootstrap = false

local function packer_init()
  local fn = vim.fn
  local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
  if fn.empty(fn.glob(install_path)) > 0 then
    packer_bootstrap = fn.system {
      "git",
      "clone",
      "--depth",
      "1",
      "https://github.com/wbthomason/packer.nvim",
      install_path,
    }
    vim.cmd [[packadd packer.nvim]]
  end
  vim.cmd "autocmd BufWritePost plugins.lua source <afile> | PackerCompile"
end

packer_init()

function M.setup()
  local conf = {
    compile_path = vim.fn.stdpath "config" .. "/lua/packer_compiled.lua",
    max_jobs = 10,
    display = {
      open_fn = function()
        return require("packer.util").float { border = "rounded" }
      end,
    },
  }


  local function plugins(use)
    use { "lewis6991/impatient.nvim" }
    use { "wbthomason/packer.nvim" }

    use {
      'folke/tokyonight.nvim',
      --        config = function()
      --          vim.cmd "colorscheme tokyonight-moon"
      --        end,
    }
    use {
      'nvim-lualine/lualine.nvim', -- Statusline
      after = "nvim-treesitter",
      config = function()
        require("nick.lualine").setup()
      end
    }
    use 'nvim-lua/plenary.nvim' -- Common utilities
    use 'nvim-lua/popup.nvim'

    use 'onsails/lspkind-nvim' -- vscode-like pictograms
    use {
      'hrsh7th/nvim-cmp', -- Completion
      event = "InsertEnter",
      opt = true,
      requires = {
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-nvim-lsp",
        "quangnguyen30192/cmp-nvim-ultisnips",
        "hrsh7th/cmp-nvim-lua",
        "octaltree/cmp-look",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-calc",
        "f3fora/cmp-spell",
        "hrsh7th/cmp-emoji",
        "ray-x/cmp-treesitter",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/cmp-nvim-lsp-document-symbol",
      },
      config = function()
      end
    }
    use "williamboman/nvim-lsp-installer"
    use 'neovim/nvim-lspconfig' -- LSP
    use 'jose-elias-alvarez/null-ls.nvim' -- Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua
    use 'williamboman/mason.nvim'
    use 'williamboman/mason-lspconfig.nvim'

    use 'glepnir/lspsaga.nvim' -- LSP UIs
    use 'L3MON4D3/LuaSnip'
    --     use {
    --       'nvim-treesitter/nvim-treesitter',
    --       run = function() require('nvim-treesitter.install').update({ with_sync = true }) end,
    --     }
    -- Better syntax
    use {
      "nvim-treesitter/nvim-treesitter",
      as = "nvim-treesitter",
      event = "BufRead",
      opt = true,
      run = ":TSUpdate",
      config = function()
        require("nick.treesitter").setup()
      end,
      requires = {
        { "jose-elias-alvarez/nvim-lsp-ts-utils" },
        { "JoosepAlviste/nvim-ts-context-commentstring" },
        { "p00f/nvim-ts-rainbow" },
        {
          "nvim-treesitter/playground",
          cmd = "TSHighlightCapturesUnderCursor",
        },
        {
          "nvim-treesitter/nvim-treesitter-textobjects",
        },
        { "RRethy/nvim-treesitter-textsubjects" },
        {
          "windwp/nvim-autopairs",
          run = "make",
          config = function()
            require("nvim-autopairs").setup {}
          end,
        },
        {
          "windwp/nvim-ts-autotag",
          config = function()
            require("nvim-ts-autotag").setup { enable = true }
          end,
        },
        {
          "nvim-treesitter/nvim-treesitter-context",
          config = function()
            require("treesitter-context").setup { enable = true }
          end,
        },
        {
          "mfussenegger/nvim-ts-hint-textobject",
          config = function()
            vim.cmd [[omap     <silent> m :<C-U>lua require('tsht').nodes()<CR>]]
            vim.cmd [[vnoremap <silent> m :lua require('tsht').nodes()<CR>]]
          end,
        },
      },
    }
    use 'kyazdani42/nvim-web-devicons' -- File icons
    --    use 'nvim-telescope/telescope.nvim'
    --    use 'nvim-telescope/telescope-file-browser.nvim'
    use {
      "nvim-telescope/telescope.nvim",
      module = "telescope",
      as = "telescope",
      requires = {
        "nvim-telescope/telescope-project.nvim",
        "nvim-telescope/telescope-file-browser.nvim",
        "nvim-telescope/telescope-github.nvim",
        "cljoly/telescope-repo.nvim",
        -- 'nvim-telescope/telescope-hop.nvim'
        { "nvim-telescope/telescope-fzf-native.nvim", run = "make" },
        {
          "nvim-telescope/telescope-frecency.nvim",
          requires = { "kkharji/sqlite.lua" },
        },
        {
          "nvim-telescope/telescope-vimspector.nvim",
          event = "BufWinEnter",
        },
        { "nvim-telescope/telescope-dap.nvim" },
      },
      config = function()
        require("nick.telescope").setup()
      end,
    }
    use 'windwp/nvim-autopairs'
    use 'windwp/nvim-ts-autotag'
    use 'norcalli/nvim-colorizer.lua'
    use 'folke/zen-mode.nvim'
    --    use({
    --      "iamcco/markdown-preview.nvim",
    --      run = function() vim.fn["mkdp#util#install"]() end,
    --    })
    use 'akinsho/nvim-bufferline.lua'
    -- use 'github/copilot.vim'

    use 'lewis6991/gitsigns.nvim'
    use 'dinhhuy258/git.nvim' -- For git blame & browse

    use {
      "voldikss/vim-floaterm",
      event = "VimEnter",
      config = function()
        require("nick.whichkey").setup()
      end
    }

    use {
      "folke/which-key.nvim",
      config = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 300
        local wk = require("which-key")
        wk.setup {}
        wk.register()
      end
    }

    if packer_bootstrap then
      print "Setting up Neovim. Restart required after installation!"
      require("packer").sync()
    end
  end

  pcall(require, "impatient")
  pcall(require, "packer_compiled")
  require("packer").init(conf)
  require("packer").startup(plugins)
end

return M
