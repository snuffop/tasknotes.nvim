-- Minimal init.lua for testing tasknotes.nvim with mini.test
-- Usage: nvim --headless --noplugin -u scripts/minimal_init.lua -c "lua MiniTest.run()"

-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Set up 'mini.test' only when calling headless Neovim
if #vim.api.nvim_list_uis() == 0 then
  -- Add required dependencies to runtimepath
  local dependencies = {
    {
      name = "mini.nvim",
      paths = {
        vim.fn.stdpath('data') .. '/lazy/mini.nvim',
        vim.fn.stdpath('data') .. '/site/pack/deps/start/mini.nvim',
        vim.fn.stdpath('data') .. '/site/pack/*/start/mini.nvim',
      },
      required = true,
    },
    {
      name = "bases.nvim",
      paths = {
        -- Local development path (same parent directory)
        vim.fn.fnamemodify(vim.fn.getcwd(), ':h') .. '/bases.nvim',
        -- Plugin manager paths
        vim.fn.stdpath('data') .. '/lazy/bases.nvim',
        vim.fn.stdpath('data') .. '/site/pack/*/start/bases.nvim',
      },
      required = true,
    },
  }

  -- Load dependencies
  for _, dep in ipairs(dependencies) do
    local found = false
    for _, path in ipairs(dep.paths) do
      if vim.fn.isdirectory(path) == 1 then
        vim.cmd('set rtp+=' .. path)
        found = true
        break
      end
    end

    if not found and dep.required then
      error(string.format([[
%s not found. Please install it first or ensure it's in the expected location.

Searched paths:
%s
]], dep.name, table.concat(dep.paths, "\n")))
    end
  end

  -- Setup mini.test
  require('mini.test').setup()
end
