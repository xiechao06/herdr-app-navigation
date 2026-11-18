if vim.g.loaded_herdr_app_navigation == 1 then
  return
end
vim.g.loaded_herdr_app_navigation = 1

local ok, navigation = pcall(require, "herdr-app-navigation")
if not ok then
  vim.notify(
    "herdr-app-navigation: cannot find the module. Add the nested plugin "
      .. "directory to 'runtimepath' (see the install section of the README).",
    vim.log.levels.ERROR
  )
  return
end

navigation.setup()
