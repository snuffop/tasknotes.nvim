-- Example configuration for tasknotes.nvim
-- Copy this to your Neovim configuration and customize as needed

require("tasknotes").setup({
  -- ========================================================================
  -- BASIC CONFIGURATION
  -- ========================================================================

  -- Path to your TaskNotes vault directory
  vault_path = "~/notes/tasks",

  -- How to identify task files
  task_identification_method = "tag", -- "tag" or "property"
  task_tag = "task",

  -- Alternative: identify by property
  -- task_identification_method = "property",
  -- task_property_name = "type",
  -- task_property_value = "task",

  -- ========================================================================
  -- FIELD MAPPING
  -- ========================================================================
  -- Customize if your vault uses different property names

  field_mapping = {
    title = "title",
    status = "status",
    priority = "priority",
    due = "due",
    scheduled = "scheduled",
    contexts = "contexts",
    projects = "projects",
    tags = "tags",
    timeEstimate = "timeEstimate",
    timeEntries = "timeEntries",
    completedDate = "completedDate",
    dateCreated = "dateCreated",
    dateModified = "dateModified",
  },

  -- Example: Using different field names
  -- field_mapping = {
  --   title = "name",
  --   status = "state",
  --   priority = "importance",
  --   due = "dueDate",
  --   scheduled = "scheduledDate",
  -- },

  -- ========================================================================
  -- STATUS DEFINITIONS
  -- ========================================================================

  statuses = {
    { name = "none", display = "None", color = "#cccccc", is_completed = false },
    { name = "open", display = "Open", color = "#808080", is_completed = false },
    { name = "in-progress", display = "In Progress", color = "#0066cc", is_completed = false },
    { name = "done", display = "Done", color = "#00aa00", is_completed = true },
  },

  -- Example: Custom statuses
  -- statuses = {
  --   { name = "backlog", display = "Backlog", color = "#666666", is_completed = false },
  --   { name = "todo", display = "To Do", color = "#0066cc", is_completed = false },
  --   { name = "doing", display = "Doing", color = "#ffaa00", is_completed = false },
  --   { name = "review", display = "Review", color = "#aa00ff", is_completed = false },
  --   { name = "done", display = "Done", color = "#00aa00", is_completed = true },
  --   { name = "cancelled", display = "Cancelled", color = "#ff0000", is_completed = true },
  -- },

  -- ========================================================================
  -- PRIORITY DEFINITIONS
  -- ========================================================================

  priorities = {
    { name = "none", display = "None", color = "#cccccc", weight = 0 },
    { name = "low", display = "Low", color = "#00aa00", weight = 1 },
    { name = "normal", display = "Normal", color = "#ffaa00", weight = 2 },
    { name = "high", display = "High", color = "#ff0000", weight = 3 },
  },

  -- Example: 5-level priority system
  -- priorities = {
  --   { name = "none", display = "None", color = "#cccccc", weight = 0 },
  --   { name = "very-low", display = "Very Low", color = "#00ccff", weight = 1 },
  --   { name = "low", display = "Low", color = "#00aa00", weight = 2 },
  --   { name = "medium", display = "Medium", color = "#ffaa00", weight = 3 },
  --   { name = "high", display = "High", color = "#ff6600", weight = 4 },
  --   { name = "critical", display = "Critical", color = "#ff0000", weight = 5 },
  -- },

  -- ========================================================================
  -- UI CONFIGURATION
  -- ========================================================================

  ui = {
    border_style = "rounded", -- "rounded", "single", "double", "solid", "shadow"
    task_form_width = 60,
    task_form_height = 20,
    time_tracker_width = 50,
    time_tracker_height = 15,
  },

  -- ========================================================================
  -- TELESCOPE CONFIGURATION
  -- ========================================================================

  telescope = {
    enabled = true,
    theme = "dropdown", -- "dropdown", "ivy", "cursor", or nil for default
  },

  -- ========================================================================
  -- TIME TRACKING
  -- ========================================================================

  time_tracking = {
    enabled = true,
    auto_save_interval = 60, -- seconds (how often to refresh active timer state)
  },

  -- ========================================================================
  -- KEYMAPS
  -- ========================================================================

  keymaps = {
    browse = "<leader>tb",       -- Browse tasks
    new_task = "<leader>tn",     -- Create new task
    edit_task = "<leader>te",    -- Edit current task
    toggle_timer = "<leader>tt", -- Toggle timer
  },

  -- Example: Disable keymaps and set them manually
  -- keymaps = {
  --   browse = false,
  --   new_task = false,
  --   edit_task = false,
  --   toggle_timer = false,
  -- },
})

