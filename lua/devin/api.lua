local M = {}
local uv = vim.loop
local json = vim.json

-- Module configuration
M.config = {
  url = nil,
  key = nil
}

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  
  if not M.config.url or M.config.url == '' then
    error('Devin API URL not configured')
  end
  
  if not M.config.key or M.config.key == '' then
    error('Devin API key not configured')
  end
end

-- Helper function to create curl command
local function create_curl_command(url, headers, data)
  local cmd = {'curl', '-s', '-N', '-X', 'POST'}
  
  -- Add headers
  for key, value in pairs(headers) do
    table.insert(cmd, '-H')
    table.insert(cmd, string.format('%s: %s', key, value))
  end
  
  -- Add data
  table.insert(cmd, '-d')
  table.insert(cmd, data)
  
  -- Add URL
  table.insert(cmd, url)
  
  return cmd
end

-- Function to make API requests to Devin
function M.query_devin(messages, context, stream_callback, final_callback)
  if not M.config.url or not M.config.key then
    error("Devin API URL and key must be configured. Please call setup()")
  end
  
  -- Prepare request data
  local data = {
    messages = messages,
    context = context,
    stream = true
  }
  
  -- Get headers from auth module
  local headers = require('devin.auth').get_headers()
  
  -- Create curl command
  local cmd = create_curl_command(
    M.config.url,
    headers,
    json.encode(data)
  )
  
  -- Start job
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  
  local handle
  handle = uv.spawn('curl', {
    args = cmd,
    stdio = {nil, stdout, stderr}
  }, function(code, signal)
    -- Cleanup
    stdout:close()
    stderr:close()
    handle:close()
    
    if code ~= 0 then
      vim.schedule(function()
        final_callback('Error: Process exited with code ' .. code)
      end)
    end
  end)
  
  -- Handle stdout data
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        stream_callback('Error: ' .. err)
        final_callback()
      end)
      return
    end
    
    if data then
      vim.schedule(function()
        -- Process each line
        for line in data:gmatch("[^\r\n]+") do
          if vim.startswith(line, 'data: ') then
            -- Extract JSON data
            local json_str = line:gsub('^data:%s*', '')
            local ok, response = pcall(json.decode, json_str)
            
            if ok then
              -- Handle different response types
              if response.type == 'content_block_start' and response.content_block and response.content_block.type == 'tool_use' then
                -- Tool usage start
                stream_callback({
                  type = 'tool_start',
                  tool = {
                    id = response.content_block.id,
                    name = response.content_block.name
                  }
                })
              elseif response.type == 'content_block_delta' and response.delta and response.delta.type == 'input_json_delta' then
                -- Tool input delta
                stream_callback({
                  type = 'tool_input',
                  delta = response.delta.partial_json
                })
              elseif response.type == 'content_block_stop' then
                -- Tool usage end
                stream_callback({
                  type = 'tool_end'
                })
              elseif response.delta and response.delta.text then
                -- Regular text delta
                stream_callback({
                  type = 'text',
                  content = response.delta.text
                })
              elseif response.type == 'message_start' and response.message and response.message.usage then
                -- Message start with usage info
                stream_callback({
                  type = 'usage_start',
                  usage = response.message.usage
                })
              elseif response.type == 'message_delta' and response.usage then
                -- Usage update
                stream_callback({
                  type = 'usage_update',
                  usage = response.usage
                })
              elseif response.type == 'message_stop' then
                -- Message complete
                stream_callback({
                  type = 'complete'
                })
                final_callback()
              elseif response.type == 'ping' then
                -- Ignore ping events
              else
                stream_callback({
                  type = 'error',
                  message = 'Unknown Devin protocol output: ' .. json_str
                })
              end
            else
              stream_callback({
                type = 'error',
                message = 'Error parsing JSON: ' .. json_str
              })
            end
          elseif line == 'event: ping' then
            -- Ignore ping events
          elseif line == 'event: error' then
            stream_callback({
              type = 'error',
              message = 'Server sent an error event'
            })
            final_callback()
          elseif line == 'event: message_stop' then
            final_callback()
          elseif not (line == 'event: message_start' or 
                     line == 'event: message_delta' or 
                     line == 'event: content_block_start' or 
                     line == 'event: content_block_delta' or 
                     line == 'event: content_block_stop') then
            stream_callback({
              type = 'error',
              message = 'Unknown Devin protocol output: ' .. line
            })
          end
        end
      end)
    end
  end)
  
  -- Handle stderr data
  stderr:read_start(function(err, data)
    if data then
      vim.schedule(function()
        stream_callback('Error: ' .. data)
      end)
    end
  end)
  
  -- Return handle for cancellation
  return handle
end

return M
