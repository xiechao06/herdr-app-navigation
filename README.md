# herdr-app-navigation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

`ctrl+h/j/k/l` in the Herdr **desktop app**: move between Neovim splits, and
between app panes everywhere else. It is a `vim-tmux-navigator` for the app —
one set of keys for Neovim windows and app panes.

```text
ctrl+h  move left
ctrl+j  move down
ctrl+k  move up
ctrl+l  move right
```

```text
Neovim splits  ──wincmd──▶  next split in that direction
                            └─ nothing there? ─▶ neighboring app pane
shell, agent, lazygit  ───────────────────────▶  neighboring app pane
```

## Why it needs two halves

A key in the app resolves to exactly one action, and the app's `pane.go` is
program-blind: once a chord is bound to it, Vim never sees the key. So the
decision has to be made somewhere that can see the focused terminal.

| Half | Directory | Installed by | What it does |
| --- | --- | --- | --- |
| App mod | `mods/pane-nav/` | `install.sh` (one line) | reads the focused terminal's foreground program: forwards the chord into Vim, runs `pane.go` for everything else |
| Neovim plugin | `nvim-herdr-app-navigation/` | `lazy.nvim` | runs `wincmd`; at a split edge asks the app for `pane.go` |

The herdr **TUI** is a different program with its own plugin system and is not
covered here: inside the app every terminal carries `$HC_TERMINAL_ID` and no
`$HERDR_PANE_ID`, which is how both halves tell the two apart.

## Install the Herdr app mod

One line, no clone:

```sh
curl -fsSL https://raw.githubusercontent.com/xiechao06/herdr-app-navigation/main/install.sh | bash
```

Or from a checkout:

```sh
git clone https://github.com/xiechao06/herdr-app-navigation
cd herdr-app-navigation
./install.sh
```

Either way it clones (or updates) the repo at
`~/.local/share/herdr-app-navigation`, links `mods/pane-nav` into
`~/.config/herdr-app/mods/pane-nav`, and runs `herdr-app check`.

Verify the app sees it:

```sh
herdr-app status     # overlays: ["pane-nav"], errors: []
```

## Configure the ctrl+h/j/k/l key bindings

`install.sh` adds these to the `terminal` section of
`~/.config/herdr-app/keys.json` when they are missing, and leaves any key you
already bound alone (it tells you which ones it kept):

```json
{
  "terminal": {
    "ctrl-h": "pane-nav.left",
    "ctrl-j": "pane-nav.down",
    "ctrl-k": "pane-nav.up",
    "ctrl-l": "pane-nav.right"
  }
}
```

The `terminal` section wins over `global`, so a `global` `ctrl-h: "pane.go:left"`
can stay: the app only uses it when no terminal has focus. The app reloads the
file live.

To merge by hand, append the four keys above to the `terminal` object in
`~/.config/herdr-app/keys.json`.

## Install the Neovim plugin with lazy.nvim

The Neovim plugin lives in a subdirectory of this repository, so add the nested
directory to `runtimepath` in `init`:

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

Save it as `~/.config/nvim/lua/plugins/herdr-app-navigation.lua` and restart
Neovim.

Details that matter for lazy.nvim and LazyVim users:

- `init` adds the nested plugin directory to `runtimepath`; without it
  `require("herdr-app-navigation")` fails.
- `event = "VeryLazy"` plus `vim.schedule()` lets this plugin override LazyVim's
  default `<C-h/j/k/l>` window mappings inside the app.
- `cond` keeps the plugin out of the way outside the app, where your own
  mappings (or `vim-tmux-navigator`) keep working.

Working on the plugin itself? Point lazy at a checkout instead, so edits are
live:

