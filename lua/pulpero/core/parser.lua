local Parser = {}

function Parser.new(config)
    local self = setmetatable({}, { __index = Parser })
    if config == nil then
        error("Parser config is nil")
    end
    self.maxLineLength = config.maxLineLength
    return self
end

function Parser.formatResponse(self, text)
    if not text or text == "" then
        return nil
    end

    local result = {}
    text = text:gsub("%s+", " ")
    :gsub("^%s+", "")
    :gsub("%s+$", "")

    local remainingText = text

    while #remainingText > 0 do
        if #remainingText <= self.maxLineLength then
            table.insert(result, remainingText)
            break
        end

        -- Get chunk of max length
        local chunk = remainingText:sub(1, self.maxLineLength)

        -- Try to find sentence end
        local lastPeriod = chunk:match(".*[%.%?%!]()")

        if lastPeriod then
            -- Cut at sentence end
            chunk = remainingText:sub(1, lastPeriod):gsub("%s+$", "")
        else
            -- Try to find word boundary
            local lastSpace = chunk:match(".*%s()")
            if lastSpace then
                chunk = remainingText:sub(1, lastSpace-1):gsub("%s+$", "")
            else
                -- No word boundary found, cut at maxLength-3 and add ellipsis
                chunk = remainingText:sub(1, self.maxLineLength-3) .. "..."
            end
        end

        table.insert(result, chunk)
        remainingText = remainingText:sub(#chunk + 1):gsub("^%s+", "")
    end

    return result
end

function Parser.cleanModelOutput(self, raw_output)
    if not raw_output or raw_output == "" then
        return nil
    end

    -- Try to match the assistant response using multiple patterns
    local patterns = {
        "<|assistant|>\n(.+)$",
        "<|assistant|>\n(.-)\n*%[end of text%]",
        "<|assistant|>\n(.-)%s*$"
    }

    local assistant_response
    for _, pattern in ipairs(patterns) do
        assistant_response = string.match(raw_output, pattern)
        if assistant_response then break end
    end

    if not assistant_response or assistant_response == "" then
        return nil
    end

    local formattedResponse = ""
    assistant_response = assistant_response:gsub("<|assistant[^>]+>", ""):gsub("%[end of text%]", "")

    for line in string.gmatch(assistant_response,"[^\n]+") do
        local subLines = self:formatResponse(line)
        for i = 1, #subLines do
            if subLines and subLines[i] then
                formattedResponse = formattedResponse .."\n" .. subLines[i]
            end
        end
    end
    return formattedResponse
end

return Parser
