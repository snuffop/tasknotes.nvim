# tasknotes.nvim

A Neovim plugin for managing [TaskNotes](https://github.com/joshklein/obsidian-tasknotes) - a task management system where each task is a markdown file with YAML frontmatter.

**📚 New to tasknotes.nvim?** Check out the [Quick Start Guide](QUICKSTART.md) to get up and running in minutes!

## Features

- **Views System**: Motion-inspired views (Inbox, Today, Overdue, etc.) with support for custom saved views
- **Browse & Search Tasks**: Snacks picker integration for fast task browsing with filtering by status, priority, context, and project
- **Create & Edit Tasks**: NUI-based forms for creating new tasks and editing existing ones
- **Time Tracking**: Built-in time tracker with start/stop timers and time entry management
- **YAML Frontmatter Support**: Full support for TaskNotes file format with custom field mapping
- **Flexible Configuration**: Customizable statuses, priorities, colors, and UI settings

## Requirements

- Neovim >= 0.5.0
- [MunifTanjim/nui.nvim](https://github.com/MunifTanjim/nui.nvim) (required)
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional but recommended)
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (optional but recommended)
- `yq` command-line tool (optional, for improved YAML parsing)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "emiller/tasknotes.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("tasknotes").setup({
      vault_path = "~/notes/tasks",
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "emiller/tasknotes.nvim",
  requires = {
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("tasknotes").setup({
      vault_path = "~/notes/tasks",
    })
  end,
}
```

## Configuration

### Default Configuration

```lua
require("tasknotes").setup({
  -- Path to TaskNotes vault directory
  vault_path = vim.fn.expand("~/notes/tasks"),

  -- Task identification method
  task_identification_method = "tag", -- "tag" or "property"
  task_tag = "task",
  task_property_name = "type",
  task_property_value = "task",

  -- Field mapping (internal name -> frontmatter property name)
  field_mapping = {
    title = "title",
    status = "status",
    priority = "priority",
    due = "due",
    scheduled = "scheduled",
    contexts = "contexts",
    projects = "projects",
    tags = "tags",
    timeEstimate = "timeEstimate",
    timeEntries = "timeEntries",
    completedDate = "completedDate",
    dateCreated = "dateCreated",
    dateModified = "dateModified",
  },

  -- Status definitions
  statuses = {
    { name = "none", display = "None", color = "#cccccc", is_completed = false },
    { name = "open", display = "Open", color = "#808080", is_completed = false },
    { name = "in-progress", display = "In Progress", color = "#0066cc", is_completed = false },
    { name = "done", display = "Done", color = "#00aa00", is_completed = true },
  },

  -- Priority definitions
  priorities = {
    { name = "none", display = "None", color = "#cccccc", weight = 0 },
    { name = "low", display = "Low", color = "#00aa00", weight = 1 },
    { name = "normal", display = "Normal", color = "#ffaa00", weight = 2 },
    { name = "high", display = "High", color = "#ff0000", weight = 3 },
  },

  -- UI configuration
  ui = {
    border_style = "rounded", -- "rounded", "single", "double", "solid"
    task_form_width = 60,
    task_form_height = 20,
    time_tracker_width = 50,
    time_tracker_height = 15,
  },

  -- Telescope configuration
  telescope = {
    enabled = true,
    theme = "dropdown",
    dim_completed = true, -- Grey out completed tasks in the picker
  },

  -- Time tracking
  time_tracking = {
    enabled = true,
    auto_save_interval = 60, -- seconds
  },

  -- Keymaps
  keymaps = {
    browse = "<leader>tb",
    new_task = "<leader>tn",
    edit_task = "<leader>te",
    toggle_timer = "<leader>tt",
  },
})
```

## Obsidian Integration

You can automatically import settings from the [Obsidian TaskNotes](https://github.com/joshklein/obsidian-tasknotes) plugin. This allows you to maintain a single source of configuration in Obsidian and sync it to Neovim.

### Automatic Import on Setup

Enable auto-import in your configuration:

```lua
require("tasknotes").setup({
  obsidian = {
    enabled = true,
    vault_path = "~/sync/claude-vault",  -- Path to your Obsidian vault
  },
})
```

When enabled, tasknotes.nvim will:

- Read settings from `.obsidian/plugins/tasknotes/data.json`
- Import task folder location, identification method, statuses, priorities, and field mappings
- Merge with any additional settings you provide (your settings take precedence)

### Manual Import

You can also manually import settings with a command:

```vim
:TaskNotesImportObsidian ~/sync/claude-vault
```

### What Gets Imported

The following settings are imported from Obsidian:

- **Task folder**: `tasksFolder` → `vault_path`
- **Identification method**: `taskIdentificationMethod` → `task_identification_method`
- **Task tag**: `taskTag` → `task_tag`
- **Task property**: `taskPropertyName/taskPropertyValue` → `task_property_name/task_property_value`
- **Field mappings**: All frontmatter field mappings
- **Custom statuses**: Status definitions with colors and completion flags
- **Custom priorities**: Priority definitions with colors and weights

## Usage

### Commands

| Command                            | Description                                |
| ---------------------------------- | ------------------------------------------ |
| `:TaskNotesBrowse`                 | Open Snacks picker to browse all tasks     |
| `:TaskNotesNew`                    | Create a new task with form                |
| `:TaskNotesEdit`                   | Edit current task metadata                 |
| `:TaskNotesRescan`                 | Rescan vault directory for tasks           |
| `:TaskNotesView [name]`            | Open view by name (or show selector)       |
| `:TaskNotesSaveView <name> [desc]` | Save custom view with name and description |
| `:TaskNotesDeleteView <name>`      | Delete a saved custom view                 |
| `:TaskNotesListViews`              | Show view selector picker                  |
| `:TaskNotesTimerToggle`            | Start/stop timer for current task          |
| `:TaskNotesTimerStatus`            | Show active timer status                   |
| `:TaskNotesTimeEntries`            | View time entries for current task         |
| `:TaskNotesByStatus`               | Browse tasks filtered by status            |
| `:TaskNotesByPriority`             | Browse tasks filtered by priority          |
| `:TaskNotesByContext`              | Browse tasks filtered by context           |
| `:TaskNotesImportObsidian <path>`  | Import settings from Obsidian vault        |

### Default Keymaps

| Keymap       | Command                | Description        |
| ------------ | ---------------------- | ------------------ |
| `<leader>tb` | `TaskNotesBrowse`      | Browse tasks       |
| `<leader>tn` | `TaskNotesNew`         | Create new task    |
| `<leader>te` | `TaskNotesEdit`        | Edit current task  |
| `<leader>tt` | `TaskNotesTimerToggle` | Toggle timer       |
| `<leader>tv` | `TaskNotesListViews`   | Open view selector |

### Picker Actions

When browsing tasks with Snacks picker, the following actions are available:

| Keymap  | Action                |
| ------- | --------------------- |
| `<CR>`  | Open task file        |
| `<C-d>` | Mark task as done     |
| `<C-e>` | Edit task metadata    |
| `<C-x>` | Delete task           |
| `<C-t>` | Toggle timer for task |
| `<C-v>` | Open view selector    |

## Views

Views provide quick access to filtered task lists, similar to Motion's view system. Views help you focus on specific subsets of tasks for different workflows.

### Built-in Views

| View          | Description                                     | Filter                                 |
| ------------- | ----------------------------------------------- | -------------------------------------- |
| `inbox`       | Tasks without project or context (needs triage) | No projects AND no contexts            |
| `today`       | Tasks due or scheduled for today or earlier     | `due <= today` OR `scheduled <= today` |
| `overdue`     | Past-due incomplete tasks                       | `due < today` AND not completed        |
| `unscheduled` | Tasks without due or scheduled dates            | No `due` AND no `scheduled`            |

### Using Views

**Open a specific view:**

```vim
:TaskNotesView inbox
:TaskNotesView today
```

**Open view selector:**

```vim
:TaskNotesListViews
" Or use keymap: <leader>tv
" Or press <C-v> while in the task picker
```

### Custom Views

Create your own saved views for common workflows:

**Save a custom view:**

```vim
:TaskNotesSaveView my_work_tasks Work-related high priority items
" This will prompt you to select a filter type
```

**Delete a custom view:**

```vim
:TaskNotesDeleteView my_work_tasks
```

**Example custom views:**

- `urgent_work` - High priority tasks in @work context
- `home_weekend` - Tasks in @home context
- `project_alpha` - All tasks for Project Alpha
- `quick_wins` - Low estimate, high priority tasks

### View Configuration

Configure view behavior in your setup:

```lua
require("tasknotes").setup({
  views = {
    -- How to identify inbox tasks
    inbox_definition = "no_project_or_context",

    -- Days ahead to include in "today" view (0 = only today)
    today_range = 0,

    keymaps = {
      view_selector = "<C-v>", -- In picker
    },
  },

  keymaps = {
    view_selector = "<leader>tv", -- Global
  },
})
```

### View Persistence

Custom views are saved to `~/.local/state/nvim/tasknotes/views.json` and persist across Neovim sessions.

## TaskNotes File Format

TaskNotes files are markdown files with YAML frontmatter:

```markdown
---
title: Review quarterly budget
status: open
priority: high
due: 2025-08-15
scheduled: 2025-08-14
tags:
  - task
  - work
  - finance
contexts:
  - "@office"
projects:
  - "[[Q3 Planning]]"
timeEstimate: 60
dateCreated: 2025-08-10T09:00:00.000Z
dateModified: 2025-08-10T09:00:00.000Z
---

Additional task description and notes go here.
Can include any markdown content.
```

### Frontmatter Fields

| Field           | Type   | Description                                 |
| --------------- | ------ | ------------------------------------------- |
| `title`         | string | Task title                                  |
| `status`        | string | Current status (open, in-progress, done)    |
| `priority`      | string | Priority level (none, low, normal, high)    |
| `due`           | string | Due date (YYYY-MM-DD)                       |
| `scheduled`     | string | Scheduled date (YYYY-MM-DD)                 |
| `contexts`      | array  | Location/tool contexts (e.g., @home, @work) |
| `projects`      | array  | Related projects (wikilinks)                |
| `tags`          | array  | Tags                                        |
| `timeEstimate`  | number | Estimated time in minutes                   |
| `timeEntries`   | array  | Time tracking entries                       |
| `completedDate` | string | When task was completed                     |
| `dateCreated`   | string | Creation timestamp (ISO)                    |
| `dateModified`  | string | Last modification timestamp (ISO)           |

## Time Tracking

### Start Timer

```vim
:TaskNotesTimerToggle
```

Or use the keymap: `<leader>tt`

### View Timer Status

```vim
:TaskNotesTimerStatus
```

### View Time Entries

```vim
:TaskNotesTimeEntries
```

### Time Entry Format

Time entries are stored in the task's frontmatter:

```yaml
timeEntries:
  - startTime: "2024-01-15T10:30:00Z"
    endTime: "2024-01-15T11:15:00Z"
    duration: 45
```

## Statusline Integration

You can add the active timer to your statusline:

```lua
-- Example with lualine
require('lualine').setup({
  sections = {
    lualine_x = {
      function()
        return require('tasknotes').statusline()
      end,
    },
  },
})
```

## API

### Lua API

```lua
local tasknotes = require("tasknotes")

-- Browse tasks
tasknotes.browse_tasks()
tasknotes.browse_tasks({ filter = { status = "open" } })

-- Create new task
tasknotes.new_task()

-- Edit current task
tasknotes.edit_task()

-- Time tracking
tasknotes.toggle_timer()
tasknotes.timer_status()
tasknotes.view_time_entries()

-- Rescan vault
tasknotes.rescan()

-- Statusline component
tasknotes.statusline()

-- Access task manager directly
local tasks = tasknotes.task_manager.get_tasks()
local task = tasknotes.task_manager.get_task_by_path("/path/to/task.md")
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features and improvements including:

- Recurring tasks support
- Task dependencies
- Reminders integration
- Calendar integration
- Export functionality
- And more...

## Development

### Running Tests

This plugin uses [mini.test](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) for testing.

#### Prerequisites

Install mini.nvim (if not already installed):

```lua
-- Using lazy.nvim
{ 'echasnovski/mini.nvim' }
```

#### Run all tests

```bash
make test
```

#### Run a specific test file

```bash
make test-file FILE=tests/test_parser.lua
make test-task-manager
make test-telescope
```

#### Run tests with verbose output

```bash
make test-verbose
```

### Test Structure

Tests are organized in the `tests/` directory:

- `tests/test_parser.lua` - YAML frontmatter parsing tests
- `tests/test_task_manager.lua` - Task object creation and management tests
- `tests/test_telescope.lua` - Telescope integration tests (includes regression tests)
- `tests/helpers.lua` - Shared test utilities

### Development Workflow

1. Make changes to the plugin code
2. Write tests for new functionality
3. Run tests to ensure nothing breaks: `make test`
4. Submit a pull request

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

MIT License

## Credits

- Inspired by [TaskNotes](https://github.com/joshklein/obsidian-tasknotes) for Obsidian
- Built with [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- Telescope integration based on patterns from [todo-comments.nvim](https://github.com/folke/todo-comments.nvim)
