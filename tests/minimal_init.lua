-- Set minimal runtime path - only current directory and plenary
local cwd = vim.fn.getcwd()
local plenary_path = vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim")
vim.opt.rtp = { cwd, plenary_path, vim.env.VIMRUNTIME }

-- Load plenary plugin files to get commands
vim.cmd("source " .. plenary_path .. "/plugin/plenary.vim")
