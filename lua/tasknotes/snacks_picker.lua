-- Snacks.nvim picker integration for tasknotes.nvim
local M = {}

local has_snacks, snacks = pcall(require, "snacks")
if not has_snacks then
  vim.notify("Snacks.nvim not found. Please install it for TaskNotes picker.", vim.log.levels.ERROR)
  return M
end

local task_manager = require("tasknotes.task_manager")
local config = require("tasknotes.config")
local bases = require("bases")

local function parse_iso_date(date_str)
  if not date_str or date_str == "" then
    return nil
  end

  local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
  if not year then
    return nil
  end

  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = 0,
    min = 0,
    sec = 0,
  })
end

local function today_timestamp()
  return os.time({
    year = tonumber(os.date("%Y")),
    month = tonumber(os.date("%m")),
    day = tonumber(os.date("%d")),
    hour = 0,
    min = 0,
    sec = 0,
  })
end

local function is_completed(task)
  return config.get_status(task.status).is_completed
end

local function is_actionable(task)
  return not is_completed(task)
end

local function same_day(date_str, target_ts)
  local value_ts = parse_iso_date(date_str)
  return value_ts ~= nil and value_ts == target_ts
end

local function between_days(date_str, start_ts, end_ts)
  local value_ts = parse_iso_date(date_str)
  return value_ts ~= nil and value_ts >= start_ts and value_ts <= end_ts
end

local function has_tag(task, tag)
  for _, value in ipairs(task.tags or {}) do
    if value == tag then
      return true
    end
  end

  return false
end

local function wiki_link_for_path(path)
  local basename = vim.fn.fnamemodify(path, ":t:r")
  return string.format("[[%s]]", basename)
end

local function list_contains_reference(values, reference)
  if not reference or reference == "" then
    return false
  end

  for _, value in ipairs(values or {}) do
    if value == reference then
      return true
    end
  end

  return false
end

local function get_current_task_context()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    return nil
  end

  return {
    filepath = filepath,
    task = task_manager.get_task_by_path(filepath),
    wikilink = wiki_link_for_path(filepath),
  }
end

local function compatible_view_filter(view_id)
  local today = today_timestamp()
  local week_end = today + (7 * 24 * 60 * 60)

  local stock_views = {
    ["tasks-default:Manual Order"] = function()
      return true
    end,
    ["tasks-default:All Tasks"] = function()
      return true
    end,
    ["tasks-default:Today"] = function(task)
      return is_actionable(task) and (same_day(task.due, today) or same_day(task.scheduled, today))
    end,
    ["tasks-default:Overdue"] = function(task)
      local due_ts = parse_iso_date(task.due)
      return is_actionable(task) and due_ts ~= nil and due_ts < today
    end,
    ["tasks-default:This Week"] = function(task)
      if not is_actionable(task) then
        return false
      end

      return between_days(task.due, today, week_end) or between_days(task.scheduled, today, week_end)
    end,
    ["tasks-default:Unscheduled"] = function(task)
      return is_actionable(task) and not parse_iso_date(task.due) and not parse_iso_date(task.scheduled)
    end,
    ["tasks-default:Not Blocked"] = function(task)
      return is_actionable(task) and not task_manager.is_task_blocked(task)
    end,
    ["tasks-default:Read Later"] = function(task)
      return has_tag(task, "read-later")
    end,
    ["relationships:Projects"] = function(task)
      local context = get_current_task_context()
      return context ~= nil and list_contains_reference(task.projects, context.wikilink)
    end,
    ["relationships:Blocked By"] = function(task)
      local context = get_current_task_context()
      if not context or not context.task then
        return false
      end

      for _, blocking_task in ipairs(task_manager.get_blocking_tasks(context.task)) do
        if blocking_task.path == task.path then
          return true
        end
      end

      return false
    end,
    ["relationships:Blocking"] = function(task)
      local context = get_current_task_context()
      if not context or not context.task then
        return false
      end

      for _, blocked_task in ipairs(task_manager.get_blocked_tasks(context.task)) do
        if blocked_task.path == task.path then
          return true
        end
      end

      return false
    end,
  }

  return stock_views[view_id]
end

-- Helper function to safely convert values to strings (handles vim.NIL)
local function safe_string(value)
  if value == nil or value == vim.NIL then
    return ""
  end
  return tostring(value)
end

