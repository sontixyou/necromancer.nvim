-- minimal_init.lua
-- Minimal Neovim configuration for running tests with plenary.nvim

-- Set up runtime path
local project_root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(project_root)

-- Add plenary.nvim to runtime path (clone location for CI)
local plenary_path = vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start/plenary.nvim')
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:prepend(plenary_path)
end

-- Alternative: Check if plenary is in the test dependencies directory
local test_deps_plenary = project_root .. '/test_deps/plenary.nvim'
if vim.fn.isdirectory(test_deps_plenary) == 1 then
  vim.opt.runtimepath:prepend(test_deps_plenary)
end

-- Set up Lua package path for the plugin
package.path = project_root .. '/lua/?.lua;' .. project_root .. '/lua/?/init.lua;' .. package.path

-- Minimal vim settings for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Load plenary
local ok, plenary = pcall(require, 'plenary')
if not ok then
  print('ERROR: plenary.nvim not found. Please install it first.')
  print('Run: git clone https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim')
  vim.cmd('cquit 1')
end