-- ============================================================================
-- ADDITIONAL KEYMAPS
-- ============================================================================
-- Uncomment and customize these if you disabled automatic keymaps above

-- vim.keymap.set("n", "<leader>tb", ":TaskNotesBrowse<CR>", { desc = "Browse TaskNotes" })
-- vim.keymap.set("n", "<leader>tn", ":TaskNotesNew<CR>", { desc = "New TaskNote" })
-- vim.keymap.set("n", "<leader>te", ":TaskNotesEdit<CR>", { desc = "Edit TaskNote" })
-- vim.keymap.set("n", "<leader>tt", ":TaskNotesTimerToggle<CR>", { desc = "Toggle Timer" })
-- vim.keymap.set("n", "<leader>ts", ":TaskNotesTimerStatus<CR>", { desc = "Timer Status" })
-- vim.keymap.set("n", "<leader>tr", ":TaskNotesRescan<CR>", { desc = "Rescan Tasks" })

-- Filter shortcuts
-- vim.keymap.set("n", "<leader>tbo", function()
--   require("tasknotes").browse_tasks({ filter = { status = "open" } })
-- end, { desc = "Browse Open Tasks" })

-- vim.keymap.set("n", "<leader>tbd", function()
--   require("tasknotes").browse_tasks({ filter = { status = "done" } })
-- end, { desc = "Browse Done Tasks" })

-- vim.keymap.set("n", "<leader>tbh", function()
--   require("tasknotes").browse_tasks({ filter = { priority = "high" } })
-- end, { desc = "Browse High Priority Tasks" })

-- ============================================================================
-- STATUSLINE INTEGRATION
-- ============================================================================
-- Example integration with lualine

-- require('lualine').setup({
--   sections = {
--     lualine_x = {
--       -- Show active timer in statusline
--       function()
--         return require('tasknotes').statusline()
--       end,
--     },
--   },
-- })

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
-- Example: Auto-rescan vault when TaskNotes files are saved

-- vim.api.nvim_create_autocmd("BufWritePost", {
--   pattern = vim.fn.expand("~/notes/tasks") .. "/*.md",
--   callback = function()
--     require("tasknotes").rescan()
--   end,
-- })

-- ============================================================================
-- TELESCOPE INTEGRATION
-- ============================================================================
-- Use Telescope extension directly

-- vim.keymap.set("n", "<leader>ft", ":Telescope tasknotes tasks<CR>", { desc = "Find Tasks" })

-- ============================================================================
-- ADVANCED: PROGRAMMATIC ACCESS
-- ============================================================================
-- Examples of using the tasknotes API programmatically

-- Get all open high-priority tasks
-- local tasknotes = require("tasknotes")
-- local high_priority_tasks = vim.tbl_filter(function(task)
--   return task.status == "open" and task.priority == "high"
-- end, tasknotes.task_manager.get_tasks())

-- Create a task programmatically
-- tasknotes.task_manager.create_task({
--   title = "Review code",
--   status = "open",
--   priority = "high",
--   due = "2025-08-20",
--   contexts = { "@work" },
--   tags = { "task", "code-review" },
-- })

-- Update a task
-- local task = tasknotes.task_manager.get_task_by_path("~/notes/tasks/my-task.md")
-- tasknotes.task_manager.update_task(task.path, {
--   status = "done",
--   completedDate = os.date("!%Y-%m-%dT%H:%M:%SZ"),
-- })
