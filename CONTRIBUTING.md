# Contributing to tasknotes.nvim

Thank you for your interest in contributing to tasknotes.nvim! This document provides guidelines and information for contributors.

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/tasknotes.nvim.git
cd tasknotes.nvim
```

2. Install dependencies (via your Neovim plugin manager):
   - nui.nvim
   - telescope.nvim
   - plenary.nvim

3. Set up a test environment with a sample TaskNotes vault

## Project Structure

```
tasknotes.nvim/
├── lua/tasknotes/
│   ├── init.lua              # Main plugin entry point
│   ├── config.lua            # Configuration management
│   ├── parser.lua            # YAML frontmatter parsing
│   ├── task_manager.lua      # Task CRUD operations
│   ├── telescope.lua         # Telescope integration
│   └── ui/
│       ├── task_form.lua     # Task creation/editing forms
│       └── time_tracker.lua  # Time tracking functionality
├── plugin/
│   └── tasknotes.vim         # Vim command definitions
├── README.md
└── LICENSE
```

## Code Style

- Use 2 spaces for indentation
- Follow existing code patterns
- Add comments for complex logic
- Use descriptive variable and function names

## Making Changes

1. Create a new branch for your feature or fix:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes following the code style guidelines

3. Test your changes thoroughly:
   - Test with different TaskNotes configurations
   - Test error cases and edge cases
   - Ensure no regressions in existing functionality

4. Commit your changes with clear, descriptive messages:
```bash
git commit -m "feat: add new feature X"
git commit -m "fix: resolve issue with Y"
```

## Commit Message Convention

Use conventional commit messages:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Test additions or changes
- `chore:` - Maintenance tasks

## Testing

Before submitting a pull request:

1. Test basic functionality:
   - Browse tasks
   - Create new tasks
   - Edit existing tasks
   - Time tracking

2. Test edge cases:
   - Empty vault
   - Invalid YAML
   - Missing dependencies

3. Test with different configurations:
   - Different field mappings
   - Custom statuses and priorities
   - Different UI settings

## Submitting a Pull Request

1. Push your branch to your fork:
```bash
git push origin feature/your-feature-name
```

2. Open a pull request on GitHub

3. Provide a clear description of:
   - What changes you made
   - Why you made them
   - How to test them

4. Wait for review and address any feedback

## Reporting Issues

When reporting issues, please include:

- Neovim version (`nvim --version`)
- Plugin version/commit
- Minimal reproduction steps
- Expected vs actual behavior
- Relevant error messages
- Your configuration

## Feature Requests

Feature requests are welcome! Please:

1. Check if the feature already exists or is planned
2. Describe the feature in detail
3. Explain the use case
4. Consider implementation approaches

## Questions?

Feel free to open an issue for questions or join discussions.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
