local M = {
  current_job = nil
}

-- Implementation command handler
function M.implement(start_line, end_line, instruction)
  -- Get selected code
  local bufnr = vim.api.nvim_get_current_buf()
  local selected_code = table.concat(
    vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false),
    "\n"
  )
  
  -- Create chat window if it doesn't exist
  local chat_bufnr = require('devin.ui').get_or_create_chat_window()
  
  -- Prepare implementation prompt
  local prompt = string.format(
    "Selected code:\n<code>\n%s\n</code>\n\nInstruction: %s",
    selected_code,
    instruction
  )
  
  -- Create messages for API
  local messages = {
    {
      role = "user",
      content = instruction
    }
  }
  
  -- Query Devin API
  M.current_job = require('devin.api').query_devin(
    messages,
    prompt,
    function(response)
      -- Handle streaming response
      require('devin.ui').display_response(response)
    end,
    function()
      -- Handle completion
      require('devin.ui').display_response({
        type = "text",
        content = "\nImplementation complete\n"
      })
      M.current_job = nil
    end
  )
end

-- Chat command handler
function M.chat(prompt)
  -- Create chat window if it doesn't exist
  local chat_bufnr = require('devin.ui').get_or_create_chat_window()
  
  -- Prepare messages
  local messages = {
    {
      role = "user",
      content = prompt or ""
    }
  }
  
  -- Query Devin API
  M.current_job = require('devin.api').query_devin(
    messages,
    "",  -- No additional context needed for chat
    function(response)
      -- Handle streaming response
      require('devin.ui').display_response(response)
    end,
    function()
      -- Handle completion
      require('devin.ui').display_response({
        type = "text",
        content = "\nChat complete\n"
      })
      M.current_job = nil
    end
  )
end

-- Cancel current operation
function M.cancel()
  if M.current_job then
    M.current_job:kill()
    M.current_job = nil
    vim.api.nvim_echo({{"Operation cancelled", "WarningMsg"}}, true, {})
  end
end

-- Execute tool command
function M.execute_tool(tool_name, arguments)
  return require('devin.tools').execute_tool(tool_name, arguments)
end

return M
