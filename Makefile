.PHONY: test test-file test-verbose test-parser test-task-manager test-telescope help

# Default target: show help
help:
	@echo "tasknotes.nvim Test Runner"
	@echo ""
	@echo "Available targets:"
	@echo "  make test              - Run all tests"
	@echo "  make test-verbose      - Run all tests with verbose output"
	@echo "  make test-parser       - Run parser tests only"
	@echo "  make test-task-manager - Run task manager tests only"
	@echo "  make test-telescope    - Run telescope tests only"
	@echo "  make test-file FILE=<path> - Run specific test file"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make test-file FILE=tests/test_parser.lua"
	@echo "  make test-verbose"

# Run all tests
test:
	@echo "Running all tests..."
	@nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run()" \
		-c "qall"

# Run a specific test file
# Usage: make test-file FILE=tests/test_parser.lua
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE parameter is required"; \
		echo "Usage: make test-file FILE=tests/test_parser.lua"; \
		exit 1; \
	fi
	@echo "Running tests in $(FILE)..."
	@nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('$(FILE)')" \
		-c "qall"

# Run tests with verbose output
test-verbose:
	@echo "Running all tests (verbose)..."
	@nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run({ silent = false })" \
		-c "qall"

# Run parser tests only
test-parser:
	@echo "Running parser tests..."
	@nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('tests/test_parser.lua')" \
		-c "qall"

# Run task manager tests only
test-task-manager:
	@echo "Running task manager tests..."
	@nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('tests/test_task_manager.lua')" \
		-c "qall"

# Run telescope tests only
test-telescope:
	@echo "Running telescope tests..."
	@nvim --headless --noplugin -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('tests/test_telescope.lua')" \
		-c "qall"

# Clean up any test artifacts (if needed in the future)
clean:
	@echo "Cleaning up test artifacts..."
	@find . -type d -name "*.test" -exec rm -rf {} + 2>/dev/null || true
