-- Obsidian Bases expression evaluator for tasknotes.nvim
-- Evaluates filter expressions from .base files against task objects

local M = {}

-- Helper function to get current date
local function get_today()
  return os.date("%Y-%m-%d")
end

-- Helper function to parse date string
local function parse_date(date_str)
  if not date_str or date_str == "" then
    return nil
  end
  -- Extract YYYY-MM-DD from ISO date strings
  local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
  if year and month and day then
    return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0 })
  end
  return nil
end

-- Helper function to add days to a date
local function add_days_to_date(date_str, days)
  local timestamp = parse_date(date_str)
  if not timestamp then return nil end
  return os.date("%Y-%m-%d", timestamp + (days * 24 * 60 * 60))
end

-- Get property value from task object
-- Handles property paths like "note.type", "file.tags", "status", etc.
function M.get_property(task, prop_path, context)
  context = context or {}

  -- Handle special property paths
  if prop_path == "note.type" then
    return task.type
  elseif prop_path == "file.tags" then
    return task.tags or {}
  elseif prop_path == "file.basename" then
    if task.path then
      return vim.fn.fnamemodify(task.path, ":t:r")
    end
    return nil
  elseif prop_path == "file.ctime" then
    if task.dateCreated then
      return task.dateCreated
    end
    return nil
  elseif prop_path == "file.mtime" then
    if task.dateModified then
      return task.dateModified
    end
    return nil
  elseif prop_path:match("^note%.") then
    -- Handle note.* properties by stripping "note." prefix
    local prop_name = prop_path:sub(6) -- Remove "note."
    return task[prop_name]
  else
    -- Direct property access
    return task[prop_path]
  end
end

