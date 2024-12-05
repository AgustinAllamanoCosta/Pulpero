local UI = {}

function UI.new(config)
    local self = setmetatable({}, { __index = UI })
    self.config = config
    return self
end

function UI.restart_loading_window(self)
    local width = math.min(120, vim.o.columns - 4)
    local height = 10
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    self.min_height = height
    self.frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    self.current_frame = 1
    self.timer = nil
    self.opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        anchor = 'NW',
        title = '',
        title_pos = 'center',
        border = { "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" },
        focusable = true,
        footer = 'Note: This explanation is AI-generated and should be verified for accuracy.',
        footer_pos = 'center'
    }
end

function UI.create_new_window(self, title, content)
    while #content > 0 and content[#content] == "" do
        table.remove(content)
    end
    local buffer = vim.api.nvim_create_buf(false, true)
    self.opts.title = title

    vim.api.nvim_buf_set_lines(buffer, 0, -1, true, content)

    local win_id = vim.api.nvim_open_win(buffer, false, self.opts)

    vim.api.nvim_buf_set_keymap(buffer, 'n', 'q', ':q<CR>', {
        noremap = true,
        silent = true
    })
    vim.api.nvim_buf_set_keymap(buffer, 'n', '<Esc>','<cmd>lua vim.api.nvim_win_close(' .. win_id .. ', true)<CR>', {silent = true, noremap = true})
end

function UI.show_explanation(self, text)
    self:restart_loading_window()
    local lines = vim.split(text, '\n')
    self:create_new_window(' Code Analysis ',lines)
end

function UI.show_error(self, message)
    self:restart_loading_window()
    local lines = vim.split(message, '\n')
    self:create_new_window(' Error message ',lines)
end

function UI.start_spiner(self)
    self:restart_loading_window()

    local buf = vim.api.nvim_create_buf(false, true)

    if self.main_win and vim.api.nvim_win_is_valid(self.main_win) then
        vim.api.nvim_win_close(self.main_win, true)
    end

    if self.footer_win and vim.api.nvim_win_is_valid(self.footer_win) then
        vim.api.nvim_win_close(self.footer_win, true)
    end

    local width = 30
    local height = 1
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    self.opts.row = row
    self.opts.height = height
    self.opts.col = col
    self.opts.width = width
    self.opts.title = ' Loading '

    local win = vim.api.nvim_open_win(buf, false, self.opts)

    self.timer = vim.loop.new_timer()
    local current_frame = 1
    local frames = self.frames

    self.loading_win = win
    self.loading_buf = buf
    self.timer:start(0, 100, vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_set_lines(buf, 0, -1, false,"Analyzing code...")
        else
            self:stop_spiner()
        end
    end))
end

function UI.stop_spiner(self)
    if self.timer then
        self.timer:stop()
        self.timer:close()
        self.timer = nil
    end

    if self.loading_win and vim.api.nvim_win_is_valid(self.loading_win) then
        vim.api.nvim_win_close(self.loading_win, true)
        self.loading_win = nil
    end

    if self.loading_buf and vim.api.nvim_buf_is_valid(self.loading_buf) then
        vim.api.nvim_buf_delete(self.loading_buf, { force = true })
        self.loading_buf = nil
    end
end

return UI
