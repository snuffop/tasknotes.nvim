# tasknotes.nvim

## Project Purpose

Task management plugin for Neovim using [TaskNotes](https://github.com/joshklein/obsidian-tasknotes) format. Each task is a markdown file with YAML frontmatter stored in an Obsidian vault.

## Architecture

### Dependencies

**Required:**

- `bases.nvim` - Obsidian Bases integration (for view filtering/sorting/evaluation)
- `MunifTanjim/nui.nvim` - UI components (forms, tables)
- `folke/snacks.nvim` - Task picker interface

**Optional:**

- `nvim-telescope/telescope.nvim` - Alternative picker backend
- `nvim-lua/plenary.nvim` - Utilities

### Core Modules

**`lua/tasknotes/task_manager.lua`**

- Central task state management
- Vault scanning and caching
- Task CRUD operations
- Filter application (uses bases.nvim for Bases filters)
- Urgency calculation integration

**`lua/tasknotes/parser.lua`**

- YAML frontmatter parsing
- TaskNotes file format handling
- Field mapping from config

**`lua/tasknotes/urgency.lua`**

- Taskwarrior-compatible urgency calculation
- Factors: priority, due date, age, annotations
- Configurable urgency coefficients
- Cached for performance

**`lua/tasknotes/cache.lua`**

- Persistent task cache at `~/.local/state/nvim/tasknotes_cache.json`
- Reduces vault scanning overhead
- Auto-recalculates urgency on load

**`lua/tasknotes/config.lua`**

- Configuration management
- Status/priority definitions
- Field mapping
- UI settings

### UI Modules

**`lua/tasknotes/snacks_picker.lua`**

- Primary task browser using Snacks.nvim picker
- Integrates with bases.nvim for view filtering
- Actions: mark done, edit, delete, toggle timer
- View selector integration

**`lua/tasknotes/ui/task_form.lua`**

- NUI-based task creation/editing form
- Field inputs for all task properties
- Validation and saving

**`lua/tasknotes/ui/time_tracker.lua`**

- Time tracking with start/stop timers
- Pomodoro-style time entries
- Time entry management and display

**`lua/tasknotes/telescope.lua`**

- Telescope picker integration (alternative to Snacks)
- Task browsing with Telescope UI

### Command Integration

**`lua/tasknotes/commands.lua`**

- Exposes Vim commands
- `:TaskNotesBrowse`, `:TaskNotesNew`, `:TaskNotesView`, etc.
- `:TaskNotesDebugIgnore` - Debug ignore directory configuration

## Key Features

### 1. Obsidian Bases Views

Uses `bases.nvim` for view filtering:

```lua
-- Loads from ~/vault/TaskNotes/Views/*.base
local view = bases.get_view(view_id, views_dir, {
  view_type = "tasknotesTaskList"  -- Filter for task list views
})

-- Apply Bases filters
local filtered = task_manager.get_tasks({
  bases_filters = combined_filters
})
```

### 2. Urgency Calculation

Taskwarrior-compatible scoring:

- **Priority**: high=6.0, medium=3.9, low=1.8
- **Due dates**: Overdue tasks get higher urgency
- **Age**: Tasks gain urgency over time
- **Annotations**: Increases with task updates

Configurable coefficients in `config.urgency_coefficients`.

### 3. Time Tracking

- Start/stop timers per task
- Time entries stored in task frontmatter
- Display total time and active timer status
- Timer toggle action in picker

### 4. Task Identification

Two modes (configured via `task_identification_method`):

**Tag-based:**

```yaml
tags: [task, work]
```

**Property-based:**

```yaml
type: task
```

### 5. Status Workflow

Configurable statuses with completion flag:

```lua
statuses = {
  { name = "open", display = "Open", color = "#808080", is_completed = false },
  { name = "done", display = "Done", color = "#00aa00", is_completed = true },
}
```

### 6. Directory Ignore Patterns

Exclude directories from vault scanning with a three-tier configuration system:

**Priority:** Neovim config > Obsidian settings > defaults

**Defaults:** `.obsidian`, `.trash`, `.git` (always applied unless overridden)

**Configuration:**

```lua
-- Use defaults only
require("tasknotes").setup({
  vault_path = "~/vault/Tasks",
  -- ignore_dirs not specified, uses defaults: .obsidian, .trash, .git
})

-- Extend with Obsidian settings
-- If .obsidian/plugins/tasknotes/data.json has:
-- { "excludedFolders": "Archive,Templates,OLD_VAULT" }
-- Results in: .obsidian, .trash, .git, Archive, Templates, OLD_VAULT

-- Complete Neovim override
require("tasknotes").setup({
  vault_path = "~/vault/Tasks",
  ignore_dirs = { "Archive", "Old", "Drafts" },
  -- Only ignores: Archive, Old, Drafts (defaults NOT included)
})

-- Disable all ignores
require("tasknotes").setup({
  vault_path = "~/vault/Tasks",
  ignore_dirs = {},  -- Empty array = no ignores
})
```

**Performance:** Uses `find -prune` to prevent descending into ignored directories, significantly improving scan speed for large vaults.

**Cache invalidation:** Cache is automatically invalidated when ignore patterns change.

## Data Flow

```
Obsidian Vault
    ↓
Parser (YAML → Lua tables)
    ↓
Cache (~/.local/state/nvim/)
    ↓
Task Manager (filtering, get_tasks)
    ↓
Urgency Calculation
    ↓
bases.nvim (Bases filter evaluation)
    ↓
Snacks Picker (display + actions)
```

## Testing

Uses mini.test framework with Makefile:

```bash
make test                # All tests
make test-task-manager   # Task manager tests
make test-urgency        # Urgency calculation tests
make test-parser         # Parser tests
```

### Test Coverage

- `tests/test_task_manager.lua` - Task CRUD, filtering
- `tests/test_urgency.lua` - Urgency calculations
- `tests/test_parser.lua` - YAML parsing
- `tests/test_dependencies.lua` - Dependency tracking
- `tests/test_cache.lua` - Cache validation and persistence
- `tests/test_ignore_dirs.lua` - Directory ignore functionality
- `tests/test_obsidian_importer.lua` - Obsidian settings parsing (excludedFolders, etc.)

## Configuration Points

### Field Mapping

Maps internal names to frontmatter properties:

```lua
field_mapping = {
  title = "title",
  status = "status",
  due = "due",
  -- Custom field:
  myCustomField = "custom_property"
}
```

### Status/Priority Definitions

```lua
statuses = {
  { name = "internal_name", display = "Display Name", color = "#hex", is_completed = bool }
}

priorities = {
  { name = "internal_name", display = "Display Name", value = number }
}
```

### Urgency Coefficients

```lua
urgency_coefficients = {
  priority_high = 6.0,
  priority_medium = 3.9,
  due_today = 10.0,
  age_coefficient = 2.0,
}
```

### Directory Ignore Configuration

**Three-tier priority system:**

1. **Defaults** (applied unless overridden): `{ ".obsidian", ".trash", ".git" }`
2. **Obsidian settings**: Read from `.obsidian/plugins/tasknotes/data.json` field `excludedFolders` (comma-separated string)
3. **Neovim config**: `ignore_dirs` option (complete override when set)

**Examples:**

```lua
-- Use defaults + Obsidian settings (if available)
ignore_dirs = nil  -- Default

-- Complete override (defaults NOT included)
ignore_dirs = { "Archive", "Templates", "Drafts" }

-- Disable all ignores
ignore_dirs = {}
```

**Implementation details:**

- Uses `find -prune` for efficient directory exclusion
- Cache tracks `ignore_dirs` and invalidates when changed
- Obsidian importer reads `excludedFolders` from `data.json` (comma-separated string, automatically parsed and trimmed)
- Directory names are matched exactly (case-sensitive on most systems)
- Example Obsidian format: `"excludedFolders": "04_Archive,05_Attachments,OLD_VAULT"`

## Integration with bases.nvim

tasknotes.nvim uses bases.nvim for:

1. **View Parsing**: Load `.base` files from `TaskNotes/Views/`
2. **Filter Evaluation**: Apply Bases expressions to tasks
3. **View Selector**: Pick from available views

Key integration points:

- `snacks_picker.lua:browse_by_view()` - Uses `bases.get_view()`
- `snacks_picker.lua:show_view_selector()` - Uses `bases.list_views()`
- `task_manager.lua:get_tasks()` - Uses `bases.evaluate()` for filtering

Always pass `view_type = "tasknotesTaskList"` to filter for task list views.

## File Organization

```
lua/tasknotes/
├── init.lua              # Plugin entry point
├── task_manager.lua      # Core task management
├── parser.lua            # YAML parsing
├── urgency.lua           # Urgency calculation
├── cache.lua             # Task caching
├── config.lua            # Configuration
├── commands.lua          # Vim commands
├── snacks_picker.lua     # Snacks integration
├── telescope.lua         # Telescope integration
└── ui/
    ├── task_form.lua     # Task create/edit form
    └── time_tracker.lua  # Time tracking UI

tests/
├── test_task_manager.lua
├── test_urgency.lua
├── test_parser.lua
├── test_cache.lua
├── test_ignore_dirs.lua
├── test_obsidian_importer.lua
├── test_dependencies.lua
└── helpers.lua
```

## Development Notes

- Cache is at `~/.local/state/nvim/tasknotes_cache.json` (not `.cache`)
- Urgency is recalculated on cache load for fresh values
- Completed tasks are filtered out by default (configurable)
- Debug notifications can be removed from `snacks_picker.lua`
- Always use Justfile for bases.nvim tests, Makefile for tasknotes tests

## Task File Format

```yaml
---
type: task
title: "My Task"
status: open
priority: high
due: 2025-12-25
scheduled: 2025-12-20
contexts: [work, urgent]
projects: [my-project]
tags: [important]
timeEstimate: 2h
timeEntries:
  - start: 2025-11-25T10:00:00Z
    end: 2025-11-25T10:30:00Z
completedDate: null
dateCreated: 2025-11-25T09:00:00Z
dateModified: 2025-11-25T10:30:00Z
---
Task description goes here.
```

## Troubleshooting

### Templates or unwanted tasks showing up

If you see template files or tasks from excluded directories:

1. **Run the debug command:**

   ```vim
   :TaskNotesDebugIgnore
   ```

   This will show:

   - Current vault path
   - Whether Obsidian integration is enabled
   - What directories are being ignored
   - Sample task paths
   - Specific troubleshooting steps

2. **Enable Obsidian integration** (if not already):

   ```lua
   require("tasknotes").setup({
     obsidian = {
       enabled = true,
       vault_path = "~/path/to/your/obsidian/vault",
     },
   })
   ```

3. **Clear cache and rescan:**

   ```vim
   :TaskNotesClearCache
   :TaskNotesRescan
   ```

   Or just restart Neovim

4. **Manual override** (if Obsidian integration can't be used):
   ```lua
   require("tasknotes").setup({
     ignore_dirs = { "04_Archive", "05_Attachments", "06_Metadata", "OLD_VAULT" },
   })
   ```

## Common Operations

### Add a new field

1. Update `config.lua` field_mapping
2. Update `parser.lua` to extract the field
3. Update `task_form.lua` if editable via UI
4. Update urgency calculation if it affects urgency

### Add a new filter expression

This is now handled in bases.nvim - update there instead.

### Change urgency calculation

1. Update `urgency.lua` calculation logic
2. Update `config.lua` urgency_coefficients if needed
3. Add tests to `tests/test_urgency.lua`
4. Clear cache to recalculate all tasks
