-- Obsidian TaskNotes settings importer
-- Parses Obsidian's data.json and maps to tasknotes.nvim config
local M = {}

-- Parse Obsidian TaskNotes data.json file
function M.parse_obsidian_settings(obsidian_vault_path)
  local settings_path = obsidian_vault_path .. "/.obsidian/plugins/tasknotes/data.json"

  -- Check if file exists
  if vim.fn.filereadable(settings_path) == 0 then
    return nil, "Obsidian TaskNotes settings not found at: " .. settings_path
  end

  -- Read JSON file
  local file = io.open(settings_path, "r")
  if not file then
    return nil, "Could not read settings file"
  end

  local content = file:read("*all")
  file:close()

  -- Parse JSON
  local ok, obsidian_settings = pcall(vim.fn.json_decode, content)
  if not ok then
    return nil, "Failed to parse JSON settings"
  end

  return obsidian_settings, nil
end

-- Map Obsidian settings to tasknotes.nvim config format
function M.map_to_nvim_config(obsidian_settings, vault_path)
  local config = {}

  -- Vault path (combine vault path with tasks folder)
  local tasks_folder = obsidian_settings.tasksFolder or "Tasks"
  config.vault_path = vault_path .. "/" .. tasks_folder

  -- Obsidian integration settings
  -- Parse excludedFolders (comma-separated string) into array
  local excluded_folders = {}
  if obsidian_settings.excludedFolders and obsidian_settings.excludedFolders ~= "" then
    for folder in obsidian_settings.excludedFolders:gmatch("([^,]+)") do
      table.insert(excluded_folders, vim.trim(folder))
    end
  end

  config.obsidian = {
    ignore_dirs = excluded_folders,
  }

  -- Task identification
  config.task_identification_method = obsidian_settings.taskIdentificationMethod or "tag"
  config.task_tag = obsidian_settings.taskTag or "task"
  config.task_property_name = obsidian_settings.taskPropertyName or "type"
  config.task_property_value = obsidian_settings.taskPropertyValue or "task"

  -- Field mapping
  if obsidian_settings.fieldMapping then
    config.field_mapping = {
      title = obsidian_settings.fieldMapping.title or "title",
      status = obsidian_settings.fieldMapping.status or "status",
      priority = obsidian_settings.fieldMapping.priority or "priority",
      due = obsidian_settings.fieldMapping.due or "due",
      scheduled = obsidian_settings.fieldMapping.scheduled or "scheduled",
      contexts = obsidian_settings.fieldMapping.contexts or "contexts",
      projects = obsidian_settings.fieldMapping.projects or "projects",
      tags = "tags",
      timeEstimate = obsidian_settings.fieldMapping.timeEstimate or "timeEstimate",
      timeEntries = obsidian_settings.fieldMapping.timeEntries or "timeEntries",
      completedDate = obsidian_settings.fieldMapping.completedDate or "completedDate",
      dateCreated = obsidian_settings.fieldMapping.dateCreated or "dateCreated",
      dateModified = obsidian_settings.fieldMapping.dateModified or "dateModified",
    }
  end

  -- Statuses
  if obsidian_settings.customStatuses then
    config.statuses = {}
    for _, status in ipairs(obsidian_settings.customStatuses) do
      table.insert(config.statuses, {
        name = status.value,
        display = status.label,
        color = status.color,
        is_completed = status.isCompleted or false,
      })
    end
  end

  -- Priorities
  if obsidian_settings.customPriorities then
    config.priorities = {}
    for _, priority in ipairs(obsidian_settings.customPriorities) do
      table.insert(config.priorities, {
        name = priority.value,
        display = priority.label,
        color = priority.color,
        weight = priority.weight or 0,
      })
    end
  end

  return config
end

-- Import settings from Obsidian vault
function M.import_from_obsidian(obsidian_vault_path)
  local obsidian_settings, err = M.parse_obsidian_settings(obsidian_vault_path)
  if not obsidian_settings then
    return nil, err
  end

  local nvim_config = M.map_to_nvim_config(obsidian_settings, obsidian_vault_path)
  return nvim_config, nil
end

return M
