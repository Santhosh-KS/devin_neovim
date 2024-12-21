local M = {}

-- Process code block from response
function M.process_code_block(block, all_changes)
  -- Parse header: filetype filename[:normal_command]
  local header_parts = vim.split(block.header, '%s+', {trimempty = true})
  local filetype = header_parts[1]
  local buffername = header_parts[2]
  local normal_command = header_parts[3] and header_parts[3]:match(':(.*)') or ''
  
  if not buffername then
    vim.api.nvim_echo({{'Warning: No buffer name specified in code block header', 'WarningMsg'}}, true, {})
    return
  end
  
  local target_bufnr = vim.fn.bufnr(buffername)
  if target_bufnr == -1 then
    vim.api.nvim_echo({{'Warning: Buffer not found for ' .. buffername, 'WarningMsg'}}, true, {})
    return
  end
  
  -- Initialize changes table for this buffer
  all_changes[target_bufnr] = all_changes[target_bufnr] or {}
  
  if filetype == 'vimexec' then
    table.insert(all_changes[target_bufnr], {
      type = 'vimexec',
      commands = block.code
    })
  else
    -- Default to appending at end of file if no normal command specified
    if normal_command == '' then
      normal_command = 'Go<CR>'
    end
    
    table.insert(all_changes[target_bufnr], {
      type = 'content',
      normal_command = normal_command,
      content = table.concat(block.code, '\n')
    })
  end
  
  -- Mark code block as applied
  local indent = require('devin.buffer').get_chat_indent()
  vim.api.nvim_buf_set_lines(
    vim.api.nvim_get_current_buf(),
    block.start_line - 2,
    block.start_line - 1,
    false,
    {indent .. '```' .. block.header .. ' [APPLIED]'}
  )
end

-- Extract code changes from response
function M.extract_changes()
  local all_changes = {}
  
  -- Find start of last Devin block
  vim.cmd('normal! G')
  local start_line = vim.fn.search('^Devin:', 'b')
  local end_line = vim.fn.line('$')
  local markdown_delim = '^' .. require('devin.buffer').get_chat_indent() .. '```'
  
  local in_code_block = false
  local current_block = {header = '', code = {}, start_line = 0}
  
  for line_num = start_line, end_line do
    local line = vim.fn.getline(line_num)
    
    if line:match(markdown_delim) then
      if not in_code_block then
        -- Start of code block
        current_block = {
          header = line:gsub(markdown_delim, ''),
          code = {},
          start_line = line_num + 1
        }
        in_code_block = true
      else
        -- End of code block
        current_block.end_line = line_num
        M.process_code_block(current_block, all_changes)
        in_code_block = false
      end
    elseif in_code_block then
      table.insert(current_block.code, line:gsub('^' .. require('devin.buffer').get_chat_indent(), ''))
    end
  end
  
  -- Process any remaining open code block
  if in_code_block then
    current_block.end_line = end_line
    M.process_code_block(current_block, all_changes)
  end
  
  return all_changes
end

-- Apply code changes to buffer
function M.apply_code_changes(bufnr, changes)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  
  -- Save current window
  local current_winid = vim.api.nvim_get_current_win()
  
  -- Find or create window for buffer
  local target_winid = vim.fn.bufwinid(bufnr)
  if target_winid == -1 then
    -- Buffer not visible, split and show it
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, bufnr)
    target_winid = vim.api.nvim_get_current_win()
  end
  
  -- Apply changes
  vim.fn.win_gotoid(target_winid)
  for _, change in ipairs(changes) do
    if change.type == 'vimexec' then
      vim.cmd(change.commands)
    else
      -- Save current position
      local save_cursor = vim.fn.getpos('.')
      
      -- Execute normal command to position cursor
      vim.cmd('normal! ' .. change.normal_command)
      
      -- Insert content at cursor position
      local lines = vim.split(change.content, '\n')
      local line = vim.fn.line('.')
      vim.api.nvim_buf_set_lines(bufnr, line - 1, line - 1, false, lines)
      
      -- Restore cursor
      vim.fn.setpos('.', save_cursor)
    end
  end
  
  -- Return to original window
  vim.fn.win_gotoid(current_winid)
end

-- Apply all code changes from response
function M.apply_changes_from_response()
  local all_changes = M.extract_changes()
  if next(all_changes) then
    for bufnr, changes in pairs(all_changes) do
      M.apply_code_changes(bufnr, changes)
    end
  end
  vim.cmd('normal! G')
end

return M
