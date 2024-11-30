local UI = {}

function UI.new(config)
    local self = setmetatable({}, { __index = UI })
    self.config = config
    return self
end

function UI.show_error(message)
    local width = math.min(80, vim.o.columns - 4)
    local height = math.min(10, vim.o.lines - 4)

    local buf = vim.api.nvim_create_buf(false, true)

    local lines = vim.split(message, '\n')
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = ' Error ',
        title_pos = 'center'
    }

    local win = vim.api.nvim_open_win(buf, true, opts)

    vim.api.nvim_win_set_option(win, 'wrap', true)

    vim.api.nvim_buf_add_highlight(buf, -1, 'ErrorMsg', 0, 0, -1)

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>',
        {silent = true, noremap = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>',
        {silent = true, noremap = true})
end

function UI.create_loading_animation()
    local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local current_frame = 1
    local timer = nil
    local loading_buf = nil
    local loading_win = nil

    local function create_loading_window()
        loading_buf = vim.api.nvim_create_buf(false, true)

        local width = 30
        local height = 1
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local opts = {
            relative = 'editor',
            row = row,
            col = col,
            width = width,
            height = height,
            style = 'minimal',
            border = 'rounded'
        }

        loading_win = vim.api.nvim_open_win(loading_buf, false, opts)
        return loading_buf, loading_win
    end

    local function update_spinner()
        if loading_buf and vim.api.nvim_buf_is_valid(loading_buf) then
            vim.api.nvim_buf_set_lines(loading_buf, 0, -1, false,
                {string.format("  %s  Analyzing function...", frames[current_frame])})
            current_frame = (current_frame % #frames) + 1
        else
            if timer then
                timer:stop()
            end
        end
    end

    local function start()
        local buf, win = create_loading_window()
        timer = vim.loop.new_timer()
        timer:start(0, 100, vim.schedule_wrap(update_spinner))
        return buf, win
    end

    local function stop()
        if timer then
            timer:stop()
            timer:close()
        end
        if loading_win and vim.api.nvim_win_is_valid(loading_win) then
            vim.api.nvim_win_close(loading_win, true)
        end

        if loading_buf and vim.api.nvim_buf_is_valid(loading_buf) then
            vim.api.nvim_buf_delete(loading_buf, { force = true })
        end
    end

    return {
        start = start,
        stop = stop
    }
end

function UI.show_explanation(text)

    local width = math.min(120, vim.o.columns - 4)
    local min_height = 10
    local lines = vim.split(text, '\n')

    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end

    table.insert(lines, "")
    table.insert(lines, string.rep("─", width - 2))
    table.insert(lines, "Note: This explanation is AI-generated and should be verified for accuracy.")
    table.insert(lines, "Press 'q' or <Esc> to close this window.")

    local content_height = #lines
    local height = math.min(math.max(content_height, min_height), vim.o.lines - 4)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = ' Function Analysis ',
        title_pos = 'center'
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_win_set_option(win, 'wrap', true)
    vim.api.nvim_win_set_option(win, 'conceallevel', 2)

    local last_lines = #lines
    if last_lines > 2 then
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', last_lines - 1, 0, -1)
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', last_lines, 0, -1)
    end

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {silent = true, noremap = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', {silent = true, noremap = true})

    return buf, win
end

return UI
