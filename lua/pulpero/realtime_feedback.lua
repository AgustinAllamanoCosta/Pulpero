local RealtimeFeedback = {}

function RealtimeFeedback.new(virtual_text, service)
    local self = setmetatable({}, { __index = RealtimeFeedback })

    self.virtual_text = virtual_text
    self.service = service

    self.config = {
        debounce_ms = 1500,
        min_line_length = 3,
        max_file_size = 10000,
        max_context_lines = 80,
        excluded_filetypes = {
            "help", "terminal", "quickfix", "nofile", "prompt", "NvimTree",
            "TelescopePrompt", "neo-tree", "oil", "alpha"
        },
        excluded_extensions = {
            "txt", "md", "log", "lock", "sum", "git", "env"
        }
    }

    self.state = {
        last_analysis_time = 0,
        last_content_hash = "",
        reason = "",
        typing_timer = nil,
        analysis_in_progress = false,
    }

    return self
end

function RealtimeFeedback:reset()
    self.virtual_text:clear_all()
    self.state.last_content_hash = ""
    if self.state.typing_timer then
        vim.fn.timer_stop(self.state.typing_timer)
        self.state.typing_timer = nil
    end
end

function RealtimeFeedback:get_treesitter_context_range(current_line)
    local has_parser, parser = pcall(vim.treesitter.get_parser, 0)
    if not has_parser or not parser then
        return nil
    end

    local tree = parser:parse()[1]
    if not tree then
        return nil
    end

    local root = tree:root()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1] - 1
    local col = cursor_pos[2]

    local node = root:named_descendant_for_range(row, col, row, col)
    if not node then
        return nil
    end

    local scope_node = self:find_scope_node(node)
    if not scope_node then
        return nil
    end

    local start_row, _, end_row, _ = scope_node:range()
    local total_lines = vim.api.nvim_buf_line_count(0)

    if end_row - start_row < 5 then
        local parent = scope_node:parent()
        if parent then
            local p_start, _, p_end, _ = parent:range()
            start_row = p_start
            end_row = p_end
        end
    end

    if end_row - start_row > self.config.max_context_lines then
        local half = math.floor(self.config.max_context_lines / 2)
        start_row = math.max(0, current_line - half)
        end_row = math.min(total_lines - 1, current_line + half)
    end

    return start_row, end_row
end

function RealtimeFeedback:find_scope_node(node)
    local filetype = vim.bo.filetype

    local scope_types = self:get_scope_types(filetype)
    if not scope_types then
        return nil
    end

    local current = node
    local best_match = nil

    while current do
        local node_type = current:type()

        for _, scope_type in ipairs(scope_types) do
            if node_type == scope_type then
                best_match = current
            end
        end

        current = current:parent()
    end

    return best_match
end

function RealtimeFeedback:get_scope_types(filetype)
    local scope_map = {
        python = {
            "function_definition", "class_definition", "method_definition",
            "if_statement", "for_statement", "while_statement",
            "try_statement", "with_statement", "match_statement"
        },
        lua = {
            "function_declaration", "function_definition", "method_declaration",
            "if_statement", "for_statement", "for_in_statement",
            "while_statement", "repeat_statement", "table_constructor"
        },
        javascript = {
            "function_declaration", "function_expression", "arrow_function",
            "method_definition", "class_declaration", "class_expression",
            "if_statement", "for_statement", "for_in_statement",
            "while_statement", "try_statement", "switch_statement"
        },
        typescript = {
            "function_declaration", "function_expression", "arrow_function",
            "method_definition", "class_declaration", "interface_declaration",
            "type_alias_declaration", "if_statement", "for_statement",
            "while_statement", "try_statement", "switch_statement"
        },
        typescriptreact = {
            "function_declaration", "function_expression", "arrow_function",
            "method_definition", "class_declaration", "interface_declaration",
            "type_alias_declaration", "if_statement", "for_statement"
        },
        go = {
            "function_declaration", "method_declaration", "func_literal",
            "if_statement", "for_statement", "type_declaration",
            "interface_declaration", "switch_statement", "select_statement"
        },
        rust = {
            "function_item", "struct_item", "enum_item", "impl_item",
            "trait_item", "if_expression", "for_expression",
            "while_expression", "match_expression", "closure_expression"
        },
        c = {
            "function_definition", "class_specifier", "struct_specifier",
            "if_statement", "for_statement", "while_statement",
            "switch_statement", "try_statement"
        },
        cpp = {
            "function_definition", "class_specifier", "struct_specifier",
            "namespace_definition", "if_statement", "for_statement",
            "while_statement", "switch_statement", "try_statement",
            "lambda_expression"
        },
        java = {
            "method_declaration", "class_declaration", "interface_declaration",
            "if_statement", "for_statement", "while_statement",
            "switch_statement", "try_statement"
        },
        kotlin = {
            "function_declaration", "class_declaration", "object_declaration",
            "if_expression", "for_statement", "when_expression"
        },
        ruby = {
            "method", "class", "module", "if", "for", "while",
            "block", "do_block"
        },
        php = {
            "function_definition", "class_declaration", "method_declaration",
            "if_statement", "for_statement", "while_statement"
        },
        swift = {
            "function_declaration", "class_declaration", "struct_declaration",
            "if_statement", "for_statement", "while_statement",
            "switch_statement", "guard_statement"
        },
        scala = {
            "function_definition", "class_definition", "object_definition",
            "if_expression", "for_expression", "match_expression"
        },
        bash = {
            "function_definition", "if_statement", "for_statement",
            "while_statement", "case_statement"
        },
        json = nil,
        yaml = nil,
        toml = nil,
    }

    return scope_map[filetype]
