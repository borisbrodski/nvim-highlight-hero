# nvim-highlight-hero

[![CI](https://github.com/borisbrodski/nvim-highlight-hero/actions/workflows/ci.yml/badge.svg)](https://github.com/borisbrodski/nvim-highlight-hero/actions/workflows/ci.yml)

Highlight multiple words, selections and whole lines in different colours — on
demand or live as you move. It is handy for spotting typos, tracking a
variable's uses, and especially for **resolving merge conflicts**: it can match
lines while ignoring indentation, so the equal-but-reindented lines light up
together.

The colours are a curated, **colour-blind-safe** palette (built on the
Okabe–Ito set), used as real background colours with automatically
contrast-checked text.

> Neovim port of [vim-highlight-hero](https://github.com/borisbrodski/vim-highlight-hero).

## Features

- **10 highlight groups** (`0`–`9`) you toggle on and off independently.
- **Live auto-highlight** of the word under the cursor or the current
  selection, updating as you move — mirrored into the other windows of the tab
  page (handy for side-by-side diffs and three-way merges; optional).
- **Merge-friendly matching**: a linewise selection matches every
  indentation-variant of those lines.
- **Strong / weak matching** — whole-word + smartcase, or substring +
  case-insensitive.
- **Colour-blind-safe palette** with dark/light variants, 256-colour
  fallbacks, and full override support.

## Requirements

Neovim ≥ 0.10 (uses `vim.fn.getregion`).

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "borisbrodski/nvim-highlight-hero",
  config = function()
    require("nvim-highlight-hero").setup()
  end,
}
```

`setup()` is required — it installs the keymaps, commands and highlight groups.

## Usage

### Commands

| Command | Action |
| --- | --- |
| `:HH [N] [text]` | Highlight the word/selection (or literal `text`) into group `N` (default `0`). Repeat on the same target to toggle it off. |
| `:HH! [N] [text]` | Same, but **weak** matching (substring, case-insensitive). |
| `:HHoff [N]` | Clear group `N` (default: the last group you set). |
| `:HHoff!` | Clear all groups. |
| `:HHauto` / `:HHauto!` | Toggle live auto-highlight (strong / weak). |
| `:HHcolors` | Preview the palette. |

In Visual mode, `:'<,'>HH` highlights the selection.

### Default keymaps

| Key | Action |
| --- | --- |
| `<leader>h0` … `<leader>h9` | Toggle the word (normal) or selection (visual) in group 0–9. |
| `<leader>hh` / `<leader>hH` | Toggle live auto-highlight (strong / weak). |
| `<leader>ho` / `<leader>hO` | Clear the last group / clear all. |

### Resolving merge conflicts

Given a conflict where the same line appears at different indentations:

```
<<<<<<< ours
  if (condition) {
||||||| base
    if (condition) {
=======
  if (condition) {
>>>>>>> theirs
```

Turn on auto-highlight (`<leader>hh`), then linewise-select one `if (condition)`
line with `V`. Every indentation-variant of that line lights up, so you can see
at a glance that only the indentation differs. Where a line's highlight does
*not* appear on another branch, that line really changed.

## Configuration

Defaults:

```lua
require("nvim-highlight-hero").setup({
  -- Digit maps are built as prefix .. 0..9
  prefix = "<leader>h",
  keymaps = {
    toggle_auto = "<leader>hh",
    toggle_auto_weak = "<leader>hH",
    off_last = "<leader>ho",
    off_all = "<leader>hO",
  },
  set_default_keymaps = true,
  auto = {
    -- Live auto-highlight also lights up matches in the other windows of the
    -- current tab page. Set to false to keep it to the current window.
    all_windows = true,
  },
  -- Override group background colours (hex). Foreground/cterm are derived.
  -- colors = { [0] = "#E69F00", auto = "#50566B" },
})
```

### Colours

The ten groups use an Okabe–Ito-based palette as background colours. The
foreground of each is chosen automatically for a contrast ratio ≥ 4.5:1, a
256-colour fallback is computed for terminals, and a light-background variant
deepens the hues so they stay visible on light themes. The palette is tested to
remain distinguishable under simulated deuteranopia and protanopia.

Override any group with `setup({ colors = { [n] = "#rrggbb" } })`, or define the
`NvimHighlightHero0`..`NvimHighlightHero9` / `NvimHighlightHeroAuto` groups
yourself.

## Development

```sh
make test          # headless plenary/busted suite
make lint          # luacheck
make format-check  # stylua
```

CI runs the suite on Neovim stable and nightly, plus luacheck and stylua.

## License

MIT.
