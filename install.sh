#!/usr/bin/env bash
# Install pane-nav: the Herdr app mod behind ctrl+h/j/k/l.
#
#   ./install.sh                    from a clone
#   curl -fsSL https://raw.githubusercontent.com/xiechao06/herdr-app-navigation/main/install.sh | bash
#
# Re-running is safe: it updates the copy it installed from, relinks the mod,
# and only adds keys that keys.json is missing. The Neovim side is installed by
# lazy.nvim, not by this script; the spec to paste is printed at the end.
set -euo pipefail

repo=${HERDR_APP_NAV_REPO:-https://github.com/xiechao06/herdr-app-navigation.git}
app_home=${HERDR_APP_HOME:-$HOME/.config/herdr-app}
share=${HERDR_APP_NAV_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/herdr-app-navigation}

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

# 1. Find the files: the clone this script sits in, or our own copy of the repo.
here=""
script=${BASH_SOURCE[0]:-}
if [ -n "$script" ] && [ -f "$script" ]; then
  candidate=$(cd -- "$(dirname -- "$script")" && pwd -P)
  if [ -f "$candidate/mods/pane-nav/main.js" ]; then
    here=$candidate
  fi
fi

if [ -z "$here" ]; then
  if [ -d "$share/.git" ]; then
    say "Updating $share"
    git -C "$share" pull --ff-only --quiet
  else
    say "Cloning to $share"
    mkdir -p -- "$(dirname -- "$share")"
    git clone --depth 1 --quiet -- "$repo" "$share"
  fi
  here=$share
fi

# 2. Link the mod where the app looks for it.
mkdir -p -- "$app_home/mods"
target=$app_home/mods/pane-nav
if [ -e "$target" ] && [ ! -L "$target" ]; then
  warn "$target is a real folder, not a link; left it alone. Move it away and rerun to use this copy."
else
  ln -sfn -- "$here/mods/pane-nav" "$target"
  say "Linked $target -> $here/mods/pane-nav"
fi

# 3. Bind ctrl+h/j/k/l in the terminal section, keeping any key already set.
keys=$app_home/keys.json
if command -v python3 >/dev/null 2>&1; then
  python3 - "$keys" <<'PY' || warn "keys.json left unchanged; merge keys.json by hand (see the README)"
import json, os, shutil, sys, time

path = sys.argv[1]
wanted = {
    "ctrl-h": "pane-nav.left",
    "ctrl-j": "pane-nav.down",
    "ctrl-k": "pane-nav.up",
    "ctrl-l": "pane-nav.right",
}

raw = ""
if os.path.exists(path):
    try:
        with open(path, encoding="utf-8") as f:
            raw = f.read()
    except OSError as error:
        sys.exit(f"warning: cannot read {path}: {error}")

data = {}
if raw.strip():
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as error:
        sys.exit(f"warning: {path} is not valid JSON ({error}); fix it, then rerun")
if not isinstance(data, dict):
    sys.exit(f"warning: {path} is not a JSON object; left it alone")

terminal = data.setdefault("terminal", {})
if not isinstance(terminal, dict):
    sys.exit(f'warning: "terminal" in {path} is not an object; left it alone')

added, kept = [], []
for key, action in wanted.items():
    current = terminal.get(key)
    if current == action:
        continue
    if current is None:
        terminal[key] = action
        added.append(key)
    else:
        kept.append(f"{key} -> {json.dumps(current)}")

if added:
    if os.path.exists(path):
        shutil.copy2(path, f"{path}.bak-{time.strftime('%H%M%S')}")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f'Bound {", ".join(added)} to pane-nav in {path}')
else:
    print(f'{path} already binds ctrl+h/j/k/l to pane-nav')

for line in kept:
    print(f"warning: kept your binding {line} (terminal section); rebind it to pane-nav to use the mod")
PY
else
  warn "python3 not found; merge keys.json by hand (see the README)"
fi

# 4. Load the mod once and report anything wrong with it.
if command -v herdr-app >/dev/null 2>&1; then
  herdr-app check "$here/mods/pane-nav"
  # The mod only receives keys while a copy is shown. Best effort, because the
  # app may not be open yet; "keep": true brings it back after a layout switch.
  # shellcheck disable=SC1010  # "do" is an app subcommand, not a shell keyword
  if out=$(herdr-app do mod.open:pane-nav 2>&1); then
    say "Opened the pane-nav overlay"
  else
    say "Could not open the overlay now ($out)"
    say "Open the app, then run: herdr-app do mod.open:pane-nav"
  fi
else
  warn "herdr-app is not on PATH; skipped checking the mod"
fi

cat <<'MSG'

The app side is installed. For the Neovim side, add this lazy.nvim spec
(~/.config/nvim/lua/plugins/herdr-app-navigation.lua), then restart Neovim:

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

With Neovim running inside the app, ctrl+h/j/k/l moves between splits and
crosses into the neighboring app pane at a split edge.
MSG
