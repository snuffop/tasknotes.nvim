local M = {}

-- Cache version for schema evolution
local CACHE_VERSION = 2

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
-- @param cache_path string: Path to cache file
-- @param cache table: Cache data structure
-- @param vault_path string: Current vault path to store in cache
function M.save(cache_path, cache, vault_path)
  local config = require("tasknotes.config")
  cache.version = CACHE_VERSION
  cache.last_updated = os.time()
  cache.vault_path = vault_path
  cache.ignore_dirs = config.get_ignore_dirs()

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

-- Check if cache needs validation based on interval
function M.needs_validation(cache, validation_interval)
  if not cache or not cache.last_validated then
    return true
  end

  local time_since_validation = os.time() - cache.last_validated
  return time_since_validation > validation_interval
end

-- Validate that cache vault_path matches current vault_path
-- Returns: valid (boolean), message (string)
function M.validate_vault_path(cache, current_vault_path)
  if not cache or not cache.vault_path then
    return false, "Cache missing vault_path (old cache format or corrupted)"
  end

  -- Normalize paths to handle symlinks, trailing slashes, ~ expansion
  local cached_path = vim.fn.resolve(vim.fn.fnamemodify(cache.vault_path, ":p"))
  local current_path = vim.fn.resolve(vim.fn.fnamemodify(current_vault_path, ":p"))

  if cached_path ~= current_path then
    return false,
      string.format("Vault moved: cached='%s', current='%s'", cached_path, current_path)
  end

  -- Check if ignore_dirs changed
  local config = require("tasknotes.config")
  local current_ignore = config.get_ignore_dirs()
  local cached_ignore = cache.ignore_dirs or {}

  if not vim.deep_equal(current_ignore, cached_ignore) then
    return false, "Ignore directories configuration changed"
  end

  return true, "Vault path valid"
end

-- Create new empty cache
-- @param vault_path string|nil: Optional vault path to initialize cache with
function M.new(vault_path)
  local config = require("tasknotes.config")
  return {
    version = CACHE_VERSION,
    vault_path = vault_path or "", -- Vault path for validation
    ignore_dirs = config.get_ignore_dirs(), -- Directory ignore patterns for validation
    last_updated = os.time(),
    last_validated = 0, -- Unix timestamp of last validation
    file_list = {}, -- List of all .md file paths in vault
    tasks = {},
  }
end

return M
