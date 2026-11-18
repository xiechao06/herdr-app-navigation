# herdr-app-navigation

`ctrl+h/j/k/l` in the Herdr desktop app: move between Neovim splits, and move
between app panes everywhere else. The app's own `pane.go` is program-blind —
once a chord is bound to it, Vim never sees the key. This project adds the
missing decision.

## How it works

A key binding in the app resolves to exactly one action, so the dispatch has to
happen somewhere that can see the focused terminal. That is a mod:

- `mods/pane-nav` — bound to `pane-nav.left/down/up/right`, it reads the focused
  terminal's foreground program (`terminals()` carries `foreground.name`) and
  either forwards the chord into the pane with `hc keys`, or runs `pane.go`.
- `editor/herdr-nav.lua` — in Neovim, `<C-h/j/k/l>` runs `wincmd`; when the
  window does not change (a split edge), it calls
  `herdr-app do pane.go --direction …`. It registers only when
  `$HC_TERMINAL_ID` is set and `$HERDR_PANE_ID` is not, so the herdr TUI keeps
  its own plugin.

The app delivers `<mod>.<command>` only to a copy that is **shown**, and a mod
with `"place": "none"` is never docked, so the mod is a zero-size, frameless
window overlay: invisible, `"keep": true`, opened once with `mod.open`.

## Install

```sh
./install.sh        # links the mod and the Neovim maps, then runs a check
```

Then merge `keys.snippet.json` into the `terminal` section of
`~/.config/herdr-app/keys.json` and show the mod once:

```sh
herdr-app do mod.open:pane-nav
```

## Files

```
mods/pane-nav/main.js     the mod: foreground check, hc keys vs pane.go
mods/pane-nav/mod.json    where it lives: { place: none, overlay: window 0x0 }
editor/herdr-nav.lua      Neovim maps: wincmd, then pane.go at an edge
keys.snippet.json         the bindings to merge into keys.json
install.sh                symlinks both halves, checks the mod
```

## Verify

```sh
herdr-app check mods/pane-nav          # loads it once, reports the exact error
herdr-app status                       # overlays: ["pane-nav"], errors: []
herdr-app do pane-nav.left             # {"ok": true} only if a shown copy listens
```

With a shell focused, `pane-nav.left` moves app focus; with Vim/Neovim focused
it types the chord into that pane instead, and Vim moves between splits.

## Caveats

- The mod only receives commands while its overlay is shown. Switching layouts
  closes windows; returning to the layout reopens kept ones. `herdr-app do
  mod.open:pane-nav` toggles it back if it is ever missing.
- Only Vim-family programs are forwarded; every other program gets `pane.go`.
  Add a regex next to `VIM` in `main.js` (and test it) if a TUI wants the chord.
- `hc keys` is one core round-trip per keypress; navigation lands in a few
  milliseconds on a local core.
- In the app, `<C-l>` also stops being LazyVim's redraw outside a split edge.

## Uninstall

```sh
rm ~/.config/herdr-app/mods/pane-nav
rm ~/.config/nvim/lua/config/herdr-nav.lua
# drop the require("config.herdr-nav") line from nvim's lua/config/keymaps.lua
# and the pane-nav bindings from ~/.config/herdr-app/keys.json
```
