local UI = {}

function UI.new(config)
    local self = setmetatable({}, { __index = UI })
    self.config = config
    self.restart_loading_window()
    return self
end

function UI.restart_loading_window(self)
    local width = math.min(120, vim.o.columns - 4)
    local height = 10
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    UI.min_height = height
    UI.frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    UI.current_frame = 1
    UI.timer = nil
    UI.opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = '',
        title_pos = 'center'
    }
end

function UI.create_loading_window(sefl)
    local buf = vim.api.nvim_create_buf(false, true)

    local width = 30
    local height = 1
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    UI.opts.row = row
    UI.opts.height = height
    UI.opts.col = col
    UI.opts.width = width
    UI.opts.title = ' Loading '

    local win = vim.api.nvim_open_win(buf, false, UI.opts)

    return buf, win
end

function UI.create_new_window(self, title, content)
    while #content > 0 and content[#content] == "" do
        table.remove(content)
    end

    table.insert(content, "")
    table.insert(content, string.rep("─", UI.opts.width - 2))
    table.insert(content, "Note: This explanation is AI-generated and should be verified for accuracy.")
    table.insert(content, "Press 'q' or <Esc> to close this window.")

    local height = math.min(math.max(#content, UI.min_height), vim.o.lines - 4)

    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)

    UI.opts.row = row
    UI.opts.title = title

    local win = vim.api.nvim_open_win(buf, true, UI.opts)
    vim.api.nvim_win_set_option(win, 'wrap', true)
    vim.api.nvim_win_set_option(win, 'conceallevel', 2)

    local last_lines = #content
    if last_lines > 2 then
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', last_lines - 1, 0, -1)
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', last_lines, 0, -1)
    end

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {silent = true, noremap = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', {silent = true, noremap = true})
end

function UI.show_explanation(self, text)
    UI:restart_loading_window()
    local lines = vim.split(text, '\n')
    UI:create_new_window(' Code Analysis ',lines)
end

function UI.show_error(self, message)
    UI:restart_loading_window()
    local lines = vim.split(message, '\n')
    UI:create_new_window(' Error message ',lines)
end

function UI.start_spiner(self)
    UI:restart_loading_window()
    local buf, win = UI:create_loading_window()
    UI.timer = vim.loop.new_timer()
    UI.timer:start(0, 100, vim.schedule_wrap(function ()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false,{string.format("  %s  Analyzing function...", UI.frames[UI.current_frame])})
        UI.current_frame = (UI.current_frame % #UI.frames) + 1
    end))
end

function UI.stop_spiner(self)
    if UI.timer then
        UI.timer:stop()
        UI.timer:close()
    end

    if UI.loading_win and vim.api.nvim_win_is_valid(UI.loading_win) then
        vim.api.nvim_win_close(UI.loading_win, true)
    end

    if UI.loading_buf and vim.api.nvim_buf_is_valid(UI.loading_buf) then
        vim.api.nvim_buf_delete(UI.loading_buf, { force = true })
    end
end

return UI
