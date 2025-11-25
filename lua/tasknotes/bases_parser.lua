-- Obsidian Bases file parser for tasknotes.nvim
-- Parses .base files and extracts view definitions

local M = {}

-- Check if yq is available for YAML parsing
local function has_yq()
  return vim.fn.executable("yq") == 1
end

-- Parse .base file using yq (if available)
local function parse_with_yq(filepath)
  if not has_yq() then
    return nil, "yq not available"
  end

  -- Use yq to convert YAML to JSON
  local cmd = string.format("yq eval -o=json '%s' 2>/dev/null", filepath)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return nil, "yq failed to parse file"
  end

  -- Decode JSON
  local ok, data = pcall(vim.fn.json_decode, result)
  if not ok then
    return nil, "Failed to decode JSON from yq"
  end

  return data, nil
end

-- Simple YAML parser for .base files (fallback when yq is not available)
-- This is a minimal parser that handles the specific .base file structure
local function parse_simple_yaml(content)
  local data = {
    filters = nil,
    views = {}
  }

  local lines = vim.split(content, "\n")
  local i = 1
  local current_section = nil
  local current_view = nil
  local indent_stack = {}

  while i <= #lines do
    local line = lines[i]

    -- Skip comments and empty lines
    if line:match("^%s*#") or line:match("^%s*$") then
      i = i + 1
      goto continue
    end

    -- Detect top-level sections
    if line:match("^filters:") then
      current_section = "filters"
      data.filters = { ['and'] = {} }
      i = i + 1
      goto continue
    elseif line:match("^views:") then
      current_section = "views"
      i = i + 1
      goto continue
    end

    -- Parse filters section
    if current_section == "filters" and line:match("^%s+and:") then
      i = i + 1
      -- Read filter expressions
      while i <= #lines do
        local filter_line = lines[i]
        if filter_line:match("^%s+%-%s+") then
          local expr = filter_line:match("^%s+%-%s+(.+)$")
          if expr then
            table.insert(data.filters['and'], expr)
          end
          i = i + 1
        else
          break
        end
      end
      goto continue
    end

    -- Parse views section
    if current_section == "views" and line:match("^%s+%-%s+type:") then
      -- New view definition
      local view_type = line:match("type:%s*(%S+)")
      current_view = {
        type = view_type,
        name = "",
        filters = nil,
        order = {},
        sort = {}
      }
      table.insert(data.views, current_view)
      i = i + 1

      -- Parse view properties
      while i <= #lines do
        local view_line = lines[i]

        -- Stop if we hit next view or end of views section
        if view_line:match("^%s+%-%s+type:") or view_line:match("^%S") then
          break
        end

        -- Parse view properties
        if view_line:match("^%s+name:") then
          current_view.name = view_line:match("name:%s*[\"']?([^\"']+)[\"']?")
        elseif view_line:match("^%s+filters:") then
          current_view.filters = { ['and'] = {} }
          i = i + 1
          -- Skip to 'and:' line
          if i <= #lines and lines[i]:match("^%s+and:") then
            i = i + 1
            -- Read filter expressions
            while i <= #lines do
              local filter_line = lines[i]
              if filter_line:match("^%s+%-%s+") then
                local expr = filter_line:match("^%s+%-%s+(.+)$")
                if expr then
                  table.insert(current_view.filters['and'], expr)
                end
                i = i + 1
              else
                break
              end
            end
          end
          goto continue
        elseif view_line:match("^%s+order:") then
          i = i + 1
          -- Read order items
          while i <= #lines do
            local order_line = lines[i]
            if order_line:match("^%s+%-%s+") then
              local prop = order_line:match("^%s+%-%s+(%S+)")
              if prop then
                table.insert(current_view.order, prop)
              end
              i = i + 1
            else
              break
            end
          end
          goto continue
        elseif view_line:match("^%s+sort:") then
          i = i + 1
          -- Read sort items (simplified - just extract column and direction)
          while i <= #lines do
            local sort_line = lines[i]
            if sort_line:match("^%s+%-%s+") then
              local column = nil
              local direction = nil
              -- Look ahead for column and direction
              local j = i
              while j <= #lines and not lines[j]:match("^%s+%-%s+") and not lines[j]:match("^%s+[a-z]+:") do
                if lines[j]:match("column:") or lines[j]:match("property:") then
                  column = lines[j]:match("column:%s*(%S+)") or lines[j]:match("property:%s*(%S+)")
                end
                if lines[j]:match("direction:") then
                  direction = lines[j]:match("direction:%s*(%S+)")
                end
                j = j + 1
                if column and direction then
                  break
                end
              end
              if column then
                table.insert(current_view.sort, { column = column, direction = direction or "ASC" })
              end
              i = j
            else
              break
            end
          end
          goto continue
        end

        i = i + 1
      end
      goto continue
    end

    i = i + 1
    ::continue::
  end

  return data, nil
end

-- Parse a .base file
function M.parse_file(filepath)
  -- Check if file exists
  if vim.fn.filereadable(filepath) == 0 then
    return nil, "File not found: " .. filepath
  end

  -- Try yq first (more robust)
  local data, err = parse_with_yq(filepath)
  if data then
    return data, nil
  end

  -- Fall back to simple parser
  local content = table.concat(vim.fn.readfile(filepath), "\n")
  return parse_simple_yaml(content)
end

-- Scan Views directory and return all tasknotesTaskList views
function M.scan_views_directory(views_dir)
  local all_views = {}

  -- Check if directory exists
  if vim.fn.isdirectory(views_dir) == 0 then
    return all_views, "Views directory not found: " .. views_dir
  end

  -- Find all .base files
  local base_files = vim.fn.glob(views_dir .. "/*.base", false, true)

  for _, filepath in ipairs(base_files) do
    local base_name = vim.fn.fnamemodify(filepath, ":t:r")
    local data, err = M.parse_file(filepath)

    if data and data.views then
      -- Extract tasknotesTaskList views only
      for _, view in ipairs(data.views) do
        if view.type == "tasknotesTaskList" then
          -- Create unique view ID
          local view_id = base_name .. ":" .. view.name

          all_views[view_id] = {
            id = view_id,
            name = view.name,
            description = base_name,
            source_file = filepath,
            base_filters = data.filters,  -- Top-level filters from .base file
            view_filters = view.filters,  -- View-specific filters
            order = view.order or {},
            sort = view.sort or {},
          }
        end
      end
    else
      if err then
        vim.notify(string.format("Failed to parse %s: %s", filepath, err), vim.log.levels.WARN)
      end
    end
  end

  return all_views, nil
end

-- Get a specific view by ID
function M.get_view(view_id, views_dir)
  local all_views, err = M.scan_views_directory(views_dir)
  if err then
    return nil, err
  end

  return all_views[view_id], nil
end

-- List all available views
function M.list_views(views_dir)
  return M.scan_views_directory(views_dir)
end

return M
