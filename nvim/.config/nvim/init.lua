-- Map leader to space
vim.g.mapleader = " "
vim.g.maplocalleader = ","

local cmd = vim.cmd

pcall(require, "impatient")

if require "config.first_load"() then
	return
end

-- Commands
-- cmd [[command! WhatHighlight :call util#syntax_stack()]]
-- cmd [[command! PackerInstall packadd packer.nvim | lua require('plugins2').install()]]
-- cmd [[command! PackerUpdate packadd packer.nvim | lua require('plugins2').update()]]
-- cmd [[command! PackerSync packadd packer.nvim | lua require('plugins2').sync()]]
-- cmd [[command! PackerClean packadd packer.nvim | lua require('plugins2').clean()]]
-- cmd [[command! PackerCompile packadd packer.nvim | lua require('plugins2').compile()]]
-- 

require "config.globals"
require "defaults".setup()
require "settings".setup()
require "plugins".setup()

-- 
-- local fn = vim.fn
-- local execute = vim.api.nvim_command
-- 
-- local function sys_init()
--   -- Performance
--   -- require "impatient".enable_profile()
--   require "impatient"
-- end
-- 
-- ----- Start loading ----------
-- -- sys_init()
-- -- 
-- --
-- -- packer_init()
-- 
-- pcall(require, 'impatient')
-- 
-- if not pcall(require, "packer") then 
--   local fn = vim.fn
--   local install_path = fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
--   if fn.empty(fn.glob(install_path)) > 0 then
--     packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
--   end
--   print(" yo need to restart...")
--   return true
-- end
-- _ = vim.cmd [[packadd packer.nvim]]
-- print( "a thing")
-- --require "packer_compiled"
-- -- 
-- 
-- require("defaults").setup()
-- 
-- -- require("settings").setup()
-- 
-- -- require("keymappings").setup()
-- 
-- -- vim.defer_fn(function()
-- -- require("plugins").setup()
-- -- end, 0)
-- 
-- ----- End loading ----------
