-- Minimal init.lua for testing tasknotes.nvim with mini.test
-- Usage: nvim --headless --noplugin -u scripts/minimal_init.lua -c "lua MiniTest.run()"

-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Set up 'mini.test' only when calling headless Neovim
if #vim.api.nvim_list_uis() == 0 then
  -- Add 'mini.nvim' to 'runtimepath'
  -- Try multiple locations where mini.nvim might be installed
  local possible_paths = {
    vim.fn.stdpath('data') .. '/lazy/mini.nvim',
    vim.fn.stdpath('data') .. '/site/pack/deps/start/mini.nvim',
    vim.fn.stdpath('data') .. '/site/pack/*/start/mini.nvim',
  }

  local mini_path = nil
  for _, path in ipairs(possible_paths) do
    if vim.fn.isdirectory(path) == 1 then
      mini_path = path
      break
    end
  end

  if mini_path then
    vim.cmd('set rtp+=' .. mini_path)
    require('mini.test').setup()
  else
    error([[
mini.nvim not found. Please install it first:

  Using lazy.nvim:
  { 'echasnovski/mini.nvim' }

  Using packer.nvim:
  use 'echasnovski/mini.nvim'
]])
  end
end