end

function RealtimeFeedback:get_content()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local result = {}
    for i, line in ipairs(lines) do
        if line and line ~= "" then
            table.insert(result, { line_number = i, content = line })
        end
    end
    return result
end

function RealtimeFeedback:get_context_content(start_line, end_line)
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

    local result = {}
    for i, line in ipairs(lines) do
        if line and line ~= "" then
            table.insert(result, {
                line_number = start_line + i,
                content = line
            })
        end
    end
    return result
end

function RealtimeFeedback:get_content_hash()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local hash = 0
    for _, line in ipairs(lines) do
        if line and line ~= "" then
            for c = 1, #line do
                hash = (hash * 31 + string.byte(line, c)) % 2147483647
            end
        end
    end
    return tostring(hash)
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
            self.state.reason = "invalid file/buffer"
            return false
        end
    end

    local file_path = vim.api.nvim_buf_get_name(bufnr)
    if file_path == "" then
        self.state.reason = "invalid file path"
        return false
    end

    local extension = file_path:match("%.([^%.]+)$")
    if extension then
        for _, excluded_ext in ipairs(self.config.excluded_extensions) do
            if extension == excluded_ext then
                self.state = "excluded extension"
                return false
            end
        end
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count > self.config.max_file_size then
        self.state.reason = "file to big"
        return false
    end

    if not self:content_change() then
        self.state.reason = "same content"
        return false
    end

    if (current_time - self.state.last_analysis_time) < self.config.debounce_ms then
        return false
    end

    return true
end

function RealtimeFeedback:content_change()
    local content_hash = self:get_content_hash()
    if content_hash ~= self.state.last_content_hash then
        self.state.last_content_hash = content_hash
        return true
    end
    return false
end

function RealtimeFeedback:analyze_current_context()
    local current_time = vim.loop.hrtime() / 1000000

    if not self:should_analyze_buffer(current_time) then
        print("Avoid to analyze buffer "..self.state.reason)
        return
    end

    self:analyze_current_context_always(current_time)
end

function RealtimeFeedback:analyze_current_context_always(current_time)

    self.state.analysis_in_progress = true
    self.state.last_analysis_time = current_time

    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor_pos[1] - 1

    local context_start, context_end = self:get_treesitter_context_range(current_line)

    local file_content = self:get_content()
    local context_content = nil

    if context_start and context_end then
        context_content = self:get_context_content(context_start, context_end)
    end

    if #file_content < self.config.min_line_length then
        self.state.analysis_in_progress = false
        return
    end

    if context_content ~= nil then
        self.virtual_text:clear_all()
        self.virtual_text:show_at_line("💭 analyzing...", current_line)

        self.service:get_live_code_feedback(
            context_content,
            "",
            function(err, result)
                vim.schedule(function()
                    self.virtual_text:clear_all()
                    self.state.analysis_in_progress = false

                    if err or not result then
                        self.virtual_text:show_at_line("⚠️ Analysis error", current_line)
                        return
                    end

                    self:display_suggestions(result, current_line)
                end)
            end
        )
    else

        self.state.analysis_in_progress = false
        print("Context is nil")
    end
end

function RealtimeFeedback:display_suggestions(result, current_line)
    if not result.has_suggestions or not result.suggestions then
        return
    end

    for _, suggestion in ipairs(result.suggestions) do
        if suggestion.message and suggestion.message ~= "" then
            if not suggestion.line_number then
                suggestion.line_number = current_line + 1
            end
            self.virtual_text:show_suggestion(suggestion)
        end
    end
end

return RealtimeFeedback
