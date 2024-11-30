local Parser = {}

function Parser.new(config)
    local self = setmetatable({}, { __index = Parser })
    self.config = config
    return self
end

function Parser.extract_function_context(self)
    local lines_before, lines_after = self.calculate_context_lines(self.config.context_window)

    local line = vim.fn.line('.')
    local lines = vim.api.nvim_buf_get_lines(0, 
        math.max(0, line - lines_before),
        math.min(line + lines_after, vim.fn.line('$')),
        false
    )

    return table.concat(lines, '\n')
end

function Parser.calculate_context_lines(context_window)
    local total_available_tokens = math.floor(context_window * 0.6)
    local total_lines = math.floor(total_available_tokens / 45)

    local lines_before = math.floor(total_lines * 0.4)
    local lines_after = math.floor(total_lines * 0.6)

    return lines_before, lines_after
end

function Parser.clean_model_output(raw_output)

    local assistant_response = string.match(raw_output, "<|im_start|>assistant\n(.-)\n*%[end of text%]")

    if assistant_response == nil or assistant_response == '' then
        return nil
    end

    assistant_response = string.gsub(assistant_response,"<|im_[^>]+>", "") -- Remove any remaining tokens
    assistant_response = string.gsub(assistant_response,"\n+", "\n")       -- Normalize newlines
    assistant_response = string.gsub(assistant_response,"^%s+", "")        -- Remove leading whitespace
    assistant_response = string.gsub(assistant_response,"%s+$", "")        -- Remove trailing whitespace

    local paragraphs = {}
    for para in string.gmatch(assistant_response,"[^\n]+") do
        if string.match(para,"%S") then
            table.insert(paragraphs, para)
        end
    end

    local formatted_output = {
        "Main Purpose:",
        "  " .. (paragraphs[1] or "No information available"),
        "",
        "Implementation Details:",
        "  " .. (paragraphs[2] or "No information available"),
        "",
        "Key Patterns & Techniques:",
        "  " .. (paragraphs[3] or "No information available"),
        "",
        "Notable Behaviors:",
        "  " .. (paragraphs[4] or "No information available")
    }

    return table.concat(formatted_output, "\n")
end

return Parser
