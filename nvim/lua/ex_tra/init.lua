local M = {}

-- Default configuration with sane default
local config = {
  binary_path = vim.fn.expand("~/.config/nvim/lua/ex_tra/ex_tra"),
}

-- Setup function for users who want to override the default
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
end

local function get_visual_selection()
  local pos_start = vim.fn.getpos("'<")
  local pos_end = vim.fn.getpos("'>")
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, pos_start[2]-1, pos_end[2], false)
  -- If selection is within a single line, trim
  if #lines == 1 then
    lines[1] = string.sub(lines[1], pos_start[3], pos_end[3])
  else
    lines[1] = string.sub(lines[1], pos_start[3])
    lines[#lines] = string.sub(lines[#lines], 1, pos_end[3])
  end
  return table.concat(lines, "\n"), pos_start[2]-1, pos_end[2]
end

local function escape_arg(str)
  str = str:gsub("\\", "\\\\")
  str = str:gsub("\"", "\\\"")
  str = str:gsub("#%{", "\\#{")
  return str
end

function M.ex_tra()
   if not config.binary_path then
    vim.notify("ex_tra not configured! Call require('ex_tra').setup({binary_path = '/path/to/ex_tra'})", vim.log.levels.ERROR)
    return
   end

  -- Get selection
  local selected, line_start, line_end = get_visual_selection()
  if not selected or selected == "" then
    vim.notify("No text selected!", vim.log.levels.ERROR)
    return
  end

  -- List transforms
  local transforms_raw = vim.fn.system(config.binary_path .. " list_transforms")
  if vim.v.shell_error ~= 0 then
    vim.notify("Error running extra list_transforms", vim.log.levels.ERROR)
    return
  end
  local transforms = vim.split(vim.trim(transforms_raw), ",%s*")
  if #transforms == 0 then
    vim.notify("No transforms found!", vim.log.levels.ERROR)
    return
  end

  -- Show numbered choice
  local numbered = {}
  for i, val in ipairs(transforms) do
    numbered[i] = string.format("%d. %s", i, val)
  end
  local choice = vim.fn.inputlist(vim.list_extend({ "Elixir Transform:" }, numbered))
  if choice < 1 or choice > #transforms then
    vim.notify("No command selected!", vim.log.levels.ERROR)
    return
  end
  local transform = transforms[choice]

  -- Run transform
  local escaped = escape_arg(selected)
  local result = vim.fn.system(string.format('%s %s "%s"', config.binary_path, transform, escaped))
  if vim.v.shell_error ~= 0 then
    vim.notify("Error running transform: " .. result, vim.log.levels.ERROR)
    return
  end

  -- Replace buffer lines
  local result_lines = vim.split(result, "\n")
  vim.api.nvim_buf_set_lines(0, line_start, line_end, false, result_lines)

  -- Optionally format
  vim.lsp.buf.format({ async = true })
end

-- Keymap for visual mode (you can change <leader>tt)
vim.api.nvim_set_keymap('x', '<leader>tt',
  [[:lua require('ex_tra').ex_tra()<CR>]],
  { noremap = true, silent = true })

return M
