#!/usr/bin/env bash
# Remove what install.sh added: the mod link, and the key bindings that point
# at it. The Neovim spec and its clone are yours to delete.
set -euo pipefail

app_home=${HERDR_APP_HOME:-$HOME/.config/herdr-app}
target=$app_home/mods/pane-nav

if [ -L "$target" ]; then
  rm -- "$target"
  printf 'Removed %s\n' "$target"
elif [ -e "$target" ]; then
  printf 'warning: %s is a real folder, not a link; left it alone\n' "$target" >&2
else
  printf 'Nothing at %s\n' "$target"
fi

cat <<'MSG'

One manual step: delete the pane-nav bindings from the "terminal" section of
~/.config/herdr-app/keys.json, or the keys will point at a mod that is gone:

  "ctrl-h": "pane-nav.left",
  "ctrl-j": "pane-nav.down",
  "ctrl-k": "pane-nav.up",
  "ctrl-l": "pane-nav.right"

Then delete the lazy.nvim spec
(~/.config/nvim/lua/plugins/herdr-app-navigation.lua) and, if this copy is not
one you keep, the clone at ~/.local/share/herdr-app-navigation.
MSG
