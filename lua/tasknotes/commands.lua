-- Command handlers for user-facing commands
local M = {}

local tasknotes = require("tasknotes")

-- Handle TaskNotesView command
-- Usage: :TaskNotesView [view_name]
-- If no view_name provided, shows view selector
function M.view_command(...)
	local args = { ... }
	local view_name = args[1]

	if not view_name or view_name == "" then
		-- No argument - show view selector
		tasknotes.show_view_selector()
	else
		-- View name provided - open that view
		tasknotes.browse_by_view(view_name)
	end
end

-- Note: Custom view creation/editing is not supported for Bases views
-- Views must be created/edited in Obsidian or by manually editing .base files

-- Debug command to show ignore configuration
function M.debug_ignore_command()
	local config = require("tasknotes.config")
	local opts = config.get()

	local lines = {
		"=== TaskNotes Ignore Configuration Debug ===",
		"",
		"Vault Path:",
		"  " .. opts.vault_path,
		"",
		"Obsidian Integration:",
		"  enabled = " .. tostring(opts.obsidian.enabled),
	}

	if opts.obsidian.enabled then
		table.insert(lines, "  vault_path = " .. (opts.obsidian.vault_path or "not set"))

		-- Try to check if Obsidian settings file exists
		local obsidian_vault = vim.fn.expand(opts.obsidian.vault_path)
		local settings_path = obsidian_vault .. "/.obsidian/plugins/tasknotes/data.json"
		local exists = vim.fn.filereadable(settings_path) == 1
		table.insert(lines, "  settings file exists = " .. tostring(exists))

		if exists then
			table.insert(lines, "  settings file: " .. settings_path)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "Ignore Directories (from config.get_ignore_dirs()):")

	local ignore_dirs = config.get_ignore_dirs()
	if #ignore_dirs == 0 then
		table.insert(lines, "  (none - all directories will be scanned)")
	else
		for _, dir in ipairs(ignore_dirs) do
			table.insert(lines, "  - " .. dir)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "Manual Override (config.ignore_dirs):")
	if opts.ignore_dirs == nil then
		table.insert(lines, "  nil (using defaults + Obsidian settings)")
	elseif #opts.ignore_dirs == 0 then
		table.insert(lines, "  {} (empty array - ignores disabled)")
	else
		for _, dir in ipairs(opts.ignore_dirs) do
			table.insert(lines, "  - " .. dir)
		end
	end

	table.insert(lines, "")
	table.insert(lines, "Sample Task Paths:")
	local task_manager = require("tasknotes.task_manager")
	local sample_count = 0
	for _, task in ipairs(task_manager.tasks) do
		if sample_count < 3 then
			table.insert(lines, "  " .. task.path)
			sample_count = sample_count + 1
		else
			break
		end
	end
	if sample_count == 0 then
		table.insert(lines, "  (no tasks loaded)")
	end

	-- Look for suspected template files
	table.insert(lines, "")
	table.insert(lines, "=== Suspected Template Files ===")
	table.insert(lines, "")

	local template_patterns = {
		"{.*}",           -- {Task title...}
		"<.*>",           -- <describe...>
		"%[.*%]",         -- [placeholder]
		"^TODO$",         -- TODO
		"^BUG$",          -- BUG
		"^FEATURE$",      -- FEATURE
		"template",       -- Contains "template"
	}

	local found_templates = {}
	for _, task in ipairs(task_manager.tasks) do
		for _, pattern in ipairs(template_patterns) do
			if task.title and task.title:match(pattern) then
				table.insert(found_templates, {
					path = task.path,
					title = task.title,
				})
				break
			end
		end
	end

	if #found_templates > 0 then
		table.insert(lines, "Found " .. #found_templates .. " suspected template files:")
		table.insert(lines, "")
		for _, tmpl in ipairs(found_templates) do
			table.insert(lines, "  File: " .. tmpl.path)
			table.insert(lines, "  Title: " .. tmpl.title)
			table.insert(lines, "")
		end
	else
		table.insert(lines, "No suspected template files found.")
		table.insert(lines, "")
	end

	table.insert(lines, "")
	table.insert(lines, "=== Troubleshooting Steps ===")
	table.insert(lines, "")

	if not opts.obsidian.enabled then
		table.insert(lines, "⚠️  Obsidian integration is NOT enabled!")
		table.insert(lines, "   Your excludedFolders setting in Obsidian won't be used.")
		table.insert(lines, "")
		table.insert(lines, "Fix: Add to your config:")
		table.insert(lines, "  obsidian = {")
		table.insert(lines, "    enabled = true,")
		table.insert(lines, "    vault_path = '~/path/to/your/obsidian/vault',")
		table.insert(lines, "  }")
	elseif opts.obsidian.enabled and vim.fn.filereadable(vim.fn.expand(opts.obsidian.vault_path) .. "/.obsidian/plugins/tasknotes/data.json") == 0 then
		table.insert(lines, "⚠️  Obsidian settings file not found!")
		table.insert(lines, "   Expected at: " .. vim.fn.expand(opts.obsidian.vault_path) .. "/.obsidian/plugins/tasknotes/data.json")
	end

	table.insert(lines, "")
	table.insert(lines, "To apply changes:")
	table.insert(lines, "  1. Update your config")
	table.insert(lines, "  2. Run :TaskNotesClearCache")
	table.insert(lines, "  3. Restart Neovim or run :TaskNotesRescan")

	-- Create a buffer to display the info
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)
	vim.api.nvim_buf_set_option(buf, 'filetype', 'tasknotes-debug')

	-- Open in a split
	vim.cmd('vsplit')
	vim.api.nvim_win_set_buf(0, buf)
end

return M
