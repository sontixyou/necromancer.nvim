.PHONY: test test-lua test-ts test-deps lint build clean

# Default test runs both TypeScript and Lua tests
test: test-ts test-lua

# Run TypeScript tests (existing tests)
test-ts:
	npm test

# Run Lua tests with plenary.nvim
# Use NVIM_APPNAME for isolation from user config
test-lua: test-deps
	NVIM_APPNAME=necromancer_test nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/necromancer/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"

# Run a specific Lua test file
# Usage: make test-file FILE=tests/necromancer/core/config_spec.lua
test-file: test-deps
	NVIM_APPNAME=necromancer_test nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile $(FILE)"

# Install test dependencies (plenary.nvim)
test-deps:
	@mkdir -p test_deps
	@if [ ! -d "test_deps/plenary.nvim" ]; then \
		echo "Installing plenary.nvim..."; \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim test_deps/plenary.nvim; \
	fi

# TypeScript lint check
lint:
	npm run lint

# Build TypeScript
build:
	npm run build

# Clean build artifacts and test dependencies
clean:
	rm -rf dist/
	rm -rf coverage/
	rm -rf test_deps/
	rm -rf node_modules/

# Help
help:
	@echo "Available targets:"
	@echo "  test       - Run all tests (TypeScript + Lua)"
	@echo "  test-ts    - Run TypeScript tests only"
	@echo "  test-lua   - Run Lua tests only"
	@echo "  test-file  - Run a specific Lua test file (FILE=path)"
	@echo "  test-deps  - Install test dependencies"
	@echo "  lint       - Run TypeScript lint check"
	@echo "  build      - Build TypeScript"
	@echo "  clean      - Clean build artifacts"
