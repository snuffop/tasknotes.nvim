-- Snacks.nvim picker integration for tasknotes.nvim
local M = {}

local has_snacks, snacks = pcall(require, "snacks")
if not has_snacks then
  vim.notify("Snacks.nvim not found. Please install it for TaskNotes picker.", vim.log.levels.ERROR)
  return M
end

local task_manager = require("tasknotes.task_manager")
local config = require("tasknotes.config")

-- Helper function to safely convert values to strings (handles vim.NIL)
local function safe_string(value)
  if value == nil or value == vim.NIL then
    return ""
  end
  return tostring(value)
end

-- Format task for display in Snacks picker
local function format_task(task)
  local opts = config.get()

  -- Get status and priority info
  local status_info = config.get_status(task.status)
  local priority_info = config.get_priority(task.priority)

  -- Check if task is completed
  local is_completed = status_info.is_completed

  -- Determine dependency indicator
  local dep_indicator = " "
  local ok, is_blocked = pcall(task_manager.is_task_blocked, task)
  if ok and is_blocked then
    dep_indicator = "⛔"
  else
    local ok2, blocked_tasks = pcall(task_manager.get_blocked_tasks, task)
    if ok2 and blocked_tasks and #blocked_tasks > 0 then
      dep_indicator = "🔒"
    end
  end

  -- Format urgency score
  local urgency_str = string.format("%4.1f", task.urgency or 0)

  -- Format due date
  local due_str = safe_string(task.due)
  if #due_str > 10 then
    due_str = due_str:sub(1, 10)  -- Trim to date only
  end

  -- Format contexts
  local contexts_str = table.concat(task.contexts or {}, ", ")

  -- Build display line with fixed-width columns
  local line = string.format(
    "%s %s  %-35s %-12s %-10s %-12s %s",
    dep_indicator,
    urgency_str,
    safe_string(task.title):sub(1, 35),  -- Truncate long titles
    status_info.display,
    priority_info.display,
    due_str,
    contexts_str
  )

  return {
    text = line,
    -- Store task data for actions
    task = task,
    urgency = task.urgency or 0,
    -- Searchable text
    search = safe_string(task.title) .. " " .. safe_string(task.status) .. " " .. safe_string(task.due),
    -- File path for preview
    file = task.path,
    -- Metadata for highlighting
    is_completed = is_completed,
  }
end

-- Browse all tasks
function M.browse_tasks(opts)
  opts = opts or {}

  -- Ensure tasks are loaded before browsing
  if not task_manager.is_loaded then
    task_manager.scan_vault()
  end

  -- Get tasks (optionally filtered)
  local tasks = task_manager.get_tasks(opts.filter)

  if #tasks == 0 then
    vim.notify("No tasks found", vim.log.levels.WARN)
    return
  end

  -- Pre-sort tasks by urgency (descending)
  local urgency_module = require("tasknotes.urgency")
  tasks = urgency_module.sort_by_urgency(tasks)

  -- Format tasks for Snacks picker
  local items = {}
  for _, task in ipairs(tasks) do
    table.insert(items, format_task(task))
  end

  -- Create Snacks picker
  snacks.picker.pick({
    prompt = "TaskNotes",
    items = items,
    format = "text",  -- Use built-in text formatter

    -- Custom sort: urgency descending (Snacks handles fuzzy matching automatically)
    sort = function(a, b)
      -- Primary sort: urgency (higher urgency first)
      if a.urgency ~= b.urgency then
        return a.urgency > b.urgency
      end
      -- Secondary sort: alphabetical by title
      return (a.task.title or "") < (b.task.title or "")
    end,

    -- Preview configuration
    preview = function(item)
      if item.file then
        return {
          file = item.file,
          type = "file",
        }
      end
    end,

    -- Actions
    actions = {
      -- Default action: open file
      select = function(item)
        if item and item.file then
          vim.cmd("edit " .. item.file)
        end
      end,

      -- Mark as done (Ctrl-d)
      ["<C-d>"] = function(item, picker)
        if not item or not item.task then return end

        -- Check if this task blocks other tasks
        local ok, blocked_tasks = pcall(task_manager.get_blocked_tasks, item.task)
        if ok and blocked_tasks and #blocked_tasks > 0 then
          local task_titles = {}
          for _, t in ipairs(blocked_tasks) do
            table.insert(task_titles, t.title)
          end
          vim.notify(
            string.format(
              "Warning: This task blocks %d other task(s): %s",
              #blocked_tasks,
              table.concat(task_titles, ", ")
            ),
            vim.log.levels.WARN
          )
        end

        -- Update task status
        task_manager.update_task(item.file, {
          status = "done",
          completedDate = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
        vim.notify("Marked task as done", vim.log.levels.INFO)

        -- Refresh picker
        vim.schedule(function()
          picker:close()
          M.browse_tasks(opts)
        end)
      end,

      -- Edit metadata (Ctrl-e)
      ["<C-e>"] = function(item, picker)
        if not item or not item.task then return end

        picker:close()
        local has_form, task_form = pcall(require, "tasknotes.ui.task_form")
        if has_form then
          task_form.edit_task(item.task)
        else
          vim.notify("Task form not available", vim.log.levels.ERROR)
        end
      end,

      -- Delete task (Ctrl-x)
      ["<C-x>"] = function(item, picker)
        if not item or not item.task then return end

        -- Confirm deletion
        vim.ui.select({ "Yes", "No" }, {
          prompt = "Delete task: " .. item.task.title .. "?",
        }, function(choice)
          if choice == "Yes" then
            task_manager.delete_task(item.file)
            vim.notify("Task deleted", vim.log.levels.INFO)

            -- Refresh picker
            vim.schedule(function()
              picker:close()
              M.browse_tasks(opts)
            end)
          end
        end)
      end,

      -- Toggle timer (Ctrl-t)
      ["<C-t>"] = function(item, picker)
        if not item or not item.task then return end

        local has_tracker, time_tracker = pcall(require, "tasknotes.ui.time_tracker")
        if has_tracker then
          time_tracker.toggle_timer(item.task)
        else
          vim.notify("Time tracker not available", vim.log.levels.ERROR)
        end
      end,
    },
  })
end

-- Filter by status
function M.browse_by_status(status)
  M.browse_tasks({ filter = { status = status } })
end

-- Filter by priority
function M.browse_by_priority(priority)
  M.browse_tasks({ filter = { priority = priority } })
end

-- Filter by context
function M.browse_by_context(context)
  M.browse_tasks({ filter = { context = context } })
end

-- Setup function (no-op for Snacks, but kept for compatibility)
function M.setup()
  -- Snacks doesn't require explicit extension registration
  return true
end

return M
