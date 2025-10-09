# Configuration Examples

This directory contains example configuration files demonstrating various necromancer features.

## `dependencies-example.json`

Demonstrates plugin dependency management:

- **Installation order**: `plenary.nvim` → `nvim-treesitter` → `telescope.nvim` → `telescope-ui-select.nvim` → `nvim-treesitter-textobjects`
- **Dependency relationships**:
  - `telescope.nvim` depends on `plenary.nvim`
  - `telescope-ui-select.nvim` depends on `telescope.nvim` (and transitively on `plenary.nvim`)
  - `nvim-treesitter-textobjects` depends on `nvim-treesitter`

To use this example:

```bash
# Copy the example configuration
cp examples/dependencies-example.json .necromancer.json

# Install all plugins in the correct dependency order
necromancer install --verbose
```

The `--verbose` flag will show the dependency resolution process and installation order.

## Key Points

1. **Automatic Resolution**: You don't need to manually order plugins in your configuration - necromancer automatically resolves the correct installation order using topological sorting.

2. **Validation**: Necromancer validates that:
   - All dependencies are defined in the configuration
   - No circular dependencies exist
   - Dependency names are valid

3. **Transitive Dependencies**: If Plugin A depends on Plugin B, and Plugin B depends on Plugin C, then Plugin C will be installed before Plugin B, and Plugin B will be installed before Plugin A.

4. **Error Handling**: If there are dependency issues (missing dependencies, circular dependencies), necromancer will provide clear error messages and exit without making any changes.