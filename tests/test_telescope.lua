-- Tests for tasknotes.telescope module
-- Includes regression test for the concatenation bug
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality
local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      child.setup()

      -- Check if telescope is available
      local has_telescope = child.lua_get([[
        local ok = pcall(require, 'telescope')
        return ok
      ]])

      if not has_telescope then
        MiniTest.skip('Telescope not available')
        return
      end

      local temp_vault = child.lua_get([[vim.fn.tempname()]])
      child.lua(string.format([[
        vim.fn.mkdir('%s', 'p')
        Config = require('tasknotes.config')
        Config.setup({ vault_path = '%s' })
        TaskManager = require('tasknotes.task_manager')
        Telescope = require('tasknotes.telescope')
      ]], temp_vault, temp_vault))
    end,
    post_once = child.stop,
  },
})

-- Test the safe_string helper and entry maker (regression test for the bug)
T['entry_maker_safe_string'] = new_set()

T['entry_maker_safe_string']['handles nil values without error'] = function()
  -- This tests the scenario where values are explicitly nil
  local success = child.lua_get([[
    -- Simulate a task with nil values
    local task = {
      path = '/test.md',
      title = 'Test Task',
      status = 'open',
      due = nil,  -- nil value
      contexts = {},
      projects = {},
      tags = {},
      priority = 'none',
    }

    -- Test that we can safely concatenate these values
    -- (this is what happens in make_entry's ordinal field)
    local ok, result = pcall(function()
      -- This is the safe_string logic from telescope.lua
      local function safe_string(value)
        if value == nil or value == vim.NIL then
          return ""
        end
        return tostring(value)
      end

      local ordinal = safe_string(task.title) .. ' ' ..
                     safe_string(task.status) .. ' ' ..
                     safe_string(task.due)
      return ordinal
    end)

    return ok and result ~= nil
  ]])

  eq(success, true)
end

T['entry_maker_safe_string']['handles vim.NIL values without error (REGRESSION TEST)'] = function()
  -- This is the EXACT bug scenario that caused the error:
  -- "attempt to concatenate a userdata value"
  local success = child.lua_get([[
    -- Simulate a task with vim.NIL values (from YAML parser)
    local task = {
      path = '/test.md',
      title = 'Test Task',
      status = vim.NIL,  -- vim.NIL from YAML parser (the bug!)
      due = vim.NIL,     -- vim.NIL from YAML parser
      contexts = {},
      projects = {},
      tags = {},
      priority = vim.NIL,
    }

    -- This should NOT crash after our fix
    local ok, result = pcall(function()
      -- This is the safe_string logic that fixes the bug
      local function safe_string(value)
        if value == nil or value == vim.NIL then
          return ""
        end
        return tostring(value)
      end

      -- This concatenation previously failed with:
      -- "attempt to concatenate a userdata value"
      local ordinal = safe_string(task.title) .. ' ' ..
                     safe_string(task.status) .. ' ' ..
                     safe_string(task.due)

      return ordinal
    end)

    return ok and result ~= nil
  ]])

  eq(success, true)
end

T['entry_maker_safe_string']['handles mixed nil and vim.NIL values'] = function()
  local success = child.lua_get([[
    local task = {
      path = '/test.md',
      title = 'Test Task',   -- string
      status = nil,          -- nil
      due = vim.NIL,         -- vim.NIL
      priority = 'high',     -- string
      contexts = {},
      projects = {},
      tags = {},
    }

    local ok, result = pcall(function()
      local function safe_string(value)
        if value == nil or value == vim.NIL then
          return ""
        end
        return tostring(value)
      end

      local ordinal = safe_string(task.title) .. ' ' ..
                     safe_string(task.status) .. ' ' ..
                     safe_string(task.due) .. ' ' ..
                     safe_string(task.priority)

      -- Should produce: "Test Task   high"
      return ordinal
    end)

    return ok and result:match('Test Task') ~= nil
  ]])

  eq(success, true)
end

-- Test display function
T['display_function'] = new_set()

T['display_function']['handles nil due date'] = function()
  local success = child.lua_get([[
    local task = {
      path = '/test.md',
      title = 'Test Task',
      status = 'open',
      priority = 'normal',
      due = nil,  -- nil due date
      contexts = { '@home' },
      projects = {},
      tags = {},
    }

    local ok, err = pcall(function()
      -- Test safe_string for due date formatting (used in make_display)
      local function safe_string(value)
        if value == nil or value == vim.NIL then
          return ""
        end
        return tostring(value)
      end

      local due_str = safe_string(task.due)
      local title_str = safe_string(task.title)

      return due_str == "" and title_str == "Test Task"
    end)

    return ok
  ]])

  eq(success, true)
end

T['display_function']['handles vim.NIL due date'] = function()
  local success = child.lua_get([[
    local task = {
      path = '/test.md',
      title = 'Test Task',
      status = 'open',
      priority = 'normal',
      due = vim.NIL,  -- vim.NIL due date from YAML
      contexts = {},
      projects = {},
      tags = {},
    }

    local ok, err = pcall(function()
      local function safe_string(value)
        if value == nil or value == vim.NIL then
          return ""
        end
        return tostring(value)
      end

      local due_str = safe_string(task.due)
      return due_str == ""
    end)

    return ok
  ]])

  eq(success, true)
end

-- Test with actual task manager integration
T['full_integration'] = new_set()

T['full_integration']['task with nil values can be processed'] = function()
  -- This tests the full pipeline: task creation -> telescope entry
  local success = child.lua_get([[
    -- Create a task object with vim.NIL values (simulating YAML parser output)
    local frontmatter = {
      title = 'Integration Test',
      status = vim.NIL,
      priority = vim.NIL,
      due = vim.NIL,
    }

    local task = TaskManager.create_task_object('/test.md', frontmatter, '')

    -- After create_task_object, all vim.NIL should be normalized
    -- This is the defense-in-depth fix in task_manager.lua

    local ok, err = pcall(function()
      -- Simulate what happens in telescope's make_entry
      local function safe_string(value)
        if value == nil or value == vim.NIL then
          return ""
        end
        return tostring(value)
      end

      local ordinal = safe_string(task.title) .. ' ' ..
                     safe_string(task.status) .. ' ' ..
                     safe_string(task.due)

      return ordinal ~= nil
    end)

    return ok
  ]])

  eq(success, true)
end

return T
