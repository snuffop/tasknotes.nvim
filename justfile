# tasknotes.nvim Test Runner

# List available recipes
@default:
    just --list

# Run all tests
@test:
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "lua MiniTest.run()" \
        -c "qall"

# Run a specific test file
@test-file FILE:
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "lua MiniTest.run_file('{{FILE}}')" \
        -c "qall"

# Run tests with verbose output
@test-verbose:
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "lua MiniTest.run({ silent = false })" \
        -c "qall"

# Run parser tests only
@test-parser:
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "lua MiniTest.run_file('tests/test_parser.lua')" \
        -c "qall"

# Run task manager tests only
@test-task-manager:
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "lua MiniTest.run_file('tests/test_task_manager.lua')" \
        -c "qall"

# Run telescope tests only
@test-telescope:
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "lua MiniTest.run_file('tests/test_telescope.lua')" \
        -c "qall"

# Clean up test artifacts
@clean:
    find . -type d -name "*.test" -exec rm -rf {} + 2>/dev/null || true
