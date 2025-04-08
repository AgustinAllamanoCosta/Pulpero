local Parser = {}
function Parser.new(logger)
    local self = setmetatable({}, { __index = Parser })
    self.logger = logger
    return self
end

function Parser.clean_model_output(self, output)
    self.logger:debug("Data to parse ", { data = output })
    local clean_response = nil
    local in_assistant_response = false
    local skip_line = false
    local response_lines = {}

    for line in output:gmatch("[^\r\n]+") do

        if line:match("Current open file code:") or line:match("Chat History") then
            self.logger:debug("Skipping line")
            skip_line = true
            goto continue
        end

        if (line:match("End File") or line:match("End History")) and skip_line then
            self.logger:debug("Not Skipping lines")
            skip_line = false
            goto continue
        end

        if skip_line then
            goto continue
        end

        if line:match("A:") then
            self.logger:debug("Response found")
            in_assistant_response = true
            table.insert(response_lines, line:gsub("A:", ""):gsub("%[end of text]", " ") .. "\n")
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

function Parser.get_code_from_response(self, output)
    self.logger:debug("Data to parse ", { data = output })
    local in_code = false
    local code_lines = {}

    for line in output:gmatch("[^\r\n]+") do
        if line:match("```%s*") and not in_code then
            self.logger:debug("Code in response found")
            in_code = true
            goto continue
        end

        if line:match("```") and in_code then
            self.logger:debug("End of the code in response found")
            in_code = false
            goto continue
        end

        if in_code then
            if line ~= "" then
                table.insert(code_lines, line .. "\n")
            end
        end
        ::continue::
    end

    self.logger:debug("Code parse ", { code_lines })
    return code_lines
end

function Parser.process_tool_calls(self, model_output)
    if not self.tool_manager then
        self.logger:debug("Tool manager not set, skipping tool execution")
        return model_output
    end

    local tool_calls = self.tool_manager:parse_tool_calls(model_output)
    if #tool_calls == 0 then
        return model_output
    end

    local processed_output = model_output

    for _, tool_call in ipairs(tool_calls) do
        self.logger:debug("Processing tool call", { tool = tool_call.name })

        local tool_result = self.tool_manager:execute_tool(tool_call.name, tool_call.params)

        local result_str
        if tool_result.success then
            result_str = string.format(
                "<tool_result name=\"%s\" success=\"true\">\n%s\n</tool_result>",
                tool_call.name,
                json.encode(tool_result.result)
            )
        else
            result_str = string.format(
                "<tool_result name=\"%s\" success=\"false\" error=\"%s\"></tool_result>",
                tool_call.name,
                tool_result.error
            )
        end

        local pattern = string.format("<tool%s+name=\"%s\"%s+params=\"[^\"]+\">", "%", tool_call.name, "%")
        processed_output = processed_output:gsub(pattern, result_str)
    end

    return processed_output
end

return Parser
