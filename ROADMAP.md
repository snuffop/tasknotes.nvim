# TaskNotes.nvim Roadmap

This document outlines potential future enhancements and improvements for tasknotes.nvim.

## High Priority

### 1. Recurring Tasks Support

**Status:** Planned
**Complexity:** High

Implement full support for TaskNotes recurring tasks using RFC 5545 recurrence rules.

**Features:**

- Parse `recurrence` field with DTSTART and RRULE
- Display next occurrence date in task browser
- Handle `complete_instances` and `skipped_instances` arrays
- UI for creating/editing recurrence rules
- Support for `recurrence_anchor` (scheduled vs completion-based)

**Implementation Notes:**

- Consider using a Lua RFC 5545 parser or calling external tools
- Add recurrence picker UI component (daily, weekly, monthly, yearly)
- Update task browser to show "next due" for recurring tasks
- Handle instance completion vs full task completion

**Example Recurrence:**

```yaml
recurrence: "DTSTART:20250804T090000Z;FREQ=WEEKLY;BYDAY=MO"
recurrence_anchor: "scheduled"
complete_instances:
  - "2025-08-04"
  - "2025-08-11"
```

---

### 2. Task Dependencies

**Status:** Planned
**Complexity:** Medium

Support for task blocking/dependency relationships.

**Features:**

- Parse `blockedBy` field (RFC 9253 format)
- Visual indicators in task browser for blocked/blocking tasks
- Dependency graph visualization
- Warnings when completing tasks that block others
- Support for different relationship types:
  - FINISHTOSTART (default)
  - FINISHTOFINISH
  - STARTTOSTART
  - STARTTOFINISH

**Implementation Notes:**

- Add dependency tree view (Telescope or NUI tree component)
- Validate dependencies (prevent circular dependencies)
- Show dependency status in task form
- Add commands to navigate to blocking/blocked tasks

**Example Dependencies:**

```yaml
blockedBy:
  - uid: "[[Operations/Order hardware]]"
    reltype: FINISHTOSTART
    gap: P1D
```

---

### 3. Reminders Integration

**Status:** Planned
**Complexity:** Medium

Support for task reminders with notifications.

**Features:**

- Parse `reminders` array from frontmatter
- Scheduled reminder checking
- Desktop notifications (via `notify-send`, `osascript`, or similar)
- Neovim notifications for active reminders
- UI for adding/editing reminders
- Support for relative and absolute reminders

**Implementation Notes:**

- Use libuv timers for periodic reminder checks
- Integrate with OS notification systems
- Add reminder picker component
- Store reminder state (dismissed, snoozed)

**Example Reminders:**

```yaml
reminders:
  - id: "rem_1678886400000_abc123xyz"
    type: "relative"
    relatedTo: "due"
    offset: "-PT15M"
    description: "Review task details"
  - type: "absolute"
    absoluteTime: "2025-10-26T09:00:00"
```

---

## Medium Priority

### 4. Testing Infrastructure

**Status:** Planned
**Complexity:** Medium

Comprehensive test suite for the plugin.

**Features:**

- Unit tests for parser (YAML parsing, frontmatter extraction)
- Unit tests for task manager (CRUD operations)
- Integration tests with sample vault
- Test helpers and fixtures
- CI/CD integration

**Implementation Notes:**

- Use plenary.nvim test harness
- Create `tests/` directory structure
- Mock file system operations where needed
- Test edge cases (invalid YAML, missing fields, etc.)

**Example Structure:**

```
tests/
├── parser_spec.lua
├── task_manager_spec.lua
├── telescope_spec.lua
├── fixtures/
│   └── sample_vault/
└── minimal_init.lua
```

---

### 5. Calendar Integration

**Status:** Planned
**Complexity:** Medium

Integration with Neovim calendar plugins.

**Features:**

- Calendar view showing tasks by due/scheduled date
- Integration with popular calendar plugins:
  - `nvim-calendar`
  - `calendar.vim`
- Support for `icsEventId` field
- Sync with external calendars (iCal, Google Calendar)
- Visual indicators for tasks on calendar

**Implementation Notes:**

- Add calendar view using NUI or existing calendar plugins
- Parse/generate iCal format
- Handle timezone conversions
- Bi-directional sync considerations

---

### 6. Export Functionality

**Status:** Planned
**Complexity:** Low-Medium

Export tasks to various formats.

**Features:**

- Export to formats:
  - JSON
  - CSV
  - Markdown (summary format)
  - iCal/ICS
  - Todo.txt
- Filter exports by status, priority, date range
- Export current selection or all tasks
- Template-based export system

**Implementation Notes:**

- Add `export.lua` module
- Support for custom export templates
- Commands: `:TaskNotesExport json`, `:TaskNotesExport csv`, etc.

---

### 7. Advanced Filtering & Search

**Status:** Planned
**Complexity:** Medium

Enhanced search and filtering capabilities.

**Features:**

- Full-text search in task body content
- Fuzzy search for task titles
- Complex query syntax (AND, OR, NOT operations)
- Saved searches/filters
- Search history
- Tag-based filtering with hierarchical tags
- Date range filtering (due this week, overdue, etc.)

