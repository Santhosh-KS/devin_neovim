local M = {}

-- Module configuration
M.config = {
  chat_window_height = 15,
  indent_size = 2
}

-- Setup function
function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  
  -- Create highlight groups
  vim.cmd([[
    highlight default DevinPrompt ctermfg=Green guifg=Green
    highlight default DevinError ctermfg=Red guifg=Red
    highlight default DevinToolUse ctermfg=Blue guifg=Blue
  ]])
end

-- Debug logging function
local function log_debug(msg)
  vim.api.nvim_echo({{string.format("[Devin Debug] %s", msg), "None"}}, true, {})
end

-- Create or get chat window
function M.get_or_create_chat_window()
  log_debug("Attempting to get or create chat window")
  
  -- Check for existing chat buffer
  local chat_bufnr = vim.fn.bufnr('Devin Chat')
  log_debug("Existing chat buffer number: " .. chat_bufnr)
  
  if chat_bufnr == -1 or not vim.api.nvim_buf_is_valid(chat_bufnr) then
    log_debug("Creating new chat buffer")
    
    -- Create new buffer
    local ok, buf = pcall(vim.api.nvim_create_buf, false, true)
    if not ok then
      log_debug("Failed to create buffer: " .. tostring(buf))
      error("Failed to create chat buffer: " .. tostring(buf))
    end
    chat_bufnr = buf
    
    -- Set buffer name
    ok, _ = pcall(vim.api.nvim_buf_set_name, chat_bufnr, 'Devin Chat')
    if not ok then
      log_debug("Failed to set buffer name")
      -- Continue anyway, not critical
    end
    
    -- Set buffer options
    local options = {
      buftype = 'nofile',
      bufhidden = 'hide',
      swapfile = false,
      filetype = 'devin'
    }
    
    for opt, val in pairs(options) do
      ok, _ = pcall(vim.api.nvim_buf_set_option, chat_bufnr, opt, val)
      if not ok then
        log_debug("Failed to set buffer option " .. opt)
      end
    end
    
    -- Create window
    local win
    ok, _ = pcall(function()
      vim.cmd('botright split')
      win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, chat_bufnr)
      vim.api.nvim_win_set_height(win, M.config.chat_window_height)
    end)
    
    if not ok then
      log_debug("Failed to create/setup window")
      error("Failed to create chat window")
    end
    
    -- Initialize chat buffer
    ok, _ = pcall(vim.api.nvim_buf_set_lines, chat_bufnr, 0, -1, false, {
      'Welcome to Devin Chat!',
      'Type your messages and press <C-]> to send.',
      '',
      'You: '
    })
    
    if not ok then
      log_debug("Failed to initialize chat buffer content")
    end
    
    -- Setup buffer
    require('devin.buffer').setup_chat_buffer(chat_bufnr)
  end
  
  log_debug("Returning chat buffer number: " .. chat_bufnr)
  return chat_bufnr
end

-- Display response in chat window
function M.display_response(response)
  local chat_bufnr = M.get_or_create_chat_window()
  
  if not vim.api.nvim_buf_is_valid(chat_bufnr) then
    return
  end
  
  -- Handle different response types
  if response.type == "text" then
    M.streaming_chat_response(response.content)
  elseif response.type == "tool_start" then
    M.append_to_chat(chat_bufnr, "\nTool: " .. response.tool.name .. "\n")
  elseif response.type == "tool_input" then
    M.append_to_chat(chat_bufnr, "Input: " .. response.delta .. "\n")
  elseif response.type == "tool_end" then
    M.append_to_chat(chat_bufnr, "Tool execution complete\n")
  elseif response.type == "error" then
    M.append_to_chat(chat_bufnr, "\nError: " .. response.message .. "\n")
  end
end

-- Handle streaming chat response
function M.streaming_chat_response(delta)
  local chat_bufnr = M.get_or_create_chat_window()
  local chat_winid = vim.fn.bufwinid(chat_bufnr)
  local current_winid = vim.api.nvim_get_current_win()
  
  vim.fn.win_gotoid(chat_winid)
  
  local indent = require('devin.buffer').get_chat_indent()
  local new_lines = vim.split(delta, "\n", true)
  
  if #new_lines > 0 then
    -- Update last line with first segment of delta
    local last_line = vim.fn.getline('$')
    vim.fn.setline('$', last_line .. new_lines[1])
    
    -- Append remaining lines with proper indentation
    if #new_lines > 1 then
      local indented_lines = vim.tbl_map(function(line)
        return indent .. line
      end, vim.list_slice(new_lines, 2))
      vim.api.nvim_buf_set_lines(chat_bufnr, -1, -1, false, indented_lines)
    end
  end
  
  vim.cmd('normal! G')
  vim.fn.win_gotoid(current_winid)
end

-- Handle final chat response
function M.final_chat_response()
  local chat_bufnr = M.get_or_create_chat_window()
  local buffer = require('devin.buffer')
  
  -- Apply code changes and prepare for next input
  require('devin.code').apply_changes_from_response()
  buffer.close_previous_fold()
  buffer.close_current_interaction_blocks()
  buffer.prepare_next_input()
end

-- Append text to chat buffer with proper formatting
function M.append_to_chat(bufnr, text)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local lines = vim.split(text, "\n")
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
    
    -- Scroll to bottom
    local winid = vim.fn.bufwinid(bufnr)
    if winid ~= -1 then
      vim.api.nvim_win_set_cursor(winid, {line_count + #lines, 0})
    end
  end
end

return M
