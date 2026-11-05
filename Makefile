NVIM        ?= nvim
PLENARY_DIR ?= .tests/plenary.nvim

# Files that already conform to stylua/luacheck. Widened as modules are
# rewritten during the redesign.
LINT_FILES = lua tests scripts

.PHONY: test lint format format-check deps clean

deps:
	@test -d $(PLENARY_DIR) || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR)

test: deps
	@PLENARY_DIR=$(PLENARY_DIR) $(NVIM) --headless --noplugin -u scripts/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'scripts/minimal_init.lua', sequential = true}"

lint:
	luacheck $(LINT_FILES)

format-check:
	stylua --check $(LINT_FILES)

format:
	stylua $(LINT_FILES)

clean:
	rm -rf .tests
