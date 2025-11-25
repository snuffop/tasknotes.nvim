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

return M