```lua
return {
  dir = vim.fn.expand("~/workspace/herdr-app-navigation"),
  name = "herdr-app-navigation",
  cond = function()
    return vim.env.HC_TERMINAL_ID ~= nil
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

## Options

```lua
require("herdr-app-navigation").setup({
  keybindings = { left = "<C-h>", down = "<C-j>", up = "<C-k>", right = "<C-l>" },
  bin = "herdr-app",              -- or $HERDR_APP_BIN
  commands = true,                -- :HerdrAppNavigateLeft/Down/Up/Right
  tmux_compat_commands = false,   -- also :TmuxNavigateLeft/Down/Up/Right
})
```

Commands, whether or not you keep the maps:

```vim
:HerdrAppNavigateLeft
:HerdrAppNavigateDown
:HerdrAppNavigateUp
:HerdrAppNavigateRight
```

## Test it

Open the app, open a pane running Neovim, and create a couple of splits
(`:vsplit`, `:split`):

- `ctrl+h/j/k/l` in Neovim moves one split, as before.
- At a split edge the same key moves focus to the neighboring app pane.
- In a shell, agent or lazygit pane the same key moves app focus directly.
- Shift focus back with `ctrl+h/j/k/l` and Neovim takes over again.

## How it works

1. The app resolves `ctrl+h` to `pane-nav.left` from `keys.json`.
2. The mod reads the focused terminal's foreground program.
3. Vim-family program: the mod types the chord into that pane with `hc keys`.
   The Neovim plugin runs `wincmd h`; if focus did not move, it runs
   `herdr-app do pane.go --direction left`.
4. Anything else (shell, agent, TUI): the mod runs `pane.go` itself.

The app delivers `<mod>.<command>` only while a copy of the mod is **shown**, so
the mod lives as a zero-size frameless window overlay (`"place": "none"`,
`"keep": true`). `install.sh` opens it once with `herdr-app do mod.open:pane-nav`;
`keep` brings it back after a restart or a layout switch.

## Troubleshooting

### ctrl+h/j/k/l moves app panes but never Neovim splits

The mod is not receiving the key, or is forwarding it too eagerly. Check the
overlay is shown, then the bindings:

```sh
herdr-app status
herdr-app ls
```

`overlays` must list `pane-nav`. If it is missing, show it again:

```sh
herdr-app do mod.open:pane-nav
```

### Neovim moves between splits but never to the neighboring pane at an edge

The plugin is loaded but cannot reach the app:

```vim
:lua print(vim.env.HC_TERMINAL_ID, vim.fn.executable("herdr-app"))
:lua print(vim.inspect(vim.fn.maparg("<C-l>", "n", false, true)))
```

The mapping should carry `desc = "Herdr app navigate right"`. If it maps to
`<C-w>l`, or says `Go to Right Window`, another config is overriding the plugin:
load this one later (`event = "VeryLazy"` plus `vim.schedule()`).

### It does nothing at all in Neovim

The `cond` matched outside the app, or the nested directory is not on
`runtimepath`. Inside the app `:lua print(vim.env.HC_TERMINAL_ID)` prints an id;
outside it prints `nil`, which is what `cond` uses.

### `hc keys` types the chord but Vim does something else

`<C-l>` also being LazyVim's redraw is expected: at a split edge the key crosses
instead of redrawing. Use `:redraw!` or bind redraw elsewhere if you want both.

## Repository layout

```text
mods/pane-nav/               the app mod: foreground check, hc keys vs pane.go
mods/pane-nav/mod.json       where it lives: { place: none, overlay: window 0x0 }
nvim-herdr-app-navigation/   the Neovim plugin: wincmd, then pane.go at an edge
keys.json                    the bindings, to merge into the app's keys.json
install.sh                   clone/link the mod, merge the keys, check it
uninstall.sh                 remove the link, list the keys to drop
```

The mod folder follows the app's sharing convention
(`mods/<name>/` plus `keys.json`), so it can also be published to
`herdr.dev/mods` with the repo topic `herdr-mod`.

## Requirements

- Herdr desktop app with mods (`herdr-app` on `$PATH`)
- Neovim 0.8 or newer, with `lazy.nvim` or another plugin manager
- `git` for the one-line install; `python3` to merge `keys.json` automatically

## Uninstall

```sh
./uninstall.sh
```

Then delete `~/.config/nvim/lua/plugins/herdr-app-navigation.lua` and, if you
do not keep a checkout, `~/.local/share/herdr-app-navigation`.

## Caveats

- Only Vim-family programs are forwarded; every other program gets `pane.go`.
  Add a name to `VIM` in `mods/pane-nav/main.js` if a TUI wants the chord.
- `hc keys` is one core round-trip per keypress; navigation lands in a few
  milliseconds on a local core.
- Switching layouts closes windows. A kept overlay is reopened on return; if it
  is ever missing, `herdr-app do mod.open:pane-nav` toggles it back.

## License

MIT. See [LICENSE](LICENSE).

## Discoverability

Herdr app navigation, herdr-app pane navigation, Neovim pane navigation in
Herdr, vim-tmux-navigator for the Herdr desktop app, LazyVim ctrl h j k l across
app panes, terminal multiplexer navigation, Neovim split navigation fallback.
