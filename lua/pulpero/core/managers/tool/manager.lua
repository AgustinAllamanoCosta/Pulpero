local ToolManager = {}
local json = require("JSON")

function ToolManager.new(logger)
    local self = setmetatable({}, { __index = ToolManager })
    self.tools = {}
    self.logger = logger
    return self
end

function ToolManager:register_tool(tool)
    self.tools[tool.name] = tool
    self.logger:debug("Registered tool: " .. tool.name)
end

function ToolManager:get_tool_descriptions()
    local descriptions = {}
    for name, tool in pairs(self.tools) do
        table.insert(descriptions, {
            name = name,
            description = tool.description,
            parameters = tool.parameters,
            call_example = tool.example
        })
    end
    return descriptions
end

function ToolManager:execute_tool(tool_name, params)
    local tool = self.tools[tool_name]
    if not tool then
        self.logger:error("Tool not found: " .. tool_name)
        return { success = false, error = "Tool not found: " .. tool_name }
    end

    local success, result = pcall(tool.execute, params)

    if success then
        return { success = true, result = result }
    else
        self.logger:error("Tool execution failed: " .. result)
        return { success = false, error = result }
    end
end

function ToolManager:generate_tools_description()
    local tool_descriptions = ""
    local tools = self:get_tool_descriptions()
    if #tools > 0 then
        for _, tool in ipairs(tools) do
            tool_descriptions = tool_descriptions .. string.format(
                "\n- Tool Name: \"%s\"\nDescription: \"%s\"\nCall Example: \"%s\"\n",
                tool.name,
                tool.description,
                tool.call_example
            )
        end
    end
    return tool_descriptions
end

function ToolManager:parse_tool_calls(model_output)
    local tool_calls = {}

    for tool_name, params_str in model_output:gmatch("<tool%s+name=\"(.*)\"%s+params=\"(.*)\"%s+/>") do
        local params = {}
        for param, value in params_str:gmatch("([^=,]+)=([^,]+)") do
            params[param:gsub("%s+", ""):gsub("\n", "")] = value
        end

        table.insert(tool_calls, {
            name = tool_name,
            params = params
        })
    end

    return tool_calls
end

function ToolManager:process_tool_call(tool_call)
    self.logger:debug("Executing tool call", { tool = tool_call.name })

    local tool_result = self:execute_tool(tool_call.name, tool_call.params)

    local result_str = ""
    if tool_result.success then
        result_str = string.format(
            "\nTool Result\nname: \"%s\"\nsuccess:\"true\"\nresult:\n\"%s\"",
            tool_call.name,
            json.encode(tool_result.result)
        )
    else
        result_str = string.format(
            "\nTool Result\nname: \"%s\"\nsuccess: \"false\"\nerror:\"%s\"",
            tool_call.name,
            tool_result.error
        )
    end

    self.logger:debug("Tool executed" .. result_str)
    return result_str
end

function ToolManager:execute_tool_if_exist_call(model_response_with_tool_call)
    local tool_calls = self:parse_tool_calls(model_response_with_tool_call)
    local tool_response = ""
    if #tool_calls > 0 then
        tool_response = self:process_tool_call(tool_calls[1])
    else
        tool_response = model_response_with_tool_call
    end
    return tool_response
end

return ToolManager
