local M = {}

local has_nui, _ = pcall(require, "nui.popup")
if not has_nui then
  return M
end

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local task_manager = require("tasknotes.task_manager")
local config = require("tasknotes.config")

-- Active timer state
M.active_timer = nil

-- Format seconds to HH:MM:SS
local function format_duration(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60
  return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Get current time in ISO format
local function get_iso_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Start timer for task
function M.start_timer(task)
  if M.active_timer then
    vim.notify("Timer already running for: " .. M.active_timer.task.title, vim.log.levels.WARN)
    return
  end

  M.active_timer = {
    task = task,
    start_time = os.time(),
    start_iso = get_iso_timestamp(),
  }

  vim.notify("Started timer for: " .. task.title, vim.log.levels.INFO)
end

-- Stop timer and save time entry
function M.stop_timer()
  if not M.active_timer then
    vim.notify("No active timer", vim.log.levels.WARN)
    return
  end

  local end_time = os.time()
  local end_iso = get_iso_timestamp()
  local duration = math.floor((end_time - M.active_timer.start_time) / 60) -- minutes

  -- Create time entry
  local time_entry = {
    startTime = M.active_timer.start_iso,
    endTime = end_iso,
    duration = duration,
  }

  -- Get current task data
  local task = M.active_timer.task
  local time_entries = task.timeEntries or {}
  table.insert(time_entries, time_entry)

  -- Update task
  local success = task_manager.update_task(task.path, {
    timeEntries = time_entries,
  })

  if success then
    vim.notify(
      string.format("Stopped timer for: %s (Duration: %d minutes)", task.title, duration),
      vim.log.levels.INFO
    )
  else
    vim.notify("Failed to save time entry", vim.log.levels.ERROR)
  end

  M.active_timer = nil
end

-- Toggle timer (start if stopped, stop if running)
function M.toggle_timer(task)
  if M.active_timer then
    if M.active_timer.task.path == task.path then
      M.stop_timer()
    else
      vim.ui.select({ "Stop current", "Cancel" }, {
        prompt = "Timer already running for: " .. M.active_timer.task.title,
      }, function(choice)
        if choice == "Stop current" then
          M.stop_timer()
          M.start_timer(task)
        end
      end)
    end
  else
    M.start_timer(task)
  end
end

-- Get timer status (for statusline)
function M.get_status()
  if not M.active_timer then
    return nil
  end

  local elapsed = os.time() - M.active_timer.start_time
  return {
    task = M.active_timer.task.title,
    duration = format_duration(elapsed),
  }
end

-- Show timer status popup
function M.show_status()
  if not M.active_timer then
    vim.notify("No active timer", vim.log.levels.INFO)
    return
  end

  local opts = config.get()
  local task = M.active_timer.task
  local elapsed = os.time() - M.active_timer.start_time

  local popup = Popup({
    enter = false,
    focusable = false,
    border = {
      style = opts.ui.border_style,
      text = {
        top = " Timer Status ",
        top_align = "center",
      },
    },
    position = "50%",
    size = {
      width = opts.ui.time_tracker_width,
      height = opts.ui.time_tracker_height,
    },
  })

  local lines = {
    "Active Timer",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
    "Task: " .. task.title,
    "Status: " .. task.status,
    "Priority: " .. task.priority,
    "",
    "Started: " .. os.date("%Y-%m-%d %H:%M:%S", M.active_timer.start_time),
    "Elapsed: " .. format_duration(elapsed),
    "",
    "Total Tracked Time: " .. (task.totalTrackedTime or 0) .. " minutes",
    "",
    "",
    "[Press any key to close]",
  }

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  popup:map("n", "<Esc>", function()
    popup:unmount()
  end, { noremap = true })

  popup:map("n", "q", function()
    popup:unmount()
  end, { noremap = true })

  popup:mount()

  -- Auto-close after a few seconds
  vim.defer_fn(function()
    if popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
      popup:unmount()
    end
  end, 3000)
end

-- View time entries for a task
function M.view_time_entries(task)
  local opts = config.get()

  local popup = Popup({
    enter = true,
    focusable = true,
    border = {
      style = opts.ui.border_style,
      text = {
        top = " Time Entries: " .. task.title .. " ",
        top_align = "center",
      },
    },
    position = "50%",
    size = {
      width = 70,
      height = 20,
    },
  })

  local lines = {
    "Time Entries",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "",
  }

  if not task.timeEntries or #task.timeEntries == 0 then
    table.insert(lines, "No time entries recorded")
  else
    table.insert(lines, string.format("Total: %d minutes", task.totalTrackedTime or 0))
    table.insert(lines, "")

    for i, entry in ipairs(task.timeEntries) do
      table.insert(lines, string.format("Entry #%d:", i))
      table.insert(lines, "  Start:    " .. (entry.startTime or "N/A"))
      table.insert(lines, "  End:      " .. (entry.endTime or "Running"))
      table.insert(lines, "  Duration: " .. (entry.duration or 0) .. " minutes")
      table.insert(lines, "")
    end
  end

  table.insert(lines, "")
  table.insert(lines, "[Press <Esc> or q to close]")

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)

  popup:on(event.BufLeave, function()
    popup:unmount()
  end)

  popup:map("n", "<Esc>", function()
    popup:unmount()
  end, { noremap = true })

  popup:map("n", "q", function()
    popup:unmount()
  end, { noremap = true })

  popup:mount()
end

return M
