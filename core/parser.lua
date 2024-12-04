local Parser = {}

function Parser.new(config)
    local self = setmetatable({}, { __index = Parser })
    self.config = config
    return self
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