**Implementation Notes:**

- Extend Telescope picker with custom matcher
- Add query parser for complex searches
- Store saved searches in config
- Add filter presets (My Day, This Week, Overdue, etc.)

**Example Queries:**

```
status:open AND priority:high
tag:work OR tag:urgent
due:<2025-08-20
@home AND NOT status:done
```

---

### 8. Task Templates

**Status:** Planned
**Complexity:** Low-Medium

Support for task templates.

**Features:**

- Define reusable task templates
- Template variables/placeholders
- Quick task creation from templates
- Template library
- Import/export templates

**Implementation Notes:**

- Store templates in plugin config or separate files
- Add template picker UI
- Support for template inheritance
- Variable substitution in title, body, contexts

**Example Template:**

```lua
templates = {
  meeting = {
    title = "Meeting: ${subject}",
    status = "open",
    priority = "normal",
    contexts = { "@work" },
    tags = { "meeting" },
    timeEstimate = 60,
    body = [[
## Agenda

## Notes

## Action Items
    ]],
  },
}
```

---

## Low Priority / Future Ideas

### 9. Subtasks Support

**Status:** Idea
**Complexity:** High

Support for task hierarchies and subtasks.

**Features:**

- Parent/child task relationships
- Nested task view in browser
- Progress tracking (% of subtasks complete)
- Automatic parent status updates
- Indented display in Telescope

**Implementation Notes:**

- Use wikilinks or dedicated frontmatter field
- Tree view component for hierarchies
- Update parser to handle subtask references

---

### 10. Mobile/Web Companion

**Status:** Idea
**Complexity:** Very High

Companion applications for mobile/web access.

**Features:**

- HTTP API server (extending existing TaskNotes API)
- Mobile app (React Native/Flutter)
- Web interface
- Real-time sync with Neovim instance

**Implementation Notes:**

- HTTP server using libuv
- WebSocket for real-time updates
- Authentication/security considerations
- File system watching for changes

---

### 11. AI-Powered Features

**Status:** Idea
**Complexity:** High

Integration with AI for task management.

**Features:**

- AI-suggested task breakdown
- Smart scheduling recommendations
- Context extraction from task descriptions
- Priority suggestions based on patterns
- Time estimate predictions

**Implementation Notes:**

- Integration with LLM APIs (OpenAI, local models)
- Privacy considerations for task data
- Opt-in feature with clear controls

---

### 12. Kanban Board View

**Status:** Idea
**Complexity:** Medium-High

Visual kanban board for task management.

**Features:**

- Column-based view by status
- Drag-and-drop task movement
- Swim lanes by priority or context
- Customizable columns
- WIP limits

**Implementation Notes:**

- NUI-based grid layout
- Update status on column movement
- Configurable board layouts
- Save board state

---

### 13. Time Tracking Enhancements

**Status:** Planned
**Complexity:** Low-Medium

Improvements to existing time tracking.

**Features:**

- Pomodoro timer integration
- Time tracking reports
  - Daily/weekly/monthly summaries
  - By project/context/tag
  - Charts and visualizations
- Idle detection
- Time entry editing/deletion
- Manual time entry addition
- Export time tracking data

**Implementation Notes:**

- Add reporting module
- Integration with charting libraries
- Store timer preferences
- Add time entry management UI

---

### 14. Productivity Analytics

**Status:** Idea
**Complexity:** Medium

Insights and analytics on task patterns.

**Features:**

- Completion rate trends
- Average time per task/project
- Productivity heatmap
- Context switching analysis
- Peak productivity times
- Task velocity metrics

**Implementation Notes:**

- Aggregate historical data
- Visualization components
- Privacy-conscious data collection
- Export analytics data

---

### 15. Plugin Integrations

**Status:** Idea
**Complexity:** Varies

Integration with other Neovim plugins.

**Potential Integrations:**

- **nvim-notify**: Better notifications
- **indent-blankline**: Task list indentation
- **which-key**: Better keymap discovery
- **trouble.nvim**: Show tasks in quickfix-style list
- **nvim-tree**: File tree integration
- **lualine/galaxyline**: Richer statusline components
- **dashboard-nvim**: Task dashboard on startup
- **neorg**: Cross-reference with Neorg tasks

---

### 16. Collaboration Features

**Status:** Idea
**Complexity:** Very High

Multi-user collaboration support.

**Features:**

- Shared task vaults
- Task assignments
- Comments and discussions
- Activity history
- Conflict resolution
- Real-time collaboration

**Implementation Notes:**

- Git-based or custom sync protocol
- User identification system
- Merge conflict handling
- Consider existing TaskNotes collaboration approaches

---

## Contributing

These improvements are open for community contribution! If you'd like to work on any of these features:

1. Open an issue to discuss the implementation approach
2. Create a feature branch
3. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

---

## Priority Guidelines

- **High Priority**: Core functionality, widely requested, high impact
- **Medium Priority**: Valuable additions, good ROI on complexity
- **Low Priority**: Nice-to-have, experimental, or very complex

Priorities may change based on community feedback and usage patterns.
