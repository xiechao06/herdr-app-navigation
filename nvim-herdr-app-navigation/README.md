# nvim-herdr-app-navigation

Neovim side of `herdr-app-navigation`: `ctrl+h/j/k/l` moves between Neovim
splits and, at a split edge, moves focus to the neighboring Herdr app pane.

Pair this with the `mods/pane-nav` mod in the repository root, which forwards
the chord into Vim panes and moves app focus everywhere else.

## Install with lazy.nvim

The plugin lives in a subdirectory, so add it to `runtimepath` in `init`:

```lua
return {
  "xiechao06/herdr-app-navigation",
  submodules = false,
  cond = function()
    return vim.env.HC_TERMINAL_ID ~= nil and vim.env.HERDR_PANE_ID == nil
  end,
  event = "VeryLazy",
  init = function(plugin)
    vim.opt.rtp:prepend(plugin.dir .. "/nvim-herdr-app-navigation")
  end,
  config = function()
    vim.schedule(function()
      require("herdr-app-navigation").setup()
    end)
  end,
}
```

Use `cond` so the plugin never loads outside the app, and `event = "VeryLazy"`
plus `vim.schedule()` so its maps win over LazyVim's default `<C-h/j/k/l>`
window mappings.

Without a plugin manager:

```lua
vim.opt.rtp:prepend("~/path/to/herdr-app-navigation/nvim-herdr-app-navigation")
require("herdr-app-navigation").setup()
```

## Options

```lua
require("herdr-app-navigation").setup({
  keybindings = { left = "<C-h>", down = "<C-j>", up = "<C-k>", right = "<C-l>" },
  bin = "herdr-app",              -- or $HERDR_APP_BIN
  commands = true,
  tmux_compat_commands = false,
})
```

`keybindings` entries set to `nil` or `""` are skipped, so you can keep your own
mapping for one direction.

## Commands

```vim
:HerdrAppNavigateLeft
:HerdrAppNavigateDown
:HerdrAppNavigateUp
:HerdrAppNavigateRight
```

With `tmux_compat_commands = true`, also:

```vim
:TmuxNavigateLeft
:TmuxNavigateDown
:TmuxNavigateUp
:TmuxNavigateRight
```

## Behavior

- If Neovim can move to a split in that direction, it does and the app is never
  called.
- If focus did not move, the plugin runs
  `herdr-app do pane.go --direction …` detached, so Neovim does not wait.
- Outside the app (`$HC_TERMINAL_ID` unset) nothing is mapped and nothing runs.

## Troubleshooting

If Neovim moves between splits but never crosses at an edge, check the mapping
and the CLI:

```vim
:lua print(vim.inspect(vim.fn.maparg("<C-l>", "n", false, true)))
:lua print(vim.fn.executable("herdr-app"))
```

The mapping should carry `desc = "Herdr app navigate right"`. If it maps to
`<C-w>l`, another config is overriding the plugin.
