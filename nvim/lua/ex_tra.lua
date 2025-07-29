---@alias selection
---| { start_pos: integer, end_pos: integer, text: string}

---@alias buffer_id integer

---Get the `extra` binary location.
---@return string
local function extra_bin()
	return vim.g.elixir_transform_extra_bin or "extra"
end

---Shell-escape characters in a string.
---@param str string
---@return string
local function escape(str)
	local s = string.gsub(str, "\\", "\\\\")
	s = string.gsub(str, '"', '\\"')
	s = string.gsub(str, "#{", "\\#{")
	return s
end

---List the transforms supported by the `extra` binary.
---@return string[] | nil
local function list_transforms()
	local cmd = extra_bin() .. " list_transforms"
	local raw_transforms = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.api.nvim_err_writeln("Error running 'extra list_transforms'")
		return
	end

	local transforms = {}
	for t in string.gmatch(vim.trim(raw_transforms), "([^,%s]+)") do
		table.insert(transforms, t)
	end

	if #transforms == 0 then
		vim.api.nvim_err_writeln("No transforms found.")
		return
	end

	return transforms
end

---Get information about the currently selected text.
---@param bufnr buffer_id
---@return selection
local function get_selection(bufnr)
	local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")[1] - 1
	local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")[1]
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos, end_pos, false)
	local text = table.concat(lines, "\n")

	if text == "" then
		error("No text selected!")
	end

	return { start_pos = start_pos, end_pos = end_pos, text = text }
end

---Apply a transformer to a selection.
---@param transform string
---@param selection selection
---@return nil
local function apply_transformer(transform, selection)
	local transform_cmd = string.format("%s %s '%s'", extra_bin(), transform, escape(selection.text))
	local result = vim.fn.system(transform_cmd)
	result = vim.fn.trim(result, "\n", 2)

	if vim.v.shell_error ~= 0 then
		error("Error executing transform: " .. result)
	end

	local result_lines = vim.split(result, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(0, selection.start_pos, selection.end_pos, false, result_lines)
end

---Prompt the user for a transform to apply to selected text. This is the public API.
---@param bufnr buffer_id
---@return nil
local function transform(bufnr)
	local selection = get_selection(bufnr)
	local cmd = extra_bin() .. " list_transforms"
	local raw_transforms = vim.fn.system(cmd)
	local transforms = {}

	if selection == nil then
		error("Error running 'extra list_transforms'")
	end

	if vim.v.shell_error ~= 0 then
		error("Error running 'extra list_transforms'")
	end

	for t in string.gmatch(vim.trim(raw_transforms), "([^,%s]+)") do
		table.insert(transforms, t)
	end

	if #transforms == 0 then
		error("No transforms found.")
		return
	end

	vim.ui.select(list_transforms(), { prompt = "Elixir Transform" }, function(choice)
		local cursor = vim.api.nvim_win_get_cursor(0)
		apply_transformer(choice, selection)
		vim.api.nvim_win_set_cursor(0, cursor)
	end)
end

return { transform = transform }
