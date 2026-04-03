local M = {}

local defaults = {
  open_cmd = "split",       -- "split" | "vsplit" | "tabnew"
  result_height = 15,       -- window height (only for split mode)
  line_format = "%d: %s",   -- %d = original line number, %s = line content
  highlight = true,         -- highlight matched keywords
}

M.config = vim.deepcopy(defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  M._register_commands()
end

--- Get visual selection text
local function get_visual_selection()
  -- Exit visual mode to update '< and '> marks
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  local start_pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos = vim.api.nvim_buf_get_mark(0, ">")
  local lines = vim.api.nvim_buf_get_text(0, start_pos[1] - 1, start_pos[2], end_pos[1] - 1, end_pos[2] + 1, {})
  return table.concat(lines, "\n")
end

--- Setup keymaps with a given prefix, e.g. setup_keymaps("<leader>f")
--- Binds:
---   {prefix}f  (Normal)  search word under cursor
---   {prefix}f  (Visual)  search selected text
---   {prefix}i  (Normal)  input pattern via vim.ui.input
---   {prefix}r  (Normal)  reset search state
---   {prefix}l  (Normal)  list searched keywords
---@param prefix string key prefix, e.g. "<leader>f"
function M.setup_keymaps(prefix)
  local search = require("step-search.search")

  -- Normal: search word under cursor
  vim.keymap.set("n", prefix .. "f", function()
    local word = vim.fn.expand("<cword>")
    if word ~= "" then
      search.search(word)
    end
  end, { desc = "StepSearch: search word under cursor" })

  -- Visual: search selected text
  vim.keymap.set("x", prefix .. "f", function()
    local text = get_visual_selection()
    if text ~= "" then
      search.search("\\V" .. vim.fn.escape(text, "\\"))
    end
  end, { desc = "StepSearch: search selected text" })

  -- Normal: input pattern via prompt
  vim.keymap.set("n", prefix .. "i", function()
    vim.ui.input({ prompt = "StepSearch pattern: " }, function(input)
      if input and input ~= "" then
        search.search(input)
      end
    end)
  end, { desc = "StepSearch: input search pattern" })

  -- Normal: reset
  vim.keymap.set("n", prefix .. "r", function()
    search.reset()
  end, { desc = "StepSearch: reset" })

  -- Normal: list keywords
  vim.keymap.set("n", prefix .. "l", function()
    search.list_patterns()
  end, { desc = "StepSearch: list keywords" })
end

function M._register_commands()
  vim.api.nvim_create_user_command("StepSearch", function(cmd)
    if cmd.args == "" then
      vim.notify("[StepSearch] Please provide a search pattern", vim.log.levels.WARN)
      return
    end
    require("step-search.search").search(cmd.args)
  end, {
    nargs = 1,
    desc = "Progressive search: search current buffer and append results",
  })

  vim.api.nvim_create_user_command("StepSearchReset", function()
    require("step-search.search").reset()
  end, {
    desc = "Reset search state and clear result buffer",
  })

  vim.api.nvim_create_user_command("StepSearchList", function()
    require("step-search.search").list_patterns()
  end, {
    desc = "List all searched keywords",
  })
end

return M
