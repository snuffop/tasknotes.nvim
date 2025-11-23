local M = {}

local config = require("tasknotes.config")
local parser = require("tasknotes.parser")
local cache_module = require("tasknotes.cache")

-- Task cache
M.tasks = {}
M.tasks_by_path = {}

-- Helper to handle vim.NIL from YAML parser
local function normalize_value(value, default)
  if value == nil or value == vim.NIL then
    return default
  end
  return value
end

-- Check if a file is a task file based on identification method
local function is_task_file(frontmatter)
  local opts = config.get()

  if opts.task_identification_method == "property" then
    -- Check if specific property matches value
    local prop_value = frontmatter[opts.task_property_name]
    return prop_value == opts.task_property_value
  else
    -- Check if tags array contains task tag
    if not frontmatter.tags then
      return false
    end

    local tags = frontmatter.tags
    if type(tags) == "string" then
      tags = { tags }
    end

    for _, tag in ipairs(tags) do
      if tag == opts.task_tag or tag:match("^" .. opts.task_tag .. "/") then
        return true
      end
    end
  end

  return false
end

-- Scan vault and discover all task files
function M.scan_vault()
  local opts = config.get()
  local vault_path = opts.vault_path

  if vim.fn.isdirectory(vault_path) == 0 then
    vim.notify("TaskNotes vault not found: " .. vault_path, vim.log.levels.ERROR)
    return
  end

  -- Find all markdown files
  local find_cmd = string.format("find '%s' -type f -name '*.md'", vault_path)
  local files = vim.fn.systemlist(find_cmd)

  -- Create a set of all current files for quick lookup
  local current_files = {}
  for _, filepath in ipairs(files) do
    current_files[filepath] = true
  end

  M.tasks = {}
  M.tasks_by_path = {}

  -- Try to load cache if enabled
  local persistent_cache = nil
  local cache_path = nil
  local files_parsed = 0
  local files_from_cache = 0

  if opts.cache.enabled then
    cache_path = vault_path .. "/" .. opts.cache.filename
    persistent_cache, err = cache_module.load(cache_path)

    if persistent_cache then
      vim.notify("Loaded task cache, checking for changes...", vim.log.levels.INFO)
    else
      vim.notify("Cache not found or invalid (" .. (err or "unknown error") .. "), performing full scan", vim.log.levels.INFO)
      persistent_cache = cache_module.new()
    end
  else
    persistent_cache = cache_module.new()
  end

  -- Process all files
  for _, filepath in ipairs(files) do
    local cached_entry = persistent_cache.tasks[filepath]
    local current_mtime = cache_module.get_mtime(filepath)

    -- Check if we can use cached data
    if cached_entry and cached_entry.mtime == current_mtime then
      -- File hasn't changed, use cached task object
      local task = cached_entry.task
      if task then
        table.insert(M.tasks, task)
        M.tasks_by_path[filepath] = task
        files_from_cache = files_from_cache + 1
      end
    else
      -- File is new or changed, parse it
      local parsed = parser.parse_file(filepath)
      if parsed and parsed.frontmatter then
        if is_task_file(parsed.frontmatter) then
          local task = M.create_task_object(filepath, parsed.frontmatter, parsed.body)
          table.insert(M.tasks, task)
          M.tasks_by_path[filepath] = task

          -- Update cache
          persistent_cache.tasks[filepath] = {
            mtime = current_mtime,
            task = task,
          }
          files_parsed = files_parsed + 1
        else
          -- Not a task file, remove from cache if present
          persistent_cache.tasks[filepath] = nil
        end
      else
        -- Failed to parse, remove from cache if present
        persistent_cache.tasks[filepath] = nil
      end
    end
  end

  -- Remove deleted files from cache
  for cached_filepath, _ in pairs(persistent_cache.tasks) do
    if not current_files[cached_filepath] then
      persistent_cache.tasks[cached_filepath] = nil
    end
  end

  -- Save updated cache
  if opts.cache.enabled and cache_path then
    local success, err = cache_module.save(cache_path, persistent_cache)
    if not success then
      vim.notify("Failed to save cache: " .. (err or "unknown error"), vim.log.levels.WARN)
    end
  end

  if files_from_cache > 0 then
    vim.notify(
      string.format("Found %d tasks (%d from cache, %d parsed)", #M.tasks, files_from_cache, files_parsed),
      vim.log.levels.INFO
    )
  else
    vim.notify(string.format("Found %d tasks", #M.tasks), vim.log.levels.INFO)
  end
end

-- Create a task object from frontmatter
function M.create_task_object(filepath, frontmatter, body)
  local opts = config.get()
  local fm = opts.field_mapping

  -- Extract mapped fields with proper vim.NIL handling
  local task = {
    path = filepath,
    title = normalize_value(frontmatter[fm.title], ""),
    status = normalize_value(frontmatter[fm.status], "open"),
    priority = normalize_value(frontmatter[fm.priority], "none"),
    due = normalize_value(frontmatter[fm.due], nil),
    scheduled = normalize_value(frontmatter[fm.scheduled], nil),
    contexts = normalize_value(frontmatter[fm.contexts], {}),
    projects = normalize_value(frontmatter[fm.projects], {}),
    tags = normalize_value(frontmatter[fm.tags], {}),
    timeEstimate = normalize_value(frontmatter[fm.timeEstimate], nil),
    timeEntries = normalize_value(frontmatter[fm.timeEntries], {}),
    completedDate = normalize_value(frontmatter[fm.completedDate], nil),
    dateCreated = normalize_value(frontmatter[fm.dateCreated], nil),
    dateModified = normalize_value(frontmatter[fm.dateModified], nil),
    body = body or "",
  }

  -- Ensure arrays are arrays
  if type(task.contexts) == "string" then
    task.contexts = { task.contexts }
  end
  if type(task.projects) == "string" then
    task.projects = { task.projects }
  end
  if type(task.tags) == "string" then
    task.tags = { task.tags }
  end

  -- Calculate total tracked time
  task.totalTrackedTime = M.calculate_total_time(task.timeEntries)

  return task
end

-- Calculate total tracked time from time entries
function M.calculate_total_time(time_entries)
  if not time_entries or #time_entries == 0 then
    return 0
  end

  local total = 0
  for _, entry in ipairs(time_entries) do
    if entry.duration then
      total = total + entry.duration
    elseif entry.startTime and entry.endTime then
      -- Parse ISO timestamps and calculate duration
      local start_time = M.parse_iso_timestamp(entry.startTime)
      local end_time = M.parse_iso_timestamp(entry.endTime)
      if start_time and end_time then
        total = total + math.floor((end_time - start_time) / 60)
      end
    end
  end

  return total
end

-- Parse ISO 8601 timestamp to Unix time
function M.parse_iso_timestamp(iso_str)
  -- Basic ISO parser (handles YYYY-MM-DDTHH:MM:SSZ format)
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = iso_str:match(pattern)

  if year then
    return os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = tonumber(hour),
      min = tonumber(min),
      sec = tonumber(sec),
    })
  end

  return nil
end

-- Get all tasks (optionally filtered)
function M.get_tasks(filter)
  if not filter then
    return M.tasks
  end

  local filtered = {}
  for _, task in ipairs(M.tasks) do
    local matches = true

    if filter.status and task.status ~= filter.status then
      matches = false
    end

    if filter.priority and task.priority ~= filter.priority then
      matches = false
    end

    if filter.context then
      local has_context = false
      for _, ctx in ipairs(task.contexts) do
        if ctx == filter.context then
          has_context = true
          break
        end
      end
      if not has_context then
        matches = false
      end
    end

    if filter.project then
      local has_project = false
      for _, proj in ipairs(task.projects) do
        if proj:match(filter.project) then
          has_project = true
          break
        end
      end
      if not has_project then
        matches = false
      end
    end

    if matches then
      table.insert(filtered, task)
    end
  end

  return filtered
end

-- Get task by filepath
function M.get_task_by_path(filepath)
  return M.tasks_by_path[filepath]
end

-- Create a new task
function M.create_task(task_data)
  local opts = config.get()
  local fm = opts.field_mapping

  -- Generate filename from title
  local filename = task_data.title:gsub("%s+", "-"):gsub("[^%w%-]", ""):lower() .. ".md"
  local filepath = opts.vault_path .. "/" .. filename

  -- Check if file already exists
  if vim.fn.filereadable(filepath) == 1 then
    vim.notify("Task file already exists: " .. filename, vim.log.levels.ERROR)
    return nil
  end

  -- Build frontmatter
  local frontmatter = {}
  frontmatter[fm.title] = task_data.title
  frontmatter[fm.status] = task_data.status or "open"
  frontmatter[fm.priority] = task_data.priority or "none"
  frontmatter[fm.due] = task_data.due
  frontmatter[fm.scheduled] = task_data.scheduled
  frontmatter[fm.contexts] = task_data.contexts or {}
  frontmatter[fm.projects] = task_data.projects or {}
  frontmatter[fm.tags] = task_data.tags or { opts.task_tag }
  frontmatter[fm.timeEstimate] = task_data.timeEstimate
  frontmatter[fm.dateCreated] = os.date("!%Y-%m-%dT%H:%M:%SZ")
  frontmatter[fm.dateModified] = frontmatter[fm.dateCreated]

  -- Write file
  local success, err = parser.write_file(filepath, frontmatter, task_data.body or "")
  if not success then
    vim.notify(err, vim.log.levels.ERROR)
    return nil
  end

  -- Add to cache
  local task = M.create_task_object(filepath, frontmatter, task_data.body)
  table.insert(M.tasks, task)
  M.tasks_by_path[filepath] = task

  vim.notify("Created task: " .. filename, vim.log.levels.INFO)
  return task
end

-- Update an existing task
function M.update_task(filepath, updates)
  local parsed = parser.parse_file(filepath)
  if not parsed then
    vim.notify("Could not read task file: " .. filepath, vim.log.levels.ERROR)
    return false
  end

  local opts = config.get()
  local fm = opts.field_mapping

  -- Update frontmatter fields
  for key, value in pairs(updates) do
    local fm_key = fm[key] or key
    parsed.frontmatter[fm_key] = value
  end

  -- Update modification date
  parsed.frontmatter[fm.dateModified] = os.date("!%Y-%m-%dT%H:%M:%SZ")

  -- Write back to file
  local success, err = parser.write_file(filepath, parsed.frontmatter, parsed.body)
  if not success then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  -- Update in-memory cache
  local task = M.create_task_object(filepath, parsed.frontmatter, parsed.body)
  M.tasks_by_path[filepath] = task

  -- Update in tasks array
  for i, t in ipairs(M.tasks) do
    if t.path == filepath then
      M.tasks[i] = task
      break
    end
  end

  -- Update persistent cache
  update_cache_file(filepath, task)

  return true
end

-- Delete a task
function M.delete_task(filepath)
  -- Remove file
  local success = os.remove(filepath)
  if not success then
    vim.notify("Could not delete task file: " .. filepath, vim.log.levels.ERROR)
    return false
  end

  -- Remove from in-memory cache
  M.tasks_by_path[filepath] = nil
  for i, task in ipairs(M.tasks) do
    if task.path == filepath then
      table.remove(M.tasks, i)
      break
    end
  end

  -- Remove from persistent cache
  update_cache_file(filepath, nil)

  vim.notify("Deleted task", vim.log.levels.INFO)
  return true
end

-- Helper function to update cache file
local function update_cache_file(filepath, task)
  local opts = config.get()
  if not opts.cache.enabled then
    return
  end

  local vault_path = opts.vault_path
  local cache_path = vault_path .. "/" .. opts.cache.filename

  -- Load existing cache
  local persistent_cache = cache_module.load(cache_path)
  if not persistent_cache then
    persistent_cache = cache_module.new()
  end

  -- Update cache entry
  if task then
    local mtime = cache_module.get_mtime(filepath)
    persistent_cache.tasks[filepath] = {
      mtime = mtime,
      task = task,
    }
  else
    -- Remove from cache
    persistent_cache.tasks[filepath] = nil
  end

  -- Save cache
  cache_module.save(cache_path, persistent_cache)
end

-- Refresh a single task from disk
function M.refresh_task(filepath)
  local parsed = parser.parse_file(filepath)
  if not parsed or not parsed.frontmatter then
    return false
  end

  if not is_task_file(parsed.frontmatter) then
    return false
  end

  local task = M.create_task_object(filepath, parsed.frontmatter, parsed.body)
  M.tasks_by_path[filepath] = task

  -- Update in tasks array
  local found = false
  for i, t in ipairs(M.tasks) do
    if t.path == filepath then
      M.tasks[i] = task
      found = true
      break
    end
  end

  if not found then
    table.insert(M.tasks, task)
  end

  -- Update cache
  update_cache_file(filepath, task)

  return true
end

return M
