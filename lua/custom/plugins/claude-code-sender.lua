-- Claude Code Sender Plugin
-- Auto-loaded by lazy.nvim

local M = {}

-- Configuration
M.config = {
  -- Target pane: 'auto', '{down-of}', '.1', '.2', etc.
  target_pane = 'auto',
  -- Whether to switch focus after sending
  switch_focus = true,
}

-- Find pane running Claude Code
local function find_claude_pane()
  -- Get all panes with their commands
  local result = vim.fn.system "tmux list-panes -F '#{pane_index}:#{pane_current_command}'"

  for line in result:gmatch '[^\r\n]+' do
    local pane_index, command = line:match '^(%d+):(.+)$'
    if command and (command:lower():match 'claude' or command:lower():match 'node') then
      return '.' .. pane_index
    end
  end

  -- Fallback to pane below
  return '{down-of}'
end

-- Get the target pane
local function get_target_pane()
  if M.config.target_pane == 'auto' then
    return find_claude_pane()
  else
    return M.config.target_pane
  end
end

-- Switch focus to target pane
local function switch_to_pane(target_pane)
  if M.config.switch_focus then
    vim.fn.system(string.format("tmux select-pane -t '%s'", target_pane))
  end
end

-- Get the relative or absolute path of current file
local function get_file_path()
  local file_path = vim.fn.expand '%:p'
  -- Try to get relative path from git root or current directory
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if git_root and git_root ~= '' then
    file_path = vim.fn.fnamemodify(file_path, ':~:.')
  else
    file_path = vim.fn.expand '%:.'
  end
  return file_path
end

-- Get line range in visual mode
local function get_visual_range()
  local start_line = vim.fn.line "'<"
  local end_line = vim.fn.line "'>"
  return start_line, end_line
end

-- Format the path with @ notation
local function format_path(include_lines)
  local path = get_file_path()

  if include_lines then
    local start_line, end_line = get_visual_range()
    return string.format('@%s:%d-%d', path, start_line, end_line)
  else
    return string.format('@%s', path)
  end
end

-- Copy to system clipboard
function M.copy_to_clipboard(include_lines)
  local formatted = format_path(include_lines)
  vim.fn.setreg('+', formatted)
  vim.notify('Copied: ' .. formatted, vim.log.levels.INFO)
end

-- Send to tmux pane
function M.send_to_tmux(include_lines)
  local formatted = format_path(include_lines)
  local target_pane = get_target_pane()

  local cmd = string.format("tmux send-keys -t '%s' '%s' ", target_pane, formatted)
  vim.fn.system(cmd)

  switch_to_pane(target_pane)
  vim.notify('Sent to Claude Code: ' .. formatted, vim.log.levels.INFO)
end

-- Send to tmux and press Enter
function M.send_to_tmux_and_enter(include_lines)
  local formatted = format_path(include_lines)
  local target_pane = get_target_pane()

  local cmd = string.format("tmux send-keys -t '%s' '%s' Enter", target_pane, formatted)
  vim.fn.system(cmd)

  switch_to_pane(target_pane)
  vim.notify('Sent to Claude Code: ' .. formatted, vim.log.levels.INFO)
end

-- Send with custom prompt
function M.send_with_prompt(include_lines)
  local file_path = format_path(include_lines)

  -- Open input prompt
  vim.ui.input({
    prompt = 'Enter prompt for Claude Code: ',
    default = '',
  }, function(prompt_text)
    if prompt_text and prompt_text ~= '' then
      -- Combine prompt with file path
      local message = string.format('%s %s', prompt_text, file_path)
      local target_pane = get_target_pane()

      -- Send to tmux and press Enter
      local cmd = string.format("tmux send-keys -t '%s' '%s' Enter", target_pane, message)
      vim.fn.system(cmd)

      switch_to_pane(target_pane)
      vim.notify('Sent to Claude Code: ' .. message, vim.log.levels.INFO)
    else
      vim.notify('Cancelled', vim.log.levels.WARN)
    end
  end)
end

-- List available panes
function M.list_panes()
  local result = vim.fn.system "tmux list-panes -F '#{pane_index}: #{pane_current_command} (#{pane_current_path})'"
  print 'Available tmux panes:'
  print(result)
end

-- Set target pane
function M.set_target_pane(pane)
  M.config.target_pane = pane
  vim.notify('Target pane set to: ' .. pane, vim.log.levels.INFO)
end

-- Toggle focus switching
function M.toggle_focus()
  M.config.switch_focus = not M.config.switch_focus
  vim.notify('Focus switching: ' .. (M.config.switch_focus and 'enabled' or 'disabled'), vim.log.levels.INFO)
end

-- Setup keybindings
function M.setup()
  -- Normal mode: Send current file
  vim.keymap.set('n', '<leader>ac', function()
    M.copy_to_clipboard(false)
  end, { desc = '[A]I: [C]opy file path to clipboard' })

  vim.keymap.set('n', '<leader>as', function()
    M.send_to_tmux(false)
  end, { desc = '[A]I: [S]end file path to Claude Code' })

  vim.keymap.set('n', '<leader>aa', function()
    M.send_to_tmux_and_enter(false)
  end, { desc = '[A]I: Send file path and submit' })

  vim.keymap.set('n', '<leader>ae', function()
    M.send_with_prompt(false)
  end, { desc = '[A]I: Send with prompt [E]dit' })

  -- Visual mode: Send with line range
  vim.keymap.set('v', '<leader>ac', function()
    M.copy_to_clipboard(true)
  end, { desc = '[A]I: [C]opy file path with lines' })

  vim.keymap.set('v', '<leader>as', function()
    M.send_to_tmux(true)
  end, { desc = '[A]I: [S]end file path with lines' })

  vim.keymap.set('v', '<leader>aa', function()
    M.send_to_tmux_and_enter(true)
  end, { desc = '[A]I: Send file path with lines and submit' })

  vim.keymap.set('v', '<leader>ae', function()
    M.send_with_prompt(true)
  end, { desc = '[A]I: Send with prompt [E]dit' })

  -- Keybinding to return focus to neovim pane
  vim.keymap.set('n', '<leader>av', function()
    vim.fn.system "tmux select-pane -t '{up-of}'"
    vim.notify('Switched to neovim pane', vim.log.levels.INFO)
  end, { desc = '[A]I: Return to [V]im pane' })

  -- Commands for configuration
  vim.api.nvim_create_user_command('ClaudeListPanes', function()
    M.list_panes()
  end, { desc = 'List available tmux panes' })

  vim.api.nvim_create_user_command('ClaudeSetPane', function(opts)
    M.set_target_pane(opts.args)
  end, { nargs = 1, desc = 'Set target pane (e.g., .1, .2, {down-of})' })

  vim.api.nvim_create_user_command('ClaudeToggleFocus', function()
    M.toggle_focus()
  end, { desc = 'Toggle automatic focus switching' })
end

-- Return a lazy.nvim plugin spec
return {
  name = 'claude-code-sender',
  dir = vim.fn.stdpath 'config' .. '/lua/custom/plugins',
  lazy = false,
  config = function()
    M.setup()
  end,
}
