local Parser = {}

function Parser.new(config)
    local self = setmetatable({}, { __index = Parser })
    self.config = config
    return self
end

function Parser.get_visual_selection(self)
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local lines = vim.api.nvim_buf_get_lines(
        0,
        start_pos[2] - 1,  -- Convert from 1-based to 0-based indexing
        end_pos[2],
        false
    )

    if #lines == 0 then
        return nil
    end

    return table.concat(lines, "\n")
end

function Parser.clean_model_output(raw_output)

    local assistant_response = string.match(raw_output,"<|assistant|>\n(.+)$")
        or string.match(raw_output,"<|assistant|>\n(.-)\n*%[end of text%]")
        or string.match(raw_output,"<|assistant|>\n(.-)%s*$")

    if assistant_response == nil or assistant_response == '' then
        return nil
    end

    assistant_response = string.gsub(assistant_response,"<|assistant[^>]+>", "") -- Remove any remaining tokens
    assistant_response = string.gsub(assistant_response,"%[end of text%]", "") -- Remove any remaining tokens
    assistant_response = string.gsub(assistant_response,"\n+", "\n")       -- Normalize newlines
    assistant_response = string.gsub(assistant_response,"^%s+", "")        -- Remove leading whitespace
    assistant_response = string.gsub(assistant_response,"%s+$", "")        -- Remove trailing whitespace

    return assistant_response

end

return Parser
