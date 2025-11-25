-- Urgency scoring system for tasknotes.nvim
-- Based on Taskwarrior's urgency algorithm: https://taskwarrior.org/docs/urgency/

local M = {}

-- Parse ISO date string to timestamp
-- @param date_str string in ISO format (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ)
-- @return number timestamp or nil
local function parse_iso_date(date_str)
  if not date_str or date_str == "" then
    return nil
  end

  -- Handle both date-only and full ISO timestamp formats
  local year, month, day = date_str:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
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

-- Calculate days between two timestamps
-- @param date_str string ISO date
-- @param now number current timestamp
-- @return number days (negative if in past)
local function days_until(date_str, now)
  local target = parse_iso_date(date_str)
  if not target then
    return nil
  end

  local diff_seconds = target - now
  return diff_seconds / (24 * 60 * 60)
end

-- Calculate urgency component for due date proximity
-- Returns 0.0 to 1.0 based on how soon the task is due
-- @param due_date string ISO date
-- @param config table urgency configuration
-- @param now number current timestamp
-- @return number urgency component (0.0-1.0)
local function calculate_due_urgency(due_date, config, now)
  if not due_date then
    return 0.0
  end

  local days = days_until(due_date, now)
  if not days then
    return 0.0
  end

  -- Overdue tasks get full urgency
  if days < 0 then
    return 1.0
  end

  -- Scale from 1.0 (due today) to 0.0 (due far in future)
  local max_days = config.urgency.date_scaling.due_max_days
  return math.max(0.0, 1.0 - (days / max_days))
end

-- TODO: Implement scheduled date urgency
-- Calculate urgency component for scheduled date proximity
-- @param scheduled_date string ISO date
-- @param config table urgency configuration
-- @param now number current timestamp
-- @return number urgency component (0.0-1.0)
local function calculate_scheduled_urgency(scheduled_date, config, now)
  -- PLACEHOLDER: To be implemented
  -- Should work similar to due date but with different scaling
  -- Tasks scheduled today or in the past get urgency boost
  return 0.0
end

-- Calculate urgency component for task age
-- Older tasks that haven't been completed should get more urgent
-- @param created_date string ISO date
-- @param config table urgency configuration
-- @param now number current timestamp
-- @return number urgency component (0.0-1.0)
local function calculate_age_urgency(created_date, config, now)
  if not created_date then
    return 0.0
  end

  local created_timestamp = parse_iso_date(created_date)
  if not created_timestamp then
    return 0.0
  end

  -- Calculate days since creation
  local age_seconds = now - created_timestamp
  local age_days = age_seconds / (24 * 60 * 60)

  -- Scale from 0.0 (new) to 1.0 (max age)
  local max_days = config.urgency.date_scaling.age_max_days
  return math.min(1.0, age_days / max_days)
end

-- Calculate priority urgency component
-- @param priority string priority level
-- @param config table urgency configuration
-- @return number urgency value
local function calculate_priority_urgency(priority, config)
  local c = config.urgency.coefficients

  if priority == "high" then
    return c.priority_high
  elseif priority == "normal" then
    return c.priority_normal
  elseif priority == "low" then
    return c.priority_low
  else
    return 0.0
  end
end

-- Calculate blocking urgency component
-- Tasks that block other tasks are more urgent
-- @param task table task object
-- @param config table urgency configuration
-- @return number urgency value
local function calculate_blocking_urgency(task, config)
  local task_manager = require("tasknotes.task_manager")
  local blocked_tasks = task_manager.get_blocked_tasks(task)
  local count = #blocked_tasks

  return count * config.urgency.coefficients.blocking_count
end

-- Check if task is blocked by incomplete dependencies
-- @param task table task object
-- @param config table urgency configuration
-- @return number urgency penalty (negative)
local function calculate_blocked_penalty(task, config)
  local task_manager = require("tasknotes.task_manager")
  local is_blocked = task_manager.is_task_blocked(task)

  if is_blocked then
    return config.urgency.coefficients.is_blocked
  end

  return 0.0
end

-- TODO: Implement tag-based urgency
-- Calculate urgency based on number and type of tags
-- @param tags table array of tag strings
-- @param config table urgency configuration
-- @return number urgency value
local function calculate_tag_urgency(tags, config)
  -- PLACEHOLDER: To be implemented
  -- Should scale 0.8/0.9/1.0 based on tag count (1/2/3+)
  -- Exclude "task" tag from count
  return 0.0
