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
        if line:match("A:") then
            self.logger:debug("Response found")
            in_assistant_response = true
            table.insert(response_lines, line:gsub("A:", "") .. "\n")
            goto continue
        end

        if in_assistant_response then
            if line ~= "" and not line:match("<｜end▁of▁sentence｜>") then
                local clean_line = line:gsub("%[INST]", ""):gsub("%[/INST]", ""):gsub("%[end of text]", " ")
                table.insert(response_lines, clean_line .. "\n")
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
