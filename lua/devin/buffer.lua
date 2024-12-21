local M = {}

-- Module configuration
M.config = {
  fold_level = 2,
  indent_size = 2
}

-- Setup function
function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  
  -- Register autocmd to set up new chat buffers
  vim.cmd([[
    augroup DevinBuffer
      autocmd!
      autocmd FileType devin lua require('devin.buffer').setup_chat_buffer(vim.fn.bufnr('%'))
    augroup END
  ]])
end

-- Get current buffer content
function M.get_current_buffer()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Get visual selection
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  if #lines == 0 then
    return ''
  end
  
  -- Handle single line selection
  if #lines == 1 then
    return string.sub(lines[1], start_pos[3], end_pos[3])
  end
  
  -- Handle multi-line selection
  lines[1] = string.sub(lines[1], start_pos[3])
  lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  
  return table.concat(lines, '\n')
end

-- Get chat indent level
function M.get_chat_indent()
  return string.rep(' ', 2)
end

-- Close previous fold in chat buffer
function M.close_previous_fold()
  local save_cursor = vim.fn.getpos('.')
  
  vim.cmd('normal! G[zk[zzc')
  
  if vim.fn.foldclosed('.') == -1 then
    vim.api.nvim_echo({{'Warning: Failed to close previous fold at line ' .. vim.fn.line('.'), 'WarningMsg'}}, true, {})
  end
  
  vim.fn.setpos('.', save_cursor)
end

-- Close code blocks in current interaction
function M.close_current_interaction_blocks()
  local save_cursor = vim.fn.getpos('.')
  
  -- Move to start of current interaction
  vim.cmd('normal! [z')
  
  -- Find and close all level 2 folds until end of interaction
  while true do
    if vim.fn.foldlevel('.') == 2 then
      vim.cmd('normal! zc')
    end
    
    local current_line = vim.fn.line('.')
    vim.cmd('normal! j')
    if vim.fn.line('.') == current_line or 
       vim.fn.foldlevel('.') < 1 or 
       vim.fn.line('.') == vim.fn.line('$') then
      break
    end
  end
  
  vim.fn.setpos('.', save_cursor)
end

-- Prepare next input line in chat buffer
function M.prepare_next_input()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {'', 'You: '})
  vim.cmd('normal! G$')
end

-- Set up buffer-local options for chat buffer
function M.setup_chat_buffer(bufnr)
  -- Set window-local options
  local win = vim.fn.bufwinid(bufnr)
  if win ~= -1 then
    vim.wo[win].foldmethod = 'indent'
    vim.wo[win].foldlevel = M.config.fold_level or 1
  end
  
  -- Set buffer-local options
  local bo = vim.bo[bufnr]
  bo.filetype = 'devin'
  bo.modifiable = true
  bo.buftype = 'nofile'
  bo.swapfile = false
end

return M
