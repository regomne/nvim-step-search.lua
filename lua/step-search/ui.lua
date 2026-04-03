local M = {}

-- Highlight groups, cycling through 8 colors
local highlight_groups = {
  "StepSearchMatch1",
  "StepSearchMatch2",
  "StepSearchMatch3",
  "StepSearchMatch4",
  "StepSearchMatch5",
  "StepSearchMatch6",
  "StepSearchMatch7",
  "StepSearchMatch8",
}

local colors_defined = false

local function define_highlight_groups()
  if colors_defined then
    return
  end
  local colors = {
    { fg = "#ffaf00", bg = "#3a3000" }, -- yellow
    { fg = "#87d7ff", bg = "#002a3a" }, -- blue
    { fg = "#87ff87", bg = "#003a00" }, -- green
    { fg = "#ff87af", bg = "#3a0020" }, -- pink
    { fg = "#d7afff", bg = "#2a003a" }, -- purple
    { fg = "#ffaf87", bg = "#3a2000" }, -- orange
    { fg = "#87ffd7", bg = "#003a2a" }, -- cyan
    { fg = "#ff8787", bg = "#3a0000" }, -- red
  }
  for i, c in ipairs(colors) do
    vim.api.nvim_set_hl(0, highlight_groups[i], { fg = c.fg, bg = c.bg, bold = true })
  end
  colors_defined = true
end

--- Open or get result window, return result buffer number
---@param source_bufnr number
---@param source_name string
---@return number result_bufnr
function M.open_result_window(source_bufnr, source_name)
  local config = require("step-search").config

  -- Check if source buffer already has an associated result buffer
  local ok, existing = pcall(vim.api.nvim_buf_get_var, source_bufnr, "step_search_result_bufnr")
  if ok and existing and vim.api.nvim_buf_is_valid(existing) then
    -- Try to find a window displaying this buffer
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == existing then
        return existing
      end
    end
    -- Buffer exists but no window, reopen
    M._open_window(config, existing)
    return existing
  end

  -- Create new scratch buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  local display_name = source_name ~= "" and source_name or ("[buf:" .. source_bufnr .. "]")
  vim.api.nvim_buf_set_name(bufnr, "[StepSearch: " .. display_name .. "]")
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "stepsearch", { buf = bufnr })

  -- Link source buffer and result buffer
  vim.api.nvim_buf_set_var(source_bufnr, "step_search_result_bufnr", bufnr)
  vim.api.nvim_buf_set_var(bufnr, "step_search_source_bufnr", source_bufnr)

  -- Open window
  M._open_window(config, bufnr)

  return bufnr
end

function M._open_window(config, bufnr)
  local cmd = config.open_cmd or "split"

  -- Save current window to jump back later
  local source_win = vim.api.nvim_get_current_win()

  if cmd == "split" then
    vim.cmd("botright " .. (config.result_height or 15) .. "split")
  elseif cmd == "vsplit" then
    vim.cmd("botright vsplit")
  elseif cmd == "tabnew" then
    vim.cmd("tabnew")
  else
    vim.cmd("botright split")
  end

  vim.api.nvim_win_set_buf(0, bufnr)

  -- Jump back to source window (not for tabnew mode)
  if cmd ~= "tabnew" then
    vim.api.nvim_set_current_win(source_win)
  end
end

--- Write formatted lines to result buffer
---@param bufnr number
---@param lines string[]
function M.update_result_buffer(bufnr, lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- Highlight searched keywords in result buffer
---@param bufnr number
---@param patterns string[]
function M.highlight_patterns(bufnr, patterns)
  define_highlight_groups()

  -- Clear old highlights
  local ns = vim.api.nvim_create_namespace("step_search_hl")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    -- Sanitize: strip NUL bytes to prevent "Using a Blob as a String" errors
    if type(line) ~= "string" then
      line = tostring(line) or ""
    end
    line = line:gsub("%z", "")
    for pi, pattern in ipairs(patterns) do
      local hl_group = highlight_groups[((pi - 1) % #highlight_groups) + 1]
      -- Find all match positions
      local pos = 0
      while true do
        -- matchstrpos(expr, pat, start) returns [matched_str, start_byte, end_byte]
        local result = vim.fn.matchstrpos(line, pattern, pos)
        local matched = result[1]
        local col_start = result[2]
        local col_end = result[3]
        if matched == "" and col_start == -1 then
          break
        end
        if col_start >= 0 and col_end > col_start then
          vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, i - 1, col_start, col_end)
        end
        pos = col_end
        -- Prevent infinite loop on zero-width matches
        if col_start == col_end then
          pos = pos + 1
        end
        if pos >= #line then
          break
        end
      end
    end
  end
end

return M
