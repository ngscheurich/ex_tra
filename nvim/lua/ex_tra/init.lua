local M = {}

---@diagnostic disable-next-line
---@alias ExTraConfig {
---binary_path?: string,
---prompt?: string,
---debug?: boolean}

---@diagnostic disable-next-line
---@alias ExTraTransform
---| "extract_defp"
---| "split_aliases"
---| "toggle_map_keys"
---| "toggle_pipeline"
---| "toggle_string_concat"

---@type ExTraConfig
local default_config = {
  binary_path = vim.fn.expand("~/.config/nvim/lua/ex_tra/ex_tra"),
  prompt = "Elixir Transform",
  debug = false,
}

---@type ExTraConfig
local config = vim.tbl_deep_extend("force", default_config, vim.g.ex_tra or {})

---Notifies the user of an issue or raises with optional context
---@param msg string
---@param context? string
---@param level? integer
local function error_notify(msg, context, level)
  if not level then
    level = vim.log.levels.ERROR
  end

  if config.debug then
    if context then
      error(msg .. ": " .. context, level)
    else
      error(msg, level)
    end
  else
    vim.notify(msg, level)
  end
end

if not config.binary_path then
  error_notify("ex_tra binary path not set")
end

---Makes a system call to the ex_tra binary with `arg`
---@param arg string
---@return boolean
---@return string
local function bincall(arg)
  local result = vim.system({ config.binary_path, arg }):wait()

  if result.code == 0 then
    return true, result.stdout
  else
    return false, result.stderr
  end
end

---Get the current visual selection
---@return boolean
---@return [string, integer, integer]|string
local function get_visual_selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\\22" then
    return false, "Not in visual mode"
  end

  local lnum_start = vim.fn.getpos("v")[2]
  local lnum_end = vim.fn.getpos(".")[2]

  if lnum_start > lnum_end then
    local cached = lnum_start
    lnum_start = lnum_end
    lnum_end = cached
  end

  lnum_start = lnum_start - 1

  local lines = vim.api.nvim_buf_get_lines(0, lnum_start, lnum_end, true)

  if #lines == 0 then
    return false, "No lines selected"
  end

  return true, { table.concat(lines, "\n"), lnum_start, lnum_end }
end

---Try to get a Tree-sitter parent node of `target_type`
---@param current_node TSNode?
---@param target_type string
---@return TSNode?
local function find_parent_of_type(current_node, target_type)
  if not current_node then
    return
  end

  if current_node:type() == target_type then
    return current_node
  end

  local target_node = current_node:parent()

  while target_node and target_node:type() ~= target_type do
    target_node = target_node:parent()
    if target_node and (target_node:type() == target_type) then
      break
    end
  end

  return target_node
end

---Gets the list of available transforms
---@return ExTraTransform[]
local function list_transforms()
  local ok, result = bincall("list_transforms")

  if not ok then
    error_notify("Could not list transforms", result)
    return {}
  end

  local transforms = vim.split(vim.trim(result), ",%s*")
  if #transforms == 0 then
    error_notify("No transforms found", result)
    return {}
  end

  return transforms
end

---Applies a transform to the given text within the start/end region
---@param transform ExTraTransform
---@param text string
---@param line_start integer
---@param line_end integer
local function apply_transform(transform, text, line_start, line_end)
  local result = vim.system({ config.binary_path, transform, text }):wait()
  if result.code ~= 0 then
    error_notify("Error running transform " .. transform, result.stderr)
    return
  end

  if string.match(result.stdout, "^Error:") then
    error_notify("Error running transform " .. transform, result.stdout)
    return
  end

  local lines = vim.split(result.stdout, "\n")
  vim.api.nvim_buf_set_lines(0, line_start, line_end, false, lines)

  vim.lsp.buf.format({ async = true })
end

---Applies a transform to a Tree-sitter node
---@param transform ExTraTransform
---@param node TSNode
local function apply_transform_node(transform, node)
  -- Mapping of transforms to Tree-sitter node types
  local transform_node_types = {
    extract_defp = "call",
    split_aliases = "call",
    toggle_map_keys = "map",
    toggle_pipeline = "binary_operator",
    toggle_string_concat = "map",
  }
  local target_type = transform_node_types[transform]
  local target_node = find_parent_of_type(node, target_type)
  local text = vim.treesitter.get_node_text(target_node, 0)

  if target_node then
    local line_start, _, line_end, _ = target_node:range()
    apply_transform(transform, text, line_start, line_end + 1)
  else
    error_notify("Couldn't find TS node")
  end
end

-- ============================================================================
-- Public API
-- ----------------------------------------------------------------------------
---Applies a transform to the visually selected text; prompts if no transform is given
---@param transform? ExTraTransform
function M.transform_selection(transform)
  local ok, result = get_visual_selection()

  if not ok then
    error_notify("Could not get visual selection", result --[[@as string]])
    return
  end

  local text, lnum_start, lnum_end = result[1], result[2], result[3]

  if transform then
    apply_transform(transform, text, lnum_start, lnum_end)
  else
    local transforms = list_transforms()
    vim.ui.select(transforms, { prompt = config.prompt }, function(choice)
      if choice then
        apply_transform(choice, text, lnum_start, lnum_end)
      end
    end)
  end
end

---Applies a transform to the current TS node (or anscestor)
---@param transform? ExTraTransform
function M.transform_node(transform)
  local current_node = vim.treesitter.get_node()

  if not current_node then
    error_notify("Could not get TS node")
    return
  end

  if transform then
    apply_transform_node(transform, current_node)
  else
    local transforms = list_transforms()
    vim.ui.select(transforms, { prompt = config.prompt }, function(choice)
      if choice then
        apply_transform_node(choice, current_node)
      end
    end)
  end
end

---Sets buffer-local keymaps using an optional prefix
---@param opts? {bufnr?: integer, prefix?: string}
function M.set_keymaps(opts)
  local prefix = "<LocalLeader>t"
  local default_opts = {}

  if opts then
    prefix = opts.prefix or prefix
    if opts.bufnr then
      default_opts.bufnr = opts.bufnr
    end
  end

  -- List of [key, arg, desc] for each keymap
  local map_params = {
    { "t", nil, "Choose transform" },
    { "x", "extract_defp", "Extract private function" },
    { "a", "split_aliases", "Split aliases" },
    { "m", "toggle_map_keys", "Toggle map keys" },
    { "p", "toggle_pipeline", "Toggle pipeline" },
    { "s", "toggle_string_concat", "Toggle string concatenation" },
  }

  for _, tbl in ipairs(map_params) do
    local key, arg, desc = tbl[1], tbl[2], tbl[3]
    local keymap_opts = vim.tbl_extend("force", default_opts, { desc = desc })

    vim.keymap.set("x", prefix .. key, function()
      M.transform_selection(arg)
    end, keymap_opts)

    vim.keymap.set("n", prefix .. key, function()
      M.transform_node(arg)
    end, keymap_opts)
  end
end

return M
