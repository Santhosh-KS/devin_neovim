local M = {}

-- Plugin configuration
M.config = {
  api_url = nil,
  api_key = nil,
}

-- Load configuration from vim globals
local function load_config()
  M.config.api_url = vim.g.devin_api_url
  M.config.api_key = vim.g.devin_api_key
  
  -- Validate configuration
  if not M.config.api_url or M.config.api_url == '' then
    error('Devin: API URL not configured. Set g:devin_api_url in your config.')
  end
  
  if not M.config.api_key or M.config.api_key == '' then
    error('Devin: API key not configured. Set g:devin_api_key in your config.')
  end
end

-- Setup function to be called by user
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  load_config()
end

-- Initialize plugin
function M.init()
  load_config()
  
  -- Load and initialize required modules
  local api = require('devin.api')
  local ui = require('devin.ui')
  local buffer = require('devin.buffer')
  local code = require('devin.code')
  local tools = require('devin.tools')
  
  -- Initialize modules with configuration
  local modules = {
    ['api'] = api,
    ['ui'] = ui,
    ['buffer'] = buffer,
    ['auth'] = require('devin.auth')
  }
  
  -- Set up each module with config
  for name, mod in pairs(modules) do
    if mod and mod.setup then
      mod.setup({
        url = M.config.api_url,
        key = M.config.api_key,
        debug = vim.g.devin_debug
      })
    else
      error('Failed to load ' .. name .. ' module or setup function not found')
    end
  end
end

-- Get plugin configuration
function M.get_config()
  return M.config
end

return M
