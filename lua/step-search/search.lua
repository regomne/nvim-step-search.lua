local M = {}

-- Search state per source buffer, keyed by source_bufnr
-- state = {
--   source_bufnr = number,
--   result_bufnr = number,
--   patterns = {},
--   matched_lnums = {},  -- set: {[lnum] = true}
--   matched_lines = {},  -- sorted list: {{lnum=n, text=s}, ...}
-- }
local states = {}

--- Get or create search state for a source buffer
---@param source_bufnr number
---@return table state
local function get_or_create_state(source_bufnr)
  if not states[source_bufnr] then
    states[source_bufnr] = {
      source_bufnr = source_bufnr,
      result_bufnr = nil,
      patterns = {},
      matched_lnums = {},
      matched_lines = {},
    }
  end
  return states[source_bufnr]
end

--- Format matched lines for display
---@param matched_lines table[] {{lnum, text}, ...}
---@return string[]
local function format_lines(matched_lines)
  local config = require("step-search").config
  local fmt = config.line_format or "%d: %s"
  local result = {}
  for _, item in ipairs(matched_lines) do
    table.insert(result, string.format(fmt, item.lnum, item.text))
  end
  return result
end

--- Main search function
---@param pattern string Vim regex pattern
function M.search(pattern)
  -- Validate regex
  local ok_regex = pcall(vim.fn.matchstr, "", pattern)
  if not ok_regex then
    vim.notify("[StepSearch] Invalid Vim regex: " .. pattern, vim.log.levels.ERROR)
    return
  end

  local ui = require("step-search.ui")
  local source_bufnr = vim.api.nvim_get_current_buf()
  local source_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(source_bufnr), ":t")

  local state = get_or_create_state(source_bufnr)

  -- Check if pattern was already searched
  for _, p in ipairs(state.patterns) do
    if p == pattern then
      vim.notify("[StepSearch] Pattern '" .. pattern .. "' already searched", vim.log.levels.INFO)
      return
    end
  end

  table.insert(state.patterns, pattern)

  -- Get all lines from source buffer
  local lines = vim.api.nvim_buf_get_lines(source_bufnr, 0, -1, false)
  local new_count = 0

  for i, line in ipairs(lines) do
    if not state.matched_lnums[i] then
      if vim.fn.match(line, pattern) >= 0 then
        state.matched_lnums[i] = true
        table.insert(state.matched_lines, { lnum = i, text = line })
        new_count = new_count + 1
      end
    end
  end

  -- Sort by line number
  table.sort(state.matched_lines, function(a, b)
    return a.lnum < b.lnum
  end)

  -- Ensure result buffer and window exist
  if not state.result_bufnr or not vim.api.nvim_buf_is_valid(state.result_bufnr) then
    state.result_bufnr = ui.open_result_window(source_bufnr, source_name)
  else
    ui.open_result_window(source_bufnr, source_name)
  end

  -- Write results
  local formatted = format_lines(state.matched_lines)
  ui.update_result_buffer(state.result_bufnr, formatted)

  -- Highlight
  if require("step-search").config.highlight then
    ui.highlight_patterns(state.result_bufnr, state.patterns)
  end

  vim.notify(
    string.format(
      "[StepSearch] '%s': %d new lines, %d total",
      pattern, new_count, #state.matched_lines
    ),
    vim.log.levels.INFO
  )
end

--- Reset search state for current buffer
function M.reset()
  local bufnr = vim.api.nvim_get_current_buf()

  -- If current buffer is a result buffer, get its source
  local ok, source = pcall(vim.api.nvim_buf_get_var, bufnr, "step_search_source_bufnr")
  local source_bufnr = ok and source or bufnr

  local state = states[source_bufnr]
  if not state then
    vim.notify("[StepSearch] No search state for current buffer", vim.log.levels.INFO)
    return
  end

  -- Clear result buffer
  if state.result_bufnr and vim.api.nvim_buf_is_valid(state.result_bufnr) then
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.result_bufnr })
    vim.api.nvim_buf_set_lines(state.result_bufnr, 0, -1, false, {})
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.result_bufnr })
  end

  -- Reset state
  states[source_bufnr] = nil
  vim.notify("[StepSearch] Search state reset", vim.log.levels.INFO)
end

--- List all searched keywords
function M.list_patterns()
  local bufnr = vim.api.nvim_get_current_buf()

  -- If current buffer is a result buffer, get its source
  local ok, source = pcall(vim.api.nvim_buf_get_var, bufnr, "step_search_source_bufnr")
  local source_bufnr = ok and source or bufnr

  local state = states[source_bufnr]
  if not state or #state.patterns == 0 then
    vim.notify("[StepSearch] No keywords searched yet", vim.log.levels.INFO)
    return
  end

  local msg = "[StepSearch] Searched keywords:\n"
  for i, p in ipairs(state.patterns) do
    msg = msg .. string.format("  %d. %s\n", i, p)
  end
  vim.notify(msg, vim.log.levels.INFO)
end

return M
