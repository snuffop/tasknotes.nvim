local M = {}

-- Cache version for schema evolution
local CACHE_VERSION = 1

-- Get file modification time
local function get_mtime(filepath)
  local stat = vim.loop.fs_stat(filepath)
  if stat then
    return stat.mtime.sec
  end
  return nil
end

-- Load cache from file
function M.load(cache_path)
  local file = io.open(cache_path, "r")
  if not file then
    return nil, "Cache file not found"
  end

  local content = file:read("*all")
  file:close()

  -- Parse JSON
  local ok, cache = pcall(vim.json.decode, content)
  if not ok then
    return nil, "Failed to parse cache JSON"
  end

  -- Check version
  if cache.version ~= CACHE_VERSION then
    return nil, "Cache version mismatch (expected " .. CACHE_VERSION .. ", got " .. tostring(cache.version) .. ")"
  end

  return cache
end

-- Save cache to file
function M.save(cache_path, cache)
  cache.version = CACHE_VERSION
  cache.last_updated = os.time()

  local json = vim.json.encode(cache)

  local file = io.open(cache_path, "w")
  if not file then
    return false, "Failed to open cache file for writing"
  end

  file:write(json)
  file:close()

  return true
end

-- Check if file has changed since cached
function M.has_changed(filepath, cached_mtime)
  local current_mtime = get_mtime(filepath)
  if not current_mtime then
    return true -- File doesn't exist, consider changed
  end

  if not cached_mtime then
    return true -- No cached mtime, consider changed
  end

  return current_mtime > cached_mtime
end

-- Get file modification time (exposed for external use)
function M.get_mtime(filepath)
  return get_mtime(filepath)
end

-- Create new empty cache
function M.new()
  return {
    version = CACHE_VERSION,
    last_updated = os.time(),
    tasks = {},
  }
end

return M
