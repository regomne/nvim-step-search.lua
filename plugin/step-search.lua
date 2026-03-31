if vim.g.loaded_step_search then
  return
end
vim.g.loaded_step_search = true

-- 自动注册命令（无需手动调用 setup 也能使用基本功能）
require("step-search")._register_commands()