local function get_selected_item(picker)
  local items = picker:selected({ fallback = true })
  return items[1]
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

  -- Determine prompt text
  local prompt_text = "TaskNotes"
  if opts.view_name then
    prompt_text = "TaskNotes [" .. opts.view_name .. "]"
  end

  -- Create Snacks picker
  snacks.picker.pick({
    prompt = prompt_text,
    items = items,

    -- Layout with preview support (telescope-style)
    layout = {
      preset = "telescope",
    },

    -- Format with proper highlighting
    format = function(item, picker)
      local ret = {}

      if item.is_completed then
        local hl_group = "TaskNotesCompletedTitle"
        -- Fallback if highlight group doesn't exist
        if vim.fn.hlexists(hl_group) == 0 then
          hl_group = "SnacksPickerComment"  -- Snacks' dimmed style
        end
        ret[#ret + 1] = { item.text, hl_group }
      else
        ret[#ret + 1] = { item.text, "SnacksPickerNormal" }
      end

      return ret
    end,

    -- Custom sort: urgency descending (Snacks handles fuzzy matching automatically)
    sort = function(a, b)
      -- Primary sort: urgency (higher urgency first)
      if a.urgency ~= b.urgency then
        return a.urgency > b.urgency
      end
      -- Secondary sort: alphabetical by title
      return (a.task.title or "") < (b.task.title or "")
    end,

    -- Preview configuration - use built-in file previewer
    preview = function(ctx)
      if ctx.item.file then
        return snacks.picker.preview.file(ctx)
      end
    end,

    -- Actions
    actions = {
      -- Default action: open file (Enter key)
      confirm = function(picker)
        local item = get_selected_item(picker)
        if item and item.file then
          picker:close()
          vim.cmd("edit " .. vim.fn.fnameescape(item.file))
        end
      end,

      -- Mark as done (Ctrl-d)
      ["<C-d>"] = function(picker)
        local item = get_selected_item(picker)
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
      ["<C-e>"] = function(picker)
        local item = get_selected_item(picker)
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
      ["<C-x>"] = function(picker)
        local item = get_selected_item(picker)
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
      ["<C-t>"] = function(picker)
        local item = get_selected_item(picker)
        if not item or not item.task then return end

        local has_tracker, time_tracker = pcall(require, "tasknotes.ui.time_tracker")
        if has_tracker then
          time_tracker.toggle_timer(item.task)
        else
          vim.notify("Time tracker not available", vim.log.levels.ERROR)
        end
      end,

      -- View selector (Ctrl-v)
      ["<C-v>"] = function(picker)
        picker:close()
        vim.schedule(function()
          M.show_view_selector()
        end)
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

-- Browse by view
function M.browse_by_view(view_id)
  local views_dir = config.get_views_dir()
 
  local view, err = bases.get_view(view_id, views_dir, { view_type = "tasknotesTaskList" })
  if not view then
    vim.notify("View not found: " .. view_id .. (err and (" - " .. err) or ""), vim.log.levels.ERROR)
    return
  end

  local predicate = compatible_view_filter(view_id)
  if predicate then
    M.browse_tasks({
      filter = { predicate = predicate },
      view_name = view.name,
    })
    return
  end

  -- Combine base filters and view-specific filters
  local combined_filters = nil
  if view.base_filters and view.view_filters then
    combined_filters = {
      ['and'] = {
        view.base_filters,
        view.view_filters,
      }
    }
  elseif view.base_filters then
    combined_filters = view.base_filters
  elseif view.view_filters then
    combined_filters = view.view_filters
  end

  M.browse_tasks({
    filter = combined_filters and { bases_filters = combined_filters } or nil,
    view_name = view.name,
  })
end

-- Show view selector
function M.show_view_selector()
  local views_dir = config.get_views_dir()

  local all_views, err = bases.list_views(views_dir, { view_type = "tasknotesTaskList" })
  if err then
    vim.notify("Failed to load views: " .. err, vim.log.levels.ERROR)
    return
  end

  -- Convert views to picker items
  local items = {}
  for view_id, view in pairs(all_views) do
    table.insert(items, {
      text = string.format("%-30s [%s]", view.name, view.description or ""),
      view_id = view_id,
      search = view.name .. " " .. (view.description or ""),
    })
  end

  -- Sort items alphabetically by name
  table.sort(items, function(a, b)
    return a.text < b.text
  end)

  if #items == 0 then
    vim.notify("No Bases views found in " .. views_dir, vim.log.levels.WARN)
    return
  end

  snacks.picker.pick({
    prompt = "Select TaskNotes View",
    items = items,
    format = function(item)
      return { { item.text, "SnacksPickerNormal" } }
    end,
    preview = function(ctx)
      -- No preview for view selector items (they don't have files)
      return nil
    end,
    actions = {
      confirm = function(picker)
        local items = picker:selected({ fallback = true })
        if #items > 0 then
          local item = items[1]
          if item.view_id then
            picker:close()
            M.browse_by_view(item.view_id)
          end
        end
      end,
    },
  })
end

-- Setup function (no-op for Snacks, but kept for compatibility)
function M.setup()
  -- Snacks doesn't require explicit extension registration
  return true
end

return M
