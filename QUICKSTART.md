# Quick Start Guide

Get up and running with tasknotes.nvim in minutes!

## 1. Installation

### Prerequisites

Make sure you have the required dependencies:

```lua
-- Using lazy.nvim
{
  "MunifTanjim/nui.nvim",
  "nvim-telescope/telescope.nvim",
  "nvim-lua/plenary.nvim",
}
```

### Install the Plugin

Add to your Neovim configuration:

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
      vault_path = "~/notes/tasks",  -- Change this to your vault path
    })
  end,
}
```

Restart Neovim and run `:Lazy sync` (or your plugin manager's install command).

## 2. Create Your TaskNotes Vault

Create the directory for your tasks:

```bash
mkdir -p ~/notes/tasks
```

## 3. Create Your First Task

### Method 1: Using the Plugin Form

1. Press `<leader>tn` (or run `:TaskNotesNew`)
2. Fill in the form fields:
   - Title: "My First Task"
   - Status: open
   - Priority: normal
   - Due Date: 2025-08-20 (YYYY-MM-DD format)
3. Press `<C-s>` to save

### Method 2: Create Manually

Create a file `~/notes/tasks/my-first-task.md`:

```markdown
---
title: My First Task
status: open
priority: normal
tags:
  - task
---

This is my first TaskNote!
```

## 4. Browse Your Tasks

Press `<leader>tb` (or run `:TaskNotesBrowse`) to open the Telescope task browser.

### Available Actions in Browser

While in the task browser:

- `<CR>` - Open the task file
- `<C-d>` - Mark task as done
- `<C-e>` - Edit task metadata
- `<C-x>` - Delete task (with confirmation)
- `<C-t>` - Start/stop timer for task

## 5. Time Tracking

### Start a Timer

1. Open a task file or select it in the browser
2. Press `<leader>tt` (or run `:TaskNotesTimerToggle`)
3. The timer starts running

### Stop the Timer

Press `<leader>tt` again to stop and save the time entry.

### View Time Entries

Run `:TaskNotesTimeEntries` to see all tracked time for the current task.

### Show Timer Status

Run `:TaskNotesTimerStatus` to see the currently running timer.

## 6. Common Workflows

### Daily Task Review

1. Press `<leader>tb` to browse all tasks
2. Review open tasks
3. Press `<C-d>` on completed tasks
4. Press `<C-e>` to update priorities or due dates

### Create Task for Current Work

1. While working, press `<leader>tn`
2. Fill in task details
3. Save and continue working
4. Return to browse with `<leader>tb`

### Track Time on Tasks

1. Open task file
2. Press `<leader>tt` to start timer
3. Work on the task
4. Press `<leader>tt` to stop timer
5. Run `:TaskNotesTimeEntries` to see total time

### Filter Tasks by Status

Run `:TaskNotesByStatus` and enter status (e.g., "open", "in-progress", "done")

### Filter Tasks by Priority

Run `:TaskNotesByPriority` and enter priority (e.g., "high", "normal", "low")

## 7. Customization

### Change Vault Location

```lua
require("tasknotes").setup({
  vault_path = "~/Dropbox/tasks",  -- Your custom path
})
```

### Customize Keymaps

```lua
require("tasknotes").setup({
  keymaps = {
    browse = "<leader>ft",      -- Find tasks
    new_task = "<leader>nt",    -- New task
    edit_task = "<leader>et",   -- Edit task
    toggle_timer = "<C-t>",     -- Toggle timer
  },
})
```

### Add Custom Statuses

```lua
require("tasknotes").setup({
  statuses = {
    { name = "backlog", display = "Backlog", color = "#666666", is_completed = false },
    { name = "todo", display = "To Do", color = "#0066cc", is_completed = false },
    { name = "doing", display = "Doing", color = "#ffaa00", is_completed = false },
    { name = "done", display = "Done", color = "#00aa00", is_completed = true },
  },
})
```

### Statusline Integration

Show the active timer in your statusline:

```lua
-- With lualine
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

## 8. Tips & Tricks

### Use Contexts for Location-Based Tasks

Prefix contexts with `@`:

```yaml
contexts:
  - "@home"
  - "@office"
  - "@computer"
```

### Link Tasks to Projects

Use wikilinks in the projects field:

```yaml
projects:
  - "[[Project Alpha]]"
  - "[[Q3 Goals]]"
```

### Set Realistic Time Estimates

Use the timeEstimate field to plan your day:

```yaml
timeEstimate: 60 # minutes
```

### Review Your Task Vault Regularly

Run `:TaskNotesRescan` to refresh the task index after manually editing files.

### Use Date Formats Consistently

Always use YYYY-MM-DD format for dates:

```yaml
due: 2025-08-20
scheduled: 2025-08-19
```

## 9. Troubleshooting

### Tasks Not Showing Up?

1. Check that your vault path is correct: `:lua print(require("tasknotes").config.get().vault_path)`
2. Ensure files have the `task` tag in frontmatter
3. Run `:TaskNotesRescan` to refresh the index

### Form Not Appearing?

Make sure `nui.nvim` is installed: `:lua print(vim.inspect(require("nui.popup")))`

### Telescope Not Working?

1. Check telescope is installed: `:Telescope`
2. Verify tasknotes extension loaded: `:Telescope tasknotes tasks`

### Timer Not Saving?

1. Check file permissions on your vault directory
2. Verify the task file exists and is readable
3. Look for error messages: `:messages`

## 10. Next Steps

- Read the [full documentation](README.md)
- Check out [example configurations](examples/init.lua)
- Review [planned features](ROADMAP.md)
- Explore the [API](doc/tasknotes.txt)

## Getting Help

- Open an issue on GitHub
- Check existing issues for solutions
- Share your use cases and workflows

Happy task managing! 🚀
