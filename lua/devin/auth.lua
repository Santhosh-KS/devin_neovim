local M = {
  config = {
    api_key = nil
  }
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  if not M.config.key then
    error("Devin API key not configured. Please set in setup()")
  end
end

function M.get_headers()
  if not M.config.key then
    error("Auth module not initialized. Please call setup() first")
  end
  
  return {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. M.config.key
  }
end

return M
