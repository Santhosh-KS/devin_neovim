local M = {}

-- Tool definitions
M.tools = {
  {
    name = 'python',
    description = 'Execute a Python one-liner code snippet and return the standard output.',
    input_schema = {
      type = 'object',
      properties = {
        code = {
          type = 'string',
          description = 'The Python one-liner code to execute. Wrap the final expression in print to see its result.'
        }
      },
      required = {'code'}
    }
  },
  {
    name = 'shell',
    description = 'Execute a shell command and return both stdout and stderr.',
    input_schema = {
      type = 'object',
      properties = {
        command = {
          type = 'string',
          description = 'The shell command or a short one-line script to execute.'
        }
      },
      required = {'command'}
    }
  },
  {
    name = 'open',
    description = 'Open an existing buffer (file or directory) to access its content.',
    input_schema = {
      type = 'object',
      properties = {
        path = {
          type = 'string',
          description = 'The path to open'
        }
      },
      required = {'path'}
    }
  },
  {
    name = 'new',
    description = 'Create a new file, opening a buffer for it so that edits can be applied.',
    input_schema = {
      type = 'object',
      properties = {
        path = {
          type = 'string',
          description = 'The path of the new file to create'
        }
      },
      required = {'path'}
    }
  },
  {
    name = 'browse',
    description = 'Open a webpage in the browser and return its content.',
    input_schema = {
      type = 'object',
      properties = {
        url = {
          type = 'string',
          description = 'The URL of the webpage to read'
        }
      },
      required = {'url'}
    }
  }
}

-- Execute a tool by name with given arguments
function M.execute_tool(tool_name, arguments)
  if tool_name == 'python' then
    return M.execute_python(arguments.code)
  elseif tool_name == 'shell' then
    return M.execute_shell(arguments.command)
  elseif tool_name == 'open' then
    return M.execute_open(arguments.path)
  elseif tool_name == 'new' then
    return M.execute_new(arguments.path)
  elseif tool_name == 'browse' then
    return M.execute_browse(arguments.url)
  else
    return 'Error: Unknown tool ' .. tool_name
  end
end

-- Execute Python code
function M.execute_python(code)
  -- Ask for confirmation
  local confirm = vim.fn.input('Execute this Python code? (y/n) ')
  if confirm:match('^y') then
    local handle = io.popen('python3 -c ' .. vim.fn.shellescape(code))
    if handle then
      local result = handle:read('*a')
      handle:close()
      return result
    else
      return 'Error: Failed to execute Python code'
    end
  else
    return 'Python code execution cancelled by user.'
  end
end

-- Execute shell command
function M.execute_shell(command)
  -- Ask for confirmation
  local confirm = vim.fn.input('Execute this shell command? (y/n) ')
  if confirm:match('^y') then
    local handle = io.popen(command)
    if handle then
      local result = handle:read('*a')
      local success = handle:close()
      return result .. '\nExit status: ' .. (success and '0' or '1')
    else
      return 'Error: Failed to execute shell command'
    end
  else
    return 'Shell command execution cancelled by user.'
  end
end

-- Open existing file/buffer
function M.execute_open(path)
  local current_win = vim.api.nvim_get_current_win()
  
  -- Create new window at top
  vim.cmd('topleft 1new')
  
  local ok, err = pcall(vim.cmd, 'edit ' .. vim.fn.fnameescape(path))
  if not ok then
    vim.cmd('close')
    vim.api.nvim_set_current_win(current_win)
    return 'ERROR: ' .. err
  end
  
  local bufname = vim.fn.bufname('%')
  
  -- Check if buffer is empty
  if vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_get_current_line() == '' then
    vim.cmd('close')
    vim.api.nvim_set_current_win(current_win)
    return 'ERROR: The opened buffer was empty (non-existent?)'
  end
  
  vim.api.nvim_set_current_win(current_win)
  return bufname
end

-- Create new file
function M.execute_new(path)
  if vim.fn.filereadable(path) == 1 then
    return 'ERROR: File already exists: ' .. path
  end
  
  local current_win = vim.api.nvim_get_current_win()
  
  -- Create new window at top
  vim.cmd('topleft 1new')
  vim.cmd('silent write ' .. vim.fn.fnameescape(path))
  local bufname = vim.fn.bufname('%')
  
  vim.api.nvim_set_current_win(current_win)
  return bufname
end

-- Browse webpage using Devin's browser commands
function M.execute_browse(url)
  local current_win = vim.api.nvim_get_current_win()
  
  -- Create new window at top
  vim.cmd('topleft 1new')
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  
  -- Use Devin's browser commands
  local ok, result = pcall(function()
    -- Navigate to URL
    vim.cmd('lua require("devin").navigate_browser("' .. url .. '")')
    return 'Opened URL in browser: ' .. url
  end)
  
  if not ok then
    vim.cmd('close')
    vim.api.nvim_set_current_win(current_win)
    return 'ERROR: Failed to open URL: ' .. result
  end
  
  -- Set buffer name to URL
  vim.api.nvim_buf_set_name(bufnr, url)
  vim.api.nvim_set_current_win(current_win)
  return result
end

return M
