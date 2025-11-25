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

  -- Check for snacks (required for picker)
  local has_snacks = pcall(require, "snacks")
  if not has_snacks then
    table.insert(warnings, "snacks.nvim not found - Task picker will not work")
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

  if opts.keymaps.view_selector then
    vim.keymap.set("n", opts.keymaps.view_selector, function()
      M.show_view_selector()
    end, { desc = "Open TaskNotes view selector" })
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
  local has_snacks = pcall(require, "snacks")
  if has_snacks then
    local picker = require("tasknotes.snacks_picker")
    picker.browse_tasks({ filter = filter })
  else
    vim.notify("Snacks.nvim not available", vim.log.levels.ERROR)
  end
end

-- Browse tasks by view
function M.browse_by_view(view_name)
  local has_snacks = pcall(require, "snacks")
  if has_snacks then
    local picker = require("tasknotes.snacks_picker")
    picker.browse_by_view(view_name)
  else
    vim.notify("Snacks.nvim not available", vim.log.levels.ERROR)
  end
end

-- Show view selector
function M.show_view_selector()
  local has_snacks = pcall(require, "snacks")
  if has_snacks then
    local picker = require("tasknotes.snacks_picker")
    picker.show_view_selector()
  else
    vim.notify("Snacks.nvim not available", vim.log.levels.ERROR)
  end
end

-- Save current filter as a custom view
function M.save_view(name, description, filter)
  local views = require("tasknotes.views")
  local view = views.create_view(name, description, filter)
  local success = views.save_view(name, view)
  if success then
    vim.notify("View saved: " .. name, vim.log.levels.INFO)
  end
  return success
end

-- Delete a custom view
function M.delete_view(view_name)
  local views = require("tasknotes.views")
  local success = views.delete_view(view_name)
  if success then
    vim.notify("View deleted: " .. view_name, vim.log.levels.INFO)
  end
  return success
end

-- List all views (shows picker)
function M.list_views()
  M.show_view_selector()
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

-- Show dependencies for current task
function M.show_dependencies()
  local filepath = vim.api.nvim_buf_get_name(0)
  local task = task_manager.get_task_by_path(filepath)

  if not task then
    vim.notify("Current buffer is not a TaskNote", vim.log.levels.WARN)
    return
  end

  local blocking_tasks = task_manager.get_blocking_tasks(task)
  local blocked_tasks = task_manager.get_blocked_tasks(task)

  local lines = {}
  table.insert(lines, "Dependencies for: " .. task.title)
  table.insert(lines, "")

  if #blocking_tasks > 0 then
    table.insert(lines, "Blocked by:")
    for _, t in ipairs(blocking_tasks) do
      local status = config.get_status(t.status)
      local status_str = status.is_completed and "[✓]" or "[ ]"
      table.insert(lines, string.format("  %s %s (%s)", status_str, t.title, t.path))
    end
  else
    table.insert(lines, "Not blocked by any tasks")
  end

  table.insert(lines, "")

  if #blocked_tasks > 0 then
    table.insert(lines, "Blocking:")
    for _, t in ipairs(blocked_tasks) do
      table.insert(lines, string.format("  - %s (%s)", t.title, t.path))
    end
  else
    table.insert(lines, "Not blocking any tasks")
  end

  -- Create a new buffer to display dependencies
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

  -- Open in a split
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_buf_set_name(bufnr, "Task Dependencies")
end

-- Navigate to blocking tasks
function M.goto_blocking_tasks()
  local filepath = vim.api.nvim_buf_get_name(0)
  local task = task_manager.get_task_by_path(filepath)

  if not task then
    vim.notify("Current buffer is not a TaskNote", vim.log.levels.WARN)
    return
  end

  local blocking_tasks = task_manager.get_blocking_tasks(task)

  if #blocking_tasks == 0 then
    vim.notify("No blocking tasks", vim.log.levels.INFO)
    return
  end

  if #blocking_tasks == 1 then
    vim.cmd("edit " .. blocking_tasks[1].path)
    return
  end

  -- Multiple blocking tasks - show selector
  local task_labels = {}
  for _, t in ipairs(blocking_tasks) do
    table.insert(task_labels, t.title)
  end

  vim.ui.select(task_labels, {
    prompt = "Select blocking task:",
  }, function(choice, idx)
    if idx then
      vim.cmd("edit " .. blocking_tasks[idx].path)
    end
  end)
end

-- Navigate to blocked tasks
function M.goto_blocked_tasks()
  local filepath = vim.api.nvim_buf_get_name(0)
  local task = task_manager.get_task_by_path(filepath)

  if not task then
    vim.notify("Current buffer is not a TaskNote", vim.log.levels.WARN)
    return
  end

  local blocked_tasks = task_manager.get_blocked_tasks(task)

  if #blocked_tasks == 0 then
    vim.notify("No blocked tasks", vim.log.levels.INFO)
    return
  end

  if #blocked_tasks == 1 then
    vim.cmd("edit " .. blocked_tasks[1].path)
    return
  end

  -- Multiple blocked tasks - show selector
  local task_labels = {}
  for _, t in ipairs(blocked_tasks) do
    table.insert(task_labels, t.title)
  end

  vim.ui.select(task_labels, {
    prompt = "Select blocked task:",
  }, function(choice, idx)
    if idx then
      vim.cmd("edit " .. blocked_tasks[idx].path)
    end
  end)
end

-- Export public API
M.task_manager = task_manager
M.config = config

return M
