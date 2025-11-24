local M = {}

local config = require("tasknotes.config")
local task_manager = require("tasknotes.task_manager")

-- Check dependencies
local function check_dependencies()
  local warnings = {}

  -- Check for nui.nvim
  local has_nui = pcall(require, "nui.popup")
  if not has_nui then
    table.insert(warnings, "nui.nvim not found - UI features will not work")
  end

  -- Check for telescope (optional)
  local has_telescope = pcall(require, "telescope")
  if not has_telescope then
    table.insert(warnings, "telescope.nvim not found - Telescope integration disabled")
  end

  -- Check for plenary (optional but recommended)
  local has_plenary = pcall(require, "plenary")
  if not has_plenary then
    table.insert(warnings, "plenary.nvim not found - some features may not work optimally")
  end

  return warnings
end

-- Setup highlight groups for completed tasks
local function setup_highlights()
  -- Create dimmed/greyed out highlight group for completed tasks
  vim.api.nvim_set_hl(0, "TaskNotesCompletedTitle", {
    fg = "#6c6c6c",        -- Dim gray color that works on both light/dark backgrounds
    strikethrough = true,  -- Clear visual indication that task is done
    italic = true,         -- Additional subtle cue
  })
end

-- Setup function
function M.setup(user_config)
  user_config = user_config or {}

  -- Import from Obsidian if enabled
  if user_config.obsidian and user_config.obsidian.enabled then
    local importer = require("tasknotes.obsidian_importer")
    local imported_config, err = importer.import_from_obsidian(user_config.obsidian.vault_path)

    if imported_config then
      -- Merge imported config with user config (user config takes precedence)
      user_config = vim.tbl_deep_extend("force", imported_config, user_config)
      vim.notify("Imported settings from Obsidian TaskNotes", vim.log.levels.INFO)
    else
      vim.notify("Could not import Obsidian settings: " .. (err or "unknown error"), vim.log.levels.WARN)
    end
  end

  -- Setup configuration
  config.setup(user_config)

  -- Setup highlight groups
  setup_highlights()

  local opts = config.get()

  -- Check dependencies
  local warnings = check_dependencies()
  for _, warning in ipairs(warnings) do
    vim.notify("TaskNotes: " .. warning, vim.log.levels.WARN)
  end

  -- Initial vault scan
  task_manager.scan_vault()

  -- Setup Telescope extension if available
  if opts.telescope.enabled then
    local has_telescope = pcall(require, "telescope")
    if has_telescope then
      local telescope_integration = require("tasknotes.telescope")
      telescope_integration.setup()
    end
  end

  -- Setup keymaps if configured
  if opts.keymaps.browse then
    vim.keymap.set("n", opts.keymaps.browse, function()
      M.browse_tasks()
    end, { desc = "Browse TaskNotes" })
  end

  if opts.keymaps.new_task then
    vim.keymap.set("n", opts.keymaps.new_task, function()
      M.new_task()
    end, { desc = "Create new TaskNote" })
  end

  if opts.keymaps.edit_task then
    vim.keymap.set("n", opts.keymaps.edit_task, function()
      M.edit_task()
    end, { desc = "Edit current TaskNote" })
  end

  if opts.keymaps.toggle_timer then
    vim.keymap.set("n", opts.keymaps.toggle_timer, function()
      M.toggle_timer()
    end, { desc = "Toggle TaskNote timer" })
  end

  -- Auto-save timer state periodically
  if opts.time_tracking.enabled then
    local timer = vim.loop.new_timer()
    timer:start(
      opts.time_tracking.auto_save_interval * 1000,
      opts.time_tracking.auto_save_interval * 1000,
      vim.schedule_wrap(function()
        local time_tracker = require("tasknotes.ui.time_tracker")
        if time_tracker.active_timer then
          -- Update in-memory task data
          task_manager.refresh_task(time_tracker.active_timer.task.path)
        end
      end)
    )
  end

  vim.notify("TaskNotes loaded", vim.log.levels.INFO)
end

-- Browse tasks
function M.browse_tasks(filter)
  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    local telescope_integration = require("tasknotes.telescope")
    telescope_integration.browse_tasks({ filter = filter })
  else
    vim.notify("Telescope not available", vim.log.levels.ERROR)
  end
end

-- Create new task
function M.new_task()
  local has_nui = pcall(require, "nui.popup")
  if has_nui then
    local task_form = require("tasknotes.ui.task_form")
    task_form.new_task()
  else
    vim.notify("NUI not available - cannot create task form", vim.log.levels.ERROR)
  end
end

-- Edit current buffer task
function M.edit_task()
  local has_nui = pcall(require, "nui.popup")
  if has_nui then
    local task_form = require("tasknotes.ui.task_form")
    task_form.edit_current_buffer()
  else
    vim.notify("NUI not available - cannot create task form", vim.log.levels.ERROR)
  end
end

-- Toggle timer for current task
function M.toggle_timer()
  local filepath = vim.api.nvim_buf_get_name(0)
  local task = task_manager.get_task_by_path(filepath)

  if not task then
    vim.notify("Current buffer is not a TaskNote", vim.log.levels.WARN)
    return
  end

  local has_nui = pcall(require, "nui.popup")
  if has_nui then
    local time_tracker = require("tasknotes.ui.time_tracker")
    time_tracker.toggle_timer(task)
  else
    vim.notify("NUI not available - cannot use time tracker", vim.log.levels.ERROR)
  end
end

-- Show timer status
function M.timer_status()
  local has_nui = pcall(require, "nui.popup")
  if has_nui then
    local time_tracker = require("tasknotes.ui.time_tracker")
    time_tracker.show_status()
  else
    vim.notify("NUI not available", vim.log.levels.ERROR)
  end
end

-- View time entries for current task
function M.view_time_entries()
  local filepath = vim.api.nvim_buf_get_name(0)
  local task = task_manager.get_task_by_path(filepath)

  if not task then
    vim.notify("Current buffer is not a TaskNote", vim.log.levels.WARN)
    return
  end

  local has_nui = pcall(require, "nui.popup")
  if has_nui then
    local time_tracker = require("tasknotes.ui.time_tracker")
    time_tracker.view_time_entries(task)
  else
    vim.notify("NUI not available", vim.log.levels.ERROR)
  end
end

-- Rescan vault
function M.rescan()
  task_manager.scan_vault()
end

-- Get statusline component
function M.statusline()
  local time_tracker = require("tasknotes.ui.time_tracker")
  local status = time_tracker.get_status()

  if status then
    return string.format(" %s (%s)", status.task, status.duration)
  end

  return ""
end

-- Import settings from Obsidian TaskNotes plugin
function M.import_obsidian_settings(obsidian_vault_path)
  local importer = require("tasknotes.obsidian_importer")

  local nvim_config, err = importer.import_from_obsidian(obsidian_vault_path)
  if not nvim_config then
    vim.notify("Failed to import Obsidian settings: " .. err, vim.log.levels.ERROR)
    return nil
  end

  -- Apply imported config
  config.setup(nvim_config)

  -- Rescan vault with new settings
  task_manager.scan_vault()

  vim.notify("Successfully imported settings from Obsidian", vim.log.levels.INFO)
  return nvim_config
end

-- Export public API
M.task_manager = task_manager
M.config = config

return M
