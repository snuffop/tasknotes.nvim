local M = {}

-- Default configuration
local defaults = {
  -- Path to TaskNotes vault directory
  vault_path = vim.fn.expand("~/notes/tasks"),

  -- Obsidian integration
  obsidian = {
    enabled = false,  -- Set to true to auto-import settings from Obsidian
    vault_path = vim.fn.expand("~/sync/vault"),  -- Path to Obsidian vault
  },

  -- Task identification method
  task_identification_method = "tag", -- "tag" or "property"
  task_tag = "task",
  task_property_name = "type",
  task_property_value = "task",

  -- Field mapping (internal name -> frontmatter property name)
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
    recurrence = "recurrence",
    recurrence_anchor = "recurrence_anchor",
    complete_instances = "complete_instances",
    skipped_instances = "skipped_instances",
  },

  -- Status definitions
  statuses = {
    { name = "none", display = "None", color = "#cccccc", is_completed = false },
    { name = "open", display = "Open", color = "#808080", is_completed = false },
    { name = "in-progress", display = "In Progress", color = "#0066cc", is_completed = false },
    { name = "done", display = "Done", color = "#00aa00", is_completed = true },
  },

  -- Priority definitions
  priorities = {
    { name = "none", display = "None", color = "#cccccc", weight = 0 },
    { name = "low", display = "Low", color = "#00aa00", weight = 1 },
    { name = "normal", display = "Normal", color = "#ffaa00", weight = 2 },
    { name = "high", display = "High", color = "#ff0000", weight = 3 },
  },

  -- UI configuration
  ui = {
    border_style = "rounded", -- "rounded", "single", "double", "solid"
    task_form_width = 60,
    task_form_height = 20,
    time_tracker_width = 50,
    time_tracker_height = 15,
  },

  -- Telescope configuration
  telescope = {
    enabled = true,
    theme = "dropdown",
    dim_completed = true, -- Grey out completed tasks in the picker
  },

  -- Time tracking
  time_tracking = {
    enabled = true,
    auto_save_interval = 60, -- seconds
  },

  -- Cache configuration
  cache = {
    enabled = true,
    filename = ".tasknotes_cache.json", -- Cache file name in vault directory
    validate_on_startup = false, -- Skip validation on startup for faster loading
    background_validation_delay = 500, -- ms to wait before background validation
    validation_interval = 300, -- seconds between validations (5 minutes)
  },

  -- Keymaps
  keymaps = {
    browse = "<leader>tb",
    new_task = "<leader>tn",
    edit_task = "<leader>te",
    toggle_timer = "<leader>tt",
  },
}

-- Current configuration
M.options = {}

-- Setup function
function M.setup(user_config)
  M.options = vim.tbl_deep_extend("force", defaults, user_config or {})

  -- Expand vault path
  M.options.vault_path = vim.fn.expand(M.options.vault_path)

  -- Ensure vault directory exists
  if vim.fn.isdirectory(M.options.vault_path) == 0 then
    vim.notify(
      string.format("TaskNotes vault directory does not exist: %s", M.options.vault_path),
      vim.log.levels.WARN
    )
  end
end

-- Get current configuration
function M.get()
  return M.options
end

-- Get status definition by name
function M.get_status(name)
  for _, status in ipairs(M.options.statuses) do
    if status.name == name then
      return status
    end
  end
  return M.options.statuses[1] -- default to first
end

-- Get priority definition by name
function M.get_priority(name)
  for _, priority in ipairs(M.options.priorities) do
    if priority.name == name then
      return priority
    end
  end
  return M.options.priorities[1] -- default to first
end

-- Get field mapping
function M.get_field(internal_name)
  return M.options.field_mapping[internal_name] or internal_name
end

return M
