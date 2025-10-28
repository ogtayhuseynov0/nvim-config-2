-- Claude Code Sender Plugin
-- This file will be auto-loaded by lazy.nvim when { import = 'plugins' } is enabled

local M = {}

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

-- Send to tmux pane below
function M.send_to_tmux(include_lines)
  local formatted = format_path(include_lines)

  -- Send to the pane below (assuming bottom pane is target)
  local cmd = string.format("tmux send-keys -t '{down-of}' '%s' ", formatted)
  vim.fn.system(cmd)

  vim.notify('Sent to Claude Code: ' .. formatted, vim.log.levels.INFO)
end

-- Send to tmux and press Enter
function M.send_to_tmux_and_enter(include_lines)
  local formatted = format_path(include_lines)

  -- Send to the pane below and press Enter
  local cmd = string.format("tmux send-keys -t '{down-of}' '%s' Enter", formatted)
  vim.fn.system(cmd)

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

      -- Send to tmux and press Enter
      local cmd = string.format("tmux send-keys -t '{down-of}' '%s' Enter", message)
      vim.fn.system(cmd)

      vim.notify('Sent to Claude Code: ' .. message, vim.log.levels.INFO)
    else
      vim.notify('Cancelled', vim.log.levels.WARN)
    end
  end)
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
end

-- Return a lazy.nvim plugin spec
return {
  name = 'claude-code-sender',
  dir = vim.fn.stdpath 'config' .. '/lua/custom/plugins', -- Point to the plugins directory
  lazy = false,
  config = function()
    M.setup()
  end,
}
