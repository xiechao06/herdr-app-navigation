-- Herdr desktop-app navigation.
--
-- Inside the Herdr app every terminal carries $HC_TERMINAL_ID and no
-- $HERDR_PANE_ID, so the herdr TUI plugin (nvim-herdr-navigation) stays
-- disabled there. These maps cover the app case only: move between Neovim
-- splits, and at a split edge ask the app to move its focus one pane over.
--
-- Requires the app to hand <C-h/j/k/l> to the terminal: a "terminal" section
-- in ~/.config/herdr-app/keys.json mapping those keys to the "terminal" action.

if vim.env.HC_TERMINAL_ID == nil or vim.env.HC_TERMINAL_ID == "" then
  return
end
if vim.env.HERDR_PANE_ID ~= nil and vim.env.HERDR_PANE_ID ~= "" then
  return
end

local directions = {
  ["<C-h>"] = { wincmd = "h", dir = "left" },
  ["<C-j>"] = { wincmd = "j", dir = "down" },
  ["<C-k>"] = { wincmd = "k", dir = "up" },
  ["<C-l>"] = { wincmd = "l", dir = "right" },
}

local function cross(dir)
  vim.fn.jobstart({ "herdr-app", "do", "pane.go", "--direction", dir }, { detach = true })
end

for lhs, d in pairs(directions) do
  vim.keymap.set("n", lhs, function()
    local prev = vim.api.nvim_get_current_win()
    vim.cmd("wincmd " .. d.wincmd)
    if vim.api.nvim_get_current_win() == prev then
      cross(d.dir)
    end
  end, { silent = true, noremap = true, desc = "Navigate " .. d.dir .. " (neovim/herdr app)" })
end
