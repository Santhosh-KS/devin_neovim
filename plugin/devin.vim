if exists('g:loaded_devin') | finish | endif

" Default configuration
if !exists('g:devin_api_url')
  let g:devin_api_url = 'https://app.devin.ai/api/v1'
endif

if !exists('g:devin_api_key')
  echohl ErrorMsg
  echo 'Devin: API key not set. Please set g:devin_api_key'
  echohl None
  finish
endif

if !exists('g:devin_map_implement')
  let g:devin_map_implement = '<leader>di'
endif

if !exists('g:devin_map_chat')
  let g:devin_map_chat = '<leader>dc'
endif

if !exists('g:devin_map_cancel')
  let g:devin_map_cancel = '<leader>dx'
endif

" Initialize plugin
lua << EOF
local devin = require('devin')
devin.setup({
    api_url = vim.g.devin_api_url,
    api_key = vim.g.devin_api_key,
    debug = true
})
devin.init()
EOF

" Initialize default commands
if !exists(':DevinChat')
    command! -nargs=1 DevinChat lua require('devin.commands').chat(<q-args>)
endif

if !exists(':DevinImplement')
    command! -range -nargs=1 DevinImplement lua require('devin.commands').implement(<line1>, <line2>, <q-args>)
endif

if !exists(':DevinCancel')
    command! DevinCancel lua require('devin.commands').cancel()
endif

" Set up default keymaps
execute 'vnoremap ' . g:devin_map_implement . ' :DevinImplement<Space>'
execute 'nnoremap ' . g:devin_map_chat . ' :DevinChat<CR>'
execute 'nnoremap ' . g:devin_map_cancel . ' :DevinCancel<CR>'

let g:loaded_devin = 1
