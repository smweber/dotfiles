-- Scott's Preferences

-- Keybindings for toggling line numbers
vim.keymap.set('n', '<Leader>nn', ':set invnumber<CR>', { noremap = true })
vim.keymap.set('n', '<Leader>nr', ':set invrelativenumber<CR>', { noremap = true })

-- Display and formatting
vim.opt.wrap = false
vim.opt.tabstop = 4           -- Display TAB characters as 4 spaces wide
vim.opt.expandtab = true      -- Replaces actual tab with spaces (Ctrl-V tab for real tabs)
vim.opt.shiftwidth = 4        -- Determines indent for >> and <<
vim.opt.softtabstop = 4       -- Determines indent for <TAB>
vim.opt.number = true
vim.opt.mouse = 'a'           -- Mouse support in terminal

-- Search behavior
vim.opt.hlsearch = true       -- Highlight search
vim.opt.incsearch = true      -- Incremental search
vim.opt.ignorecase = true     -- Case insensitive search
vim.opt.smartcase = true      -- Case sensitive when uppercase present

-- File behavior
vim.opt.autoread = true       -- Auto reload files that have changed outside vim
vim.opt.scrolloff = 2         -- Start scrolling before cursor reaches last line

-- Swap and backup files
vim.opt.swapfile = true
vim.opt.directory = vim.fn.expand('~/.tmp')
vim.opt.backupdir = vim.fn.expand('~/.tmp')

-- Split behavior
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Clipboard
vim.opt.clipboard:append('unnamedplus')  -- Yank and copy with system clipboard

-- Filetype-specific settings
local function set_indent(pattern, width)
  vim.api.nvim_create_autocmd('FileType', {
    pattern = pattern,
    callback = function()
      vim.opt_local.shiftwidth = width
      vim.opt_local.softtabstop = width
    end,
  })
end

set_indent({'html', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact'}, 2)

-- Tab and window movement keybindings
-- Note: <c-h/j/k/l> are handled by vim-tmux-navigator plugin

-- Config reload commands
vim.api.nvim_create_user_command('ReloadConfig', function()
  vim.cmd('source $MYVIMRC')
end, {})

vim.api.nvim_create_user_command('OpenConfig', function()
  vim.cmd('edit $MYVIMRC')
end, {})

-- Writing and Wrapping Functions
local function wrap_it()
  vim.opt.wrap = true
  vim.opt.linebreak = true
  vim.opt.list = false
  vim.keymap.set('n', 'j', 'gj', { noremap = true, buffer = true })
  vim.keymap.set('n', 'k', 'gk', { noremap = true, buffer = true })
  vim.keymap.set('n', '$', 'g$', { noremap = true, buffer = true })
  vim.keymap.set('n', '^', 'g^', { noremap = true, buffer = true })
end

local function unwrap_it()
  vim.opt.wrap = false
  vim.opt.linebreak = false
  vim.keymap.del('n', 'j', { buffer = true })
  vim.keymap.del('n', 'k', { buffer = true })
  vim.keymap.del('n', '$', { buffer = true })
  vim.keymap.del('n', '^', { buffer = true })
end

vim.api.nvim_create_user_command('WrapIt', wrap_it, {})
vim.api.nvim_create_user_command('UnWrapIt', unwrap_it, {})

-- Goyo integration for writing mode
vim.api.nvim_create_autocmd('User', {
  pattern = 'GoyoEnter',
  callback = function()
    wrap_it()
    vim.b.quitting = false
    vim.b.quitting_bang = false

    vim.api.nvim_create_autocmd('QuitPre', {
      buffer = 0,
      callback = function()
        vim.b.quitting = true
      end,
    })

    vim.cmd([[cabbrev <buffer> q! let b:quitting_bang = 1 <bar> q!]])
  end,
})

vim.api.nvim_create_autocmd('User', {
  pattern = 'GoyoLeave',
  callback = function()
    unwrap_it()

    -- Quit Vim if this is the only remaining buffer
    if vim.b.quitting then
      local buffers = vim.fn.range(1, vim.fn.bufnr('$'))
      local listed = vim.tbl_filter(function(b)
        return vim.fn.buflisted(b) == 1
      end, buffers)

      if #listed == 1 then
        if vim.b.quitting_bang then
          vim.cmd('qa!')
        else
          vim.cmd('qa')
        end
      end
    end
  end,
})

-- Trailing Whitespace Stripping
local function strip_trailing_whitespace()
  local save_search = vim.fn.getreg('/')
  local save_line = vim.fn.line('.')
  local save_col = vim.fn.col('.')

  vim.cmd([[%s/\s\+$//e]])

  vim.fn.setreg('/', save_search)
  vim.fn.cursor(save_line, save_col)
end

vim.keymap.set('n', '<Leader>w', strip_trailing_whitespace, { silent = true })

-- Clear Command Line after delay
vim.api.nvim_create_augroup('clearcmdline', { clear = true })
vim.api.nvim_create_autocmd('CmdlineLeave', {
  group = 'clearcmdline',
  callback = function()
    vim.defer_fn(function()
      vim.cmd('echo ""')
    end, 5000)
  end,
})

-- LSP Configuration
vim.api.nvim_set_hl(0, 'LspInlayHint', { link = 'Comment' })

vim.api.nvim_create_user_command('Format', function()
  vim.lsp.buf.format({ async = false })
end, {})

vim.api.nvim_create_user_command('OR', function()
  vim.lsp.buf.code_action({ context = { only = { 'source.organizeImports' } }, apply = true })
end, {})
