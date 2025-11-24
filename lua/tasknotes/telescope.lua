local M = {}

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  return M
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

local task_manager = require("tasknotes.task_manager")
local config = require("tasknotes.config")

-- Helper function to safely convert values to strings (handles vim.NIL)
local function safe_string(value)
  if value == nil or value == vim.NIL then
    return ""
  end
  return tostring(value)
end

-- Format task for display
local function make_display(opts)
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 40 },
      { width = 12 },
      { width = 10 },
      { width = 12 },
      { remaining = true },
    },
  })

  return function(entry)
    local task = entry.value
    local opts = config.get()

    -- Get status and priority info
    local status_info = config.get_status(task.status)
    local priority_info = config.get_priority(task.priority)

    -- Check if task is completed and dimming is enabled
    local is_completed = status_info.is_completed
    local should_dim = is_completed and opts.telescope.dim_completed

    -- Choose highlight group based on completion status
    local title_hl = should_dim and "TaskNotesCompletedTitle" or "TelescopeResultsIdentifier"
    local status_hl = should_dim and "TaskNotesCompletedTitle" or "TelescopeResultsComment"
    local priority_hl = should_dim and "TaskNotesCompletedTitle" or "TelescopeResultsConstant"
    local due_hl = should_dim and "TaskNotesCompletedTitle" or "TelescopeResultsNumber"
    local contexts_hl = should_dim and "TaskNotesCompletedTitle" or "TelescopeResultsSpecialComment"

    -- Format due date
    local due_str = safe_string(task.due)

    -- Format contexts
    local contexts_str = table.concat(task.contexts or {}, ", ")

    return displayer({
      { safe_string(task.title), title_hl },
      { status_info.display, status_hl },
      { priority_info.display, priority_hl },
      { due_str, due_hl },
      { contexts_str, contexts_hl },
    })
  end
end

-- Create entry maker for tasks
local function make_entry(task)
  return {
    value = task,
    display = make_display(),
    ordinal = safe_string(task.title) .. " " .. safe_string(task.status) .. " " .. safe_string(task.due),
    path = task.path,
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

  pickers
    .new(opts, {
      prompt_title = "TaskNotes",
      finder = finders.new_table({
        results = tasks,
        entry_maker = make_entry,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.file_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        -- Default action: open file
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd("edit " .. selection.path)
          end
        end)

        -- Action: Mark as done
        map("i", "<C-d>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            task_manager.update_task(selection.path, {
              status = "done",
              completedDate = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            })
            vim.notify("Marked task as done", vim.log.levels.INFO)

            -- Refresh picker
            local current_picker = action_state.get_current_picker(prompt_bufnr)
            current_picker:refresh(finders.new_table({
              results = task_manager.get_tasks(opts.filter),
              entry_maker = make_entry,
            }), { reset_prompt = false })
          end
        end)

        -- Action: Edit metadata (open form)
        map("i", "<C-e>", function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            -- Open edit form (will be implemented in task_form.lua)
            local has_form, task_form = pcall(require, "tasknotes.ui.task_form")
            if has_form then
              task_form.edit_task(selection.value)
            else
              vim.notify("Task form not available", vim.log.levels.ERROR)
            end
          end
        end)

        -- Action: Delete task
        map("i", "<C-x>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            -- Confirm deletion
            vim.ui.select({ "Yes", "No" }, {
              prompt = "Delete task: " .. selection.value.title .. "?",
            }, function(choice)
              if choice == "Yes" then
                task_manager.delete_task(selection.path)

                -- Refresh picker
                local current_picker = action_state.get_current_picker(prompt_bufnr)
                current_picker:refresh(finders.new_table({
                  results = task_manager.get_tasks(opts.filter),
                  entry_maker = make_entry,
                }), { reset_prompt = false })
              end
            end)
          end
        end)

        -- Action: Toggle timer
        map("i", "<C-t>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            local has_tracker, time_tracker = pcall(require, "tasknotes.ui.time_tracker")
            if has_tracker then
              time_tracker.toggle_timer(selection.value)
            else
              vim.notify("Time tracker not available", vim.log.levels.ERROR)
            end
          end
        end)

        return true
      end,
    })
    :find()
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

-- Register Telescope extension
function M.setup()
  return telescope.register_extension({
    exports = {
      tasks = M.browse_tasks,
      by_status = M.browse_by_status,
      by_priority = M.browse_by_priority,
      by_context = M.browse_by_context,
    },
  })
end

return M
