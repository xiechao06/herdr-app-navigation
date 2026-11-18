#!/usr/bin/env bash
# Links the mod into the Herdr app and the editor maps into Neovim, then prints
# the keys.json snippet to merge. Re-running is safe.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
app_home="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"
nvim_home="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

mkdir -p "$app_home/mods" "$nvim_home/lua/config"
ln -sfn "$here/mods/pane-nav" "$app_home/mods/pane-nav"
ln -sfn "$here/editor/herdr-nav.lua" "$nvim_home/lua/config/herdr-nav.lua"

if ! grep -q 'require("config.herdr-nav")' "$nvim_home/lua/config/keymaps.lua" 2>/dev/null; then
  printf '\n-- Herdr desktop app: <C-h/j/k/l> across Neovim splits and app panes\nrequire("config.herdr-nav")\n' \
    >> "$nvim_home/lua/config/keymaps.lua"
fi

herdr-app check "$here/mods/pane-nav"

cat <<'MSG'

Linked. Two manual steps remain:

1. Merge keys.snippet.json into the "terminal" section of
   ~/.config/herdr-app/keys.json (the app reloads it live).

2. Show the mod once, so it can receive those key commands:

     herdr-app do mod.open:pane-nav

   It is a zero-size, frameless window; "keep": true in mod.json brings it back
   after a restart or a layout switch.
MSG
