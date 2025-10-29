local M = {}

-- Configuration - Set your Claude Code pane here!
M.config = {
  target_pane = '.3', -- Change this to your Claude Code pane (.2, .3, etc.)
  switch_focus = true, -- Auto-switch to Claude Code after sending
}

-- Get the relative or absolute path of current file
local function get_file_path()
  local file_path = vim.fn.expand '%:p'
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

-- Switch focus to target pane
local function switch_to_pane()
  if M.config.switch_focus then
    vim.fn.system(string.format("tmux select-pane -t '%s'", M.config.target_pane))
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
  local cmd = string.format("tmux send-keys -t '%s' '%s' ", M.config.target_pane, formatted)
  vim.fn.system(cmd)
  switch_to_pane()
  vim.notify('Sent to Claude Code: ' .. formatted, vim.log.levels.INFO)
end

-- Send to tmux and press Enter
function M.send_to_tmux_and_enter(include_lines)
  local formatted = format_path(include_lines)
  local cmd = string.format("tmux send-keys -t '%s' '%s' Enter", M.config.target_pane, formatted)
  vim.fn.system(cmd)
  switch_to_pane()
  vim.notify('Sent to Claude Code: ' .. formatted, vim.log.levels.INFO)
end

-- Send with custom prompt
function M.send_with_prompt(include_lines)
  local file_path = format_path(include_lines)
  vim.ui.input({
    prompt = 'Enter prompt for Claude Code: ',
    default = '',
  }, function(prompt_text)
    if prompt_text and prompt_text ~= '' then
      local message = string.format('%s %s', prompt_text, file_path)
      local cmd = string.format("tmux send-keys -t '%s' '%s' Enter", M.config.target_pane, message)
      vim.fn.system(cmd)
      switch_to_pane()
      vim.notify('Sent to Claude Code: ' .. message, vim.log.levels.INFO)
    else
      vim.notify('Cancelled', vim.log.levels.WARN)
    end
  end)
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

-- Show current config
function M.show_config()
  print '════════════════════════════════════════'
  print('Target pane: ' .. M.config.target_pane)
  print('Auto-switch focus: ' .. (M.config.switch_focus and 'enabled' or 'disabled'))
  print '════════════════════════════════════════'
end

-- Setup keybindings
function M.setup()
  -- Normal mode
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

  -- Visual mode
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

  -- Return to vim pane
  vim.keymap.set('n', '<leader>av', function()
    vim.fn.system "tmux select-pane -t '{up-of}'"
    vim.notify('Switched to neovim pane', vim.log.levels.INFO)
  end, { desc = '[A]I: Return to [V]im pane' })

  -- Commands
  vim.api.nvim_create_user_command('ClaudeSetPane', function(opts)
    M.set_target_pane(opts.args)
  end, { nargs = 1, desc = 'Set target pane (e.g., .2, .3, {down-of})' })

  vim.api.nvim_create_user_command('ClaudeToggleFocus', function()
    M.toggle_focus()
  end, { desc = 'Toggle automatic focus switching' })

  vim.api.nvim_create_user_command('ClaudeConfig', function()
    M.show_config()
  end, { desc = 'Show current Claude Code configuration' })
end

-- Return lazy.nvim plugin spec
return {
  name = 'claude-code-sender',
  dir = vim.fn.stdpath 'config' .. '/lua/custom/plugins',
  lazy = false,
  config = function()
    M.setup()
  end,
}
