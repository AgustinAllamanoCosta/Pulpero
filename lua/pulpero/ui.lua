local UI = {}

function UI.new(config)
    local self         = setmetatable({}, { __index = UI })
    local width        = math.floor(vim.o.columns * 0.3)
    local chat_height  = vim.o.lines - 9
    local row          = 0
    local col          = vim.o.columns - width
    local input_height = 3

    self.config        = config
    self.chat_buf      = vim.api.nvim_create_buf(false, true)
    self.input_buf     = vim.api.nvim_create_buf(false, true)
    self.chat_options  = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = chat_height,
        style = 'minimal',
        border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
        title = ' Pulpero ',
        title_pos = 'center',
        focusable = true
    }
    self.input_options = {
        relative = 'editor',
        row = chat_height + 2,
        col = col,
        width = width,
        height = input_height,
        style = 'minimal',
        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
        title = ' Message ',
        title_pos = 'center',
        focusable = true,
        footer = 'Execute :PulperoCloseChat to close',
        footer_pos = 'center'
    }

    self.chat_win      = nil
    self.input_win     = nil

    vim.api.nvim_buf_set_option(self.chat_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.chat_buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(self.chat_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(self.chat_buf, 'modifiable', false)

    vim.api.nvim_buf_set_option(self.input_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.input_buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(self.input_buf, 'swapfile', false)
    return self
end

function UI.create_chat_sidebar(self)
    self.chat_win = vim.api.nvim_open_win(self.chat_buf, false, self.chat_options)
    self.input_win = vim.api.nvim_open_win(self.input_buf, true, self.input_options)

    vim.api.nvim_win_set_option(self.chat_win, 'wrap', true)
    vim.api.nvim_win_set_option(self.chat_win, 'cursorline', true)
    vim.api.nvim_win_set_option(self.chat_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
    vim.api.nvim_win_set_option(self.input_win, 'wrap', true)
    vim.api.nvim_win_set_option(self.input_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
end

function UI.open_chat(self)
    self.chat_win = vim.api.nvim_open_win(self.chat_buf, false, self.chat_options)
    self.input_win = vim.api.nvim_open_win(self.input_buf, true, self.input_options)
end

function UI.close_chat(self)
    vim.api.nvim_win_close(self.chat_win, true)
    vim.api.nvim_win_close(self.input_win, true)
end

return UI
