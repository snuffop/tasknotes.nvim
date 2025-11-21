local M = {}

-- Split frontmatter and body from markdown content
function M.split_frontmatter(content)
  -- Match YAML frontmatter between --- delimiters
  local pattern = "^%-%-%-\n(.-)%-%-%-\n(.*)$"
  local frontmatter_str, body = content:match(pattern)

  if frontmatter_str then
    return frontmatter_str, body
  end

  -- No frontmatter found
  return nil, content
end

-- Parse YAML frontmatter string to Lua table
function M.parse_yaml(yaml_str)
  if not yaml_str or yaml_str == "" then
    return {}
  end

  -- Try using yq if available (faster and more reliable)
  local has_yq = vim.fn.executable("yq") == 1
  if has_yq then
    local json_str = vim.fn.system({ "yq", "eval", "-o=json", "-" }, yaml_str)
    if vim.v.shell_error == 0 then
      local ok, result = pcall(vim.fn.json_decode, json_str)
      if ok then
        return result
      end
    end
  end

  -- Fallback to basic Lua YAML parser
  return M.parse_yaml_basic(yaml_str)
end

-- Basic YAML parser for simple frontmatter (handles most TaskNotes cases)
function M.parse_yaml_basic(yaml_str)
  local result = {}
  local lines = vim.split(yaml_str, "\n")
  local current_key = nil
  local current_list = nil
  local in_multiline = false

  for _, line in ipairs(lines) do
    -- Skip empty lines and comments
    if line:match("^%s*$") or line:match("^%s*#") then
      goto continue
    end

    -- List item
    if line:match("^%s*%-%s+") then
      local value = line:match("^%s*%-%s+(.+)$")
      if current_key and current_list then
        -- Trim quotes if present
        value = value:match('^"(.-)"$') or value:match("^'(.-)'$") or value
        table.insert(current_list, value)
      end
      goto continue
    end

    -- Key-value pair
    local key, value = line:match("^([%w_]+):%s*(.*)$")
    if key then
      current_key = key

      if value == "" or value == "null" then
        -- Empty value or null
        result[key] = nil
        current_list = nil
      elseif value == "[]" then
        -- Empty array
        result[key] = {}
        current_list = nil
      else
        -- Try to parse value
        value = value:gsub("^%s+", ""):gsub("%s+$", "") -- trim

        -- Remove quotes
        local unquoted = value:match('^"(.-)"$') or value:match("^'(.-)'$")
        if unquoted then
          result[key] = unquoted
          current_list = nil
        -- Boolean
        elseif value == "true" then
          result[key] = true
          current_list = nil
        elseif value == "false" then
          result[key] = false
          current_list = nil
        -- Number
        elseif value:match("^%-?%d+%.?%d*$") then
          result[key] = tonumber(value)
          current_list = nil
        -- Start of array (indicated by no value after colon)
        elseif value == "" then
          result[key] = {}
          current_list = result[key]
        else
          -- String value
          result[key] = value
          current_list = nil
        end
      end
      goto continue
    end

    ::continue::
  end

  return result
end

-- Serialize Lua table to YAML frontmatter string
function M.serialize_yaml(data)
  local lines = {}

  -- Helper to serialize a value
  local function serialize_value(value, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)

    if type(value) == "table" then
      -- Check if it's an array or object
      local is_array = #value > 0
      if is_array then
        local result = {}
        for _, item in ipairs(value) do
          if type(item) == "string" then
            table.insert(result, prefix .. "- " .. item)
          elseif type(item) == "table" then
            -- Complex array item (for timeEntries, etc.)
            table.insert(result, prefix .. "- ")
            for k, v in pairs(item) do
              table.insert(result, prefix .. "  " .. k .. ": " .. tostring(v))
            end
          else
            table.insert(result, prefix .. "- " .. tostring(item))
          end
        end
        return table.concat(result, "\n")
      else
        -- Object
        local result = {}
        for k, v in pairs(value) do
          table.insert(result, prefix .. k .. ": " .. serialize_value(v, indent + 1))
        end
        return table.concat(result, "\n")
      end
    elseif type(value) == "boolean" then
      return tostring(value)
    elseif type(value) == "number" then
      return tostring(value)
    elseif type(value) == "string" then
      -- Quote strings with special characters
      if value:match("[:#@]") or value:match("^%s") or value:match("%s$") then
        return '"' .. value .. '"'
      end
      return value
    else
      return tostring(value)
    end
  end

  -- Serialize each field
  local ordered_keys = {}
  for k in pairs(data) do
    table.insert(ordered_keys, k)
  end
  table.sort(ordered_keys)

  for _, key in ipairs(ordered_keys) do
    local value = data[key]
    if type(value) == "table" and #value > 0 then
      -- Array
      table.insert(lines, key .. ":")
      table.insert(lines, serialize_value(value, 0))
    elseif type(value) == "table" then
      -- Object
      table.insert(lines, key .. ":")
      for k, v in pairs(value) do
        table.insert(lines, "  " .. k .. ": " .. serialize_value(v, 1))
      end
    else
      table.insert(lines, key .. ": " .. serialize_value(value))
    end
  end

  return table.concat(lines, "\n")
end

-- Parse a full markdown file
function M.parse_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Could not open file: " .. filepath
  end

  local content = file:read("*all")
  file:close()

  local frontmatter_str, body = M.split_frontmatter(content)
  local frontmatter = M.parse_yaml(frontmatter_str or "")

  return {
    frontmatter = frontmatter,
    body = body,
    path = filepath,
  }
end

-- Write frontmatter and body to file
function M.write_file(filepath, frontmatter, body)
  local yaml_str = M.serialize_yaml(frontmatter)
  local content = "---\n" .. yaml_str .. "\n---\n" .. (body or "")

  local file = io.open(filepath, "w")
  if not file then
    return false, "Could not write file: " .. filepath
  end

  file:write(content)
  file:close()

  return true
end

return M
