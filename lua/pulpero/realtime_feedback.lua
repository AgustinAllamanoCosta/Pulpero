local RealtimeFeedback = {}

function RealtimeFeedback.new(virtual_text, service)
    local self = setmetatable({}, { __index = RealtimeFeedback })

    self.virtual_text = virtual_text
    self.service = service

    self.config = {
        debounce_ms = 2000,    -- Wait 2 seconds after stopping typing
        min_line_length = 10,  -- Minimum line length to trigger analysis
        max_file_size = 10000, -- Maximum file size in lines
        excluded_filetypes = {
            "help", "terminal", "quickfix", "nofile", "prompt"
        },
        excluded_extensions = {
            "txt", "md", "log", "json", "xml"
        }
    }

    self.state = {
        last_analysis_time = 0,
        last_content_hash = "",
        typing_timer = nil,
        mode_timer = nil,
        analysis_in_progress = false,
    }

    return self
end

function RealtimeFeedback:reset()
    self.virtual_text:clear_all()
    self.state.last_content_hash = ""
    self.state.last_cursor_line = 0
    if self.state.typing_timer then
        vim.fn.timer_stop(self.state.typing_timer)
        self.state.typing_timer = nil
    end
    if self.state.mode_timer then
        vim.fn.timer_stop(self.state.mode_timer)
        self.state.mode_timer = nil
    end
end

function RealtimeFeedback:should_analyze_buffer(current_time)
    if self.state.analysis_in_progress then
        return false
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

    for _, excluded in ipairs(self.config.excluded_filetypes) do
        if filetype == excluded or buftype == excluded then
            return false
        end
    end

    local file_path = vim.api.nvim_buf_get_name(bufnr)
    if file_path == "" then
        return false
    end

    local extension = file_path:match("%.([^%.]+)$")
    if extension then
        for _, excluded_ext in ipairs(self.config.excluded_extensions) do
            if extension == excluded_ext then
                return false
            end
        end
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count > self.config.max_file_size then
        return false
    end

    if not self:content_chage() then
        return false
    end

    if (current_time - self.state.last_analysis_time) < self.config.debounce_ms then
        return false
    end

    return true
end

function RealtimeFeedback:content_chage()
    local content_hash = self:get_content_hash()
    if content_hash ~= self.state.last_content_hash then
        self.state.last_content_hash = content_hash
        return true
    end
    return false
end

function RealtimeFeedback:get_content_hash()
    local content = self:get_content()
    local hash = 0
    for i = 1, #content do
        hash = (hash * 31 + string.byte(content, i)) % 2147483647
    end

    return tostring(hash)
end

function RealtimeFeedback:get_content()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local content = table.concat(lines, "\n")
    return content
end

function RealtimeFeedback:analyze_current_context()
    local current_time = vim.loop.hrtime() / 1000000

    if not self:should_analyze_buffer(current_time) then
        return
    end

    self.state.analysis_in_progress = true
    self.state.last_analysis_time = current_time

    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor_pos[1] - 1

    local context_start, context_end = self:get_smart_context_range(current_line)
    local context_lines = vim.api.nvim_buf_get_lines(0, context_start, context_end + 1, false)
    local context_content = table.concat(context_lines, "\n")
    local file_content = self:get_content()

    if #context_content < self.config.min_line_length then
        self.state.analysis_in_progress = false
        return
    end

    self.virtual_text:clear_all()
    self.virtual_text:show_at_line("💭 thinking...", current_line)

    self.service:get_live_code_feedback(
        file_content,
        context_content,
        function(err, result)
            vim.schedule(function()
                self.virtual_text:clear_all()
                self.state.analysis_in_progress = false

                if err and result == "" or result == nil then
                    self.virtual_text:show_at_line("⚠️ Analysis error", current_line)
                    return
                end

                local formated_result = result:gsub("```", ""):gsub("\\n", "\n")
                self.virtual_text:show_at_line(formated_result, current_line)
            end)
        end
    )
end

function RealtimeFeedback:get_smart_context_range(current_line)
    local bufnr = vim.api.nvim_get_current_buf()
    local total_lines = vim.api.nvim_buf_line_count(bufnr)

    local function_start = current_line
    local function_end = current_line

    for i = current_line, math.max(0, current_line - 20), -1 do
        local line_content = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1] or ""
        if line_content:match("^%s*function") or
            line_content:match("^%s*local%s+function") or
            line_content:match("^%s*async%s*function") or
            line_content:match("^%s*export%s*async%s*function") or
            line_content:match("^%s*def%s+") or
            line_content:match("^%s*class%s+") or
            line_content:match("^%s*export%s*class%s+") or
            line_content:match("^%s*if%s+") or
            line_content:match("^%s*for%s+") or
            line_content:match("^%s*while%s+") then
            function_start = i
            break
        end
    end

    for i = current_line, math.min(total_lines - 1, current_line + 20) do
        local line_content = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1] or ""
        if line_content:match("^%s*end%s*$") or
            line_content:match("^%s*}%s*$") or
            line_content:match("^%s*return") then
            function_end = i
            break
        end
    end

    if function_end - function_start < 2 then
        function_start = math.max(0, current_line - 6)
        function_end = math.min(total_lines - 1, current_line + 6)
    end

    return function_start, function_end
end

return RealtimeFeedback
