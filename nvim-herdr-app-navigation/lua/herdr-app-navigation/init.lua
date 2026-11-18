-- Neovim half of Herdr app navigation.
--
-- The Herdr app routes ctrl+h/j/k/l to the pane-nav mod, which forwards the
-- chord into Vim/Neovim panes. These maps then move between Neovim splits and,
-- at a split edge, ask the app to move its focus one pane over.

local M = {}

local config = {
  keybindings = {
    left = "<C-h>",
    down = "<C-j>",
    up = "<C-k>",
    right = "<C-l>",
  },
  -- Program that talks to the running app. The app itself is not on PATH
  -- inside its own terminal, so this is only the CLI entry point.
  bin = nil,
  -- Create :HerdrAppNavigateLeft/Down/Up/Right.
  commands = true,
  -- Also create :TmuxNavigateLeft/Down/Up/Right, for configs that already map
  -- those names to vim-tmux-navigator.
  tmux_compat_commands = false,
}

local directions = {
  left = { wincmd = "h" },
  down = { wincmd = "j" },
  up = { wincmd = "k" },
  right = { wincmd = "l" },
}

local commands_created = false
local compat_created = false

local function bin()
  return config.bin or vim.env.HERDR_APP_BIN or "herdr-app"
end

-- Inside the app every terminal carries $HC_TERMINAL_ID and no $HERDR_PANE_ID;
-- the herdr TUI (and its own navigator plugin) uses the opposite. That is what
-- keeps the two halves from fighting over <C-h/j/k/l>.
function M.enabled()
  local terminal = vim.env.HC_TERMINAL_ID
  local pane = vim.env.HERDR_PANE_ID
  return terminal ~= nil and terminal ~= "" and (pane == nil or pane == "")
end

local function cross(direction)
  if vim.fn.executable(bin()) ~= 1 then
    return false
  end
  -- One detached round-trip; Neovim must not block on the app's reply.
  return vim.fn.jobstart(
    { bin(), "do", "pane.go", "--direction", direction },
    { detach = true }
  ) > 0
end

-- Move inside Neovim first; only ask the app when focus did not change.
function M.navigate(direction)
  local move = directions[direction]
  if move == nil then
    return false
  end

  local before = vim.api.nvim_get_current_win()
  if not pcall(vim.cmd, "wincmd " .. move.wincmd) then
    return false
  end
  if vim.api.nvim_get_current_win() ~= before then
    return true
  end

  return cross(direction)
end

function M.left()
  return M.navigate("left")
end

function M.down()
  return M.navigate("down")
end

function M.up()
  return M.navigate("up")
end

function M.right()
  return M.navigate("right")
end

local function create_command(name, direction)
  if vim.fn.exists(":" .. name) == 2 then
    return
  end
  vim.api.nvim_create_user_command(name, function()
    M.navigate(direction)
  end, { desc = "Herdr app navigate " .. direction })
end

local function create_commands()
  if config.commands and not commands_created then
    for direction in pairs(directions) do
      create_command("HerdrAppNavigate" .. direction:sub(1, 1):upper() .. direction:sub(2), direction)
    end
    commands_created = true
  end

  if config.tmux_compat_commands and not compat_created then
    for direction in pairs(directions) do
      create_command("TmuxNavigate" .. direction:sub(1, 1):upper() .. direction:sub(2), direction)
    end
    compat_created = true
  end
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  if not M.enabled() then
    -- Outside the app, leave every key alone: the person's own mappings, or
    -- vim-tmux-navigator, keep working there.
    return M
  end

  create_commands()

  for direction, lhs in pairs(config.keybindings or {}) do
    if directions[direction] ~= nil and lhs ~= nil and lhs ~= "" then
      vim.keymap.set("n", lhs, function()
        M.navigate(direction)
      end, { silent = true, noremap = true, desc = "Herdr app navigate " .. direction })
    end
  end

  return M
end

return M