-- Evaluate a string expression like "status == 'done'"
function M.evaluate_string_expression(expr, task, context)
  -- Trim whitespace
  expr = expr:match("^%s*(.-)%s*$")

  -- Handle negation (leading !)
  local negated = false
  if expr:match("^!") or expr:match("^not%s+") then
    negated = true
    expr = expr:gsub("^!", ""):gsub("^not%s+", ""):match("^%s*(.-)%s*$")
  end

  -- Strip surrounding parentheses if present
  if expr:match("^%(.+%)$") then
    expr = expr:sub(2, -2):match("^%s*(.-)%s*$")
  end

  local result = false

  -- Pattern 1: property == "value" or property == 'value'
  local prop, value = expr:match("^([%w%.]+)%s*==%s*[\"']([^\"']+)[\"']$")
  if prop then
    result = (M.get_property(task, prop, context) == value)
    return negated and not result or result
  end

  -- Pattern 2: property != "value" or property != 'value'
  prop, value = expr:match("^([%w%.]+)%s*!=%s*[\"']([^\"']+)[\"']$")
  if prop then
    result = (M.get_property(task, prop, context) ~= value)
    return negated and not result or result
  end

  -- Pattern 3: property.isEmpty()
  prop = expr:match("^([%w%.]+)%.isEmpty%(%s*%)$")
  if prop then
    local val = M.get_property(task, prop, context)
    result = (val == nil or val == "" or val == vim.NIL or (type(val) == "table" and #val == 0))
    return negated and not result or result
  end

  -- Pattern 3b: property.isEmpty() != true (testing if NOT empty)
  prop = expr:match("^([%w%.]+)%.isEmpty%(%s*%)%s*!=%s*true$")
  if prop then
    local val = M.get_property(task, prop, context)
    result = (val == nil or val == "" or val == vim.NIL or (type(val) == "table" and #val == 0))
    -- Result of isEmpty != true means we want the opposite (not empty)
    result = not result
    return negated and not result or result
  end

  -- Pattern 3c: property.isEmpty() == false (testing if NOT empty)
  prop = expr:match("^([%w%.]+)%.isEmpty%(%s*%)%s*==%s*false$")
  if prop then
    local val = M.get_property(task, prop, context)
    result = (val == nil or val == "" or val == vim.NIL or (type(val) == "table" and #val == 0))
    -- Result of isEmpty == false means we want the opposite (not empty)
    result = not result
    return negated and not result or result
  end

  -- Pattern 4: property.contains("value") or property.contains('value')
  prop, value = expr:match("^([%w%.]+)%.contains%s*%([\"']([^\"']+)[\"']%s*%)$")
  if prop then
    local val = M.get_property(task, prop, context)
    if type(val) == "table" then
      for _, v in ipairs(val) do
        if v == value or tostring(v) == value then
          result = true
          break
        end
      end
    elseif type(val) == "string" then
      result = val:find(value, 1, true) ~= nil
    end
    return negated and not result or result
  end

  -- Pattern 4b: property.contains("value") != true (testing if contains returns false)
  prop, value = expr:match("^([%w%.]+)%.contains%s*%([\"']([^\"']+)[\"']%s*%)%s*!=%s*true$")
  if prop then
    local val = M.get_property(task, prop, context)
    if type(val) == "table" then
      for _, v in ipairs(val) do
        if v == value or tostring(v) == value then
          result = true
          break
        end
      end
    elseif type(val) == "string" then
      result = val:find(value, 1, true) ~= nil
    end
    -- Result of contains != true means we want the opposite
    result = not result
    return negated and not result or result
  end

  -- Pattern 4c: property.contains("value") == false
  prop, value = expr:match("^([%w%.]+)%.contains%s*%([\"']([^\"']+)[\"']%s*%)%s*==%s*false$")
  if prop then
    local val = M.get_property(task, prop, context)
    if type(val) == "table" then
      for _, v in ipairs(val) do
        if v == value or tostring(v) == value then
          result = true
          break
        end
      end
    elseif type(val) == "string" then
      result = val:find(value, 1, true) ~= nil
    end
    -- Result of contains == false means we want the opposite
    result = not result
    return negated and not result or result
  end

  -- Pattern 5: date(property) < today()
  local date_prop = expr:match("^date%s*%(([%w%.]+)%)%s*<%s*today%(%s*%)$")
  if date_prop then
    local prop_value = M.get_property(task, date_prop, context)
    if prop_value then
      local prop_date = parse_date(prop_value)
      local today_date = parse_date(get_today())
      result = prop_date and today_date and prop_date < today_date
    end
    return negated and not result or result
  end

  -- Pattern 6: date(property) == today()
  date_prop = expr:match("^date%s*%(([%w%.]+)%)%s*==%s*today%(%s*%)$")
  if date_prop then
    local prop_value = M.get_property(task, date_prop, context)
    if prop_value then
      local prop_date = parse_date(prop_value)
      local today_date = parse_date(get_today())
      result = prop_date and today_date and prop_date == today_date
    end
    return negated and not result or result
  end

  -- Pattern 7: date(property) <= today()
  date_prop = expr:match("^date%s*%(([%w%.]+)%)%s*<=%s*today%(%s*%)$")
  if date_prop then
    local prop_value = M.get_property(task, date_prop, context)
    if prop_value then
      local prop_date = parse_date(prop_value)
      local today_date = parse_date(get_today())
      result = prop_date and today_date and prop_date <= today_date
    end
    return negated and not result or result
  end

  -- Pattern 8: date(property) >= today()
  date_prop = expr:match("^date%s*%(([%w%.]+)%)%s*>=%s*today%(%s*%)$")
  if date_prop then
    local prop_value = M.get_property(task, date_prop, context)
    if prop_value then
      local prop_date = parse_date(prop_value)
      local today_date = parse_date(get_today())
      result = prop_date and today_date and prop_date >= today_date
    end
    return negated and not result or result
  end

  -- Pattern 9: date(property) <= today() + "N days"
  local date_prop, days_str = expr:match("^date%s*%(([%w%.]+)%)%s*<=%s*today%(%s*%)%s*%+%s*[\"'](%d+)%s+days?[\"']$")
  if date_prop and days_str then
    local prop_value = M.get_property(task, date_prop, context)
    if prop_value then
      local prop_date = parse_date(prop_value)
      local target_date = parse_date(add_days_to_date(get_today(), tonumber(days_str)))
      result = prop_date and target_date and prop_date <= target_date
    end
    return negated and not result or result
  end

  -- Pattern 10: property (truthy check)
  prop = expr:match("^([%w%.]+)$")
  if prop then
    local val = M.get_property(task, prop, context)
    result = val ~= nil and val ~= false and val ~= "" and val ~= vim.NIL
    if type(val) == "table" then
      result = #val > 0
    end
    return negated and not result or result
  end

  -- If no pattern matched, return false (unknown expression)
  vim.notify("Unknown Bases expression: " .. expr, vim.log.levels.WARN)
  return false
end

-- Evaluate a filter expression (can be table with and/or, or string expression)
function M.evaluate(filter, task, context)
  context = context or {}

  if not filter then
    return true
  end

  -- Handle table with logical operators
  if type(filter) == "table" then
    -- Check for 'and' operator
    if filter['and'] then
      for _, sub_filter in ipairs(filter['and']) do
        if not M.evaluate(sub_filter, task, context) then
          return false
        end
      end
      return true
    end

    -- Check for 'or' operator
    if filter['or'] then
      for _, sub_filter in ipairs(filter['or']) do
        if M.evaluate(sub_filter, task, context) then
          return true
        end
      end
      return false
    end

    -- Unknown table structure, treat as true
    return true
  end

  -- Handle string expression
  if type(filter) == "string" then
    return M.evaluate_string_expression(filter, task, context)
  end

  -- Unknown type, treat as false
  return false
end

return M
