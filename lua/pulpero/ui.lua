local UI = {}

function UI.new(config)
    local self = setmetatable({}, { __index = UI })
    self.config = config
    self.chat_win = nil
    self.chat_buf = nil
    return self
end

function UI.create_chat_sidebar(self)
    local width = math.floor(vim.o.columns * 0.3)
    local height = vim.o.lines - 4  -- Leave some space for status line
    local row = 0
    local col = vim.o.columns - width

    if not self.chat_buf or not vim.api.nvim_buf_is_valid(self.chat_buf) then
        self.chat_buf = vim.api.nvim_create_buf(false, true)
    end

    vim.api.nvim_buf_set_option(self.chat_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self.chat_buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(self.chat_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(self.chat_buf, 'modifiable', false)

    local opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = { "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" },
        title = ' Pulpero ',
        title_pos = 'center',
        focusable = true,
        footer = ':q or <Escape> to close the chat when is focus',
        footer_pos = 'center'
    }

    if not self.chat_win or not vim.api.nvim_win_is_valid(self.chat_win) then
        self.chat_win = vim.api.nvim_open_win(self.chat_buf, false, opts)

        vim.api.nvim_win_set_option(self.chat_win, 'wrap', true)
        vim.api.nvim_win_set_option(self.chat_win, 'cursorline', true)
        vim.api.nvim_win_set_option(self.chat_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
    else
        vim.api.nvim_win_set_config(self.chat_win, opts)
    end

    -- Set up keymaps for the chat window
    local keymap_opts = { noremap = true, silent = true }
    vim.api.nvim_buf_set_keymap(self.chat_buf, 'n', 'q',
        '<cmd>lua vim.api.nvim_win_close(' .. self.chat_win .. ', true)<CR>',
        keymap_opts)
    vim.api.nvim_buf_set_keymap(self.chat_buf, 'n', '<Esc>',
        '<cmd>lua vim.api.nvim_win_close(' .. self.chat_win .. ', true)<CR>',
        keymap_opts)

    return self.chat_win, self.chat_buf
end

function UI.update_chat_content(self, messages)
    if not self.chat_buf or not vim.api.nvim_buf_is_valid(self.chat_buf) then
        return
    end

    vim.api.nvim_buf_set_option(self.chat_buf, 'modifiable', true)

    messages = vim.split(messages, '\n')
    local is_second_line  = false
    local formatted_messages = {}
    for _, msg in ipairs(messages) do
        if is_second_line then
            table.insert(formatted_messages, "")
        end
        is_second_line = true
        if msg ~= " " and msg ~= "" then
            table.insert(formatted_messages, "► " .. msg)
        end
    end
    table.insert(formatted_messages, " ")
    table.insert(formatted_messages, "!!! " .. "Note: This explanation is AI-generated and should be verified for accuracy." .. "!!!")

    vim.api.nvim_buf_set_lines(self.chat_buf, 0, -1, false, formatted_messages)

    vim.api.nvim_buf_set_option(self.chat_buf, 'modifiable', false)
end

return UI
