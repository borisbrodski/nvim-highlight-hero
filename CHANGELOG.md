# Changelog

## Unreleased — redesign

A ground-up rewrite with a test suite and CI.

### Added
- Numbered highlight groups `0`–`9` via `:HH[!] [N] [text]`, toggled per window.
- `:HHoff [N]` / `:HHoff!` to clear one group or all.
- Live auto-highlight (`:HHauto[!]`, `<leader>hh` / `<leader>hH`) of the word
  under the cursor or the current selection.
- Merge-friendly matching: a linewise selection matches every
  indentation-variant of those lines.
- Colour-blind-safe palette (Okabe–Ito based) with auto-contrast foregrounds,
  256-colour fallbacks, a light-background variant, and `:HHcolors` preview.
  Overridable via `setup({ colors = ... })`.
- Default keymaps `<leader>h0`–`h9`, `<leader>hh` / `hH`, `<leader>ho` / `hO`.
- Test suite (plenary/busted) and GitHub Actions CI (Neovim stable + nightly,
  luacheck, stylua).

### Fixed
- `:HH` no longer errors — the command now receives its arguments, count and
  bang (previously it called into Lua with none and indexed a nil value).
- Smart-space / merge matching no longer drops blank lines or mis-escapes
  `\V` patterns.
- Toggle state is tracked per window instead of in a module-global, so
  highlights no longer leak between windows and buffers.
- Multibyte and blockwise selections are read correctly.

### Changed
- `setup()` is now required; commands, keymaps and highlight groups are
  created there (not at plugin load).
- Group `0` is available again (digit-suffixed maps avoid the bare `0` key).