end

-- TODO: Implement project-based urgency
-- Calculate urgency based on project associations
-- @param projects table array of project links
-- @param config table urgency configuration
-- @return number urgency value
local function calculate_project_urgency(projects, config)
  -- PLACEHOLDER: To be implemented
  -- Should scale 0.8/0.9/1.0 based on project count
  return 0.0
end

-- TODO: Implement context-based urgency
-- Calculate urgency based on context assignments
-- @param contexts table array of context strings
-- @param config table urgency configuration
-- @return number urgency value
local function calculate_context_urgency(contexts, config)
  -- PLACEHOLDER: To be implemented
  return 0.0
end

-- TODO: Implement time estimate urgency
-- Tasks with time estimates show planning and may be more urgent
-- @param time_estimate number minutes or nil
-- @param config table urgency configuration
-- @return number urgency value
local function calculate_estimate_urgency(time_estimate, config)
  -- PLACEHOLDER: To be implemented
  return 0.0
end

-- Calculate total urgency score for a task
-- @param task table task object
-- @param config table configuration (from config.get())
-- @param now number optional current timestamp (defaults to os.time())
-- @param skip_dependencies boolean optional flag to skip dependency calculations (for initial load)
-- @return number urgency score
function M.calculate_urgency(task, config, now, skip_dependencies)
  now = now or os.time()
  skip_dependencies = skip_dependencies or false
  local score = 0.0
  local c = config.urgency.coefficients

  -- Early exit for completed tasks (should be filtered anyway)
  local status_def = require("tasknotes.config").get_status(task.status)
  if status_def.is_completed then
    return -100.0
  end

  -- CORE FACTORS (implemented)

  -- Due date urgency (weighted)
  local due_component = calculate_due_urgency(task.due, config, now)
  score = score + (due_component * c.due_proximity)

  -- Priority urgency
  score = score + calculate_priority_urgency(task.priority, config)

  -- Status: in-progress tasks are more urgent
  if task.status == "in-progress" then
    score = score + c.in_progress
  end

  -- Dependency factors (skip during initial load to avoid circular dependency)
  if not skip_dependencies then
    score = score + calculate_blocking_urgency(task, config)
    score = score + calculate_blocked_penalty(task, config)
  end

  -- Age-based urgency
  local age_component = calculate_age_urgency(task.dateCreated, config, now)
  score = score + (age_component * c.age)

  -- FUTURE FACTORS (TODOs)

  -- TODO: Uncomment when implemented
  -- local sched_component = calculate_scheduled_urgency(task.scheduled, config, now)
  -- score = score + (sched_component * c.scheduled_proximity)

  -- TODO: Uncomment when implemented
  -- score = score + calculate_tag_urgency(task.tags, config)
  -- score = score + calculate_project_urgency(task.projects, config)
  -- score = score + calculate_context_urgency(task.contexts, config)
  -- score = score + calculate_estimate_urgency(task.timeEstimate, config)

  return score
end

-- Sort tasks by urgency (descending)
-- @param tasks table array of task objects
-- @return table sorted array
function M.sort_by_urgency(tasks)
  local sorted = vim.deepcopy(tasks)
  table.sort(sorted, function(a, b)
    return (a.urgency or 0) > (b.urgency or 0)
  end)
  return sorted
end

-- Combine urgency score with Telescope fuzzy match score
-- Used for weighted sorting that considers both relevance and urgency
-- @param urgency_score number task urgency score
-- @param fuzzy_score number telescope fuzzy match score (lower is better)
-- @param config table configuration
-- @return number combined score (lower is better for Telescope)
function M.combine_with_fuzzy_score(urgency_score, fuzzy_score, config)
  -- Normalize urgency to 0-100 range (typical urgency scores are 0-30)
  local normalized_urgency = math.min(urgency_score, 30) / 30 * 100

  -- Invert urgency since Telescope uses lower=better
  -- High urgency (30) -> low score (0)
  -- Low urgency (0) -> high score (100)
  local inverted_urgency = 100 - normalized_urgency

  -- Weight: 70% urgency, 30% fuzzy matching
  -- This prioritizes urgency but still allows search to influence results
  return (inverted_urgency * 0.7) + (fuzzy_score * 0.3)
end

return M
