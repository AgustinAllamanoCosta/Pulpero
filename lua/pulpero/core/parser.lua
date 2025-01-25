local Parser = {}
function Parser.new(config, logger)
    local self = setmetatable({}, { __index = Parser })
    self.logger = logger
    return self
end

function Parser.cleanModelOutput(self, output)
    self.logger:debug("Data to parse ", { data = output })
    local clean_response = nil
    local in_assistant_response = false
    local response_lines = {}

    for line in output:gmatch("[^\r\n]+") do
        if line:match("<|assistant|>") then
            self.logger:debug("Response found")
            in_assistant_response = true
            table.insert(response_lines, line:gsub("<|assistant|>", "") .. "\n")
            goto continue
        end

        if in_assistant_response then
            if line ~= "" and not line:match("^<|.*|>$") then
                table.insert(response_lines, line:gsub("%[end of text]", " ") .. "\n")
            end
        end
        ::continue::
    end

    if #response_lines > 0 then
        clean_response = table.concat(response_lines, "\n")
    end

    return clean_response
end

return Parser
