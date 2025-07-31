local json = require("JSON")
local ToolManager = {}

function ToolManager.new(logger)
    local self = setmetatable({}, { __index = ToolManager })
    self.tools = {}
    self.logger = logger
    return self
end

function ToolManager.register_tool(self, tool)
    self.tools[tool.name] = tool
    self.logger:debug("Registered tool: " .. tool.name)
end

function ToolManager.get_tool_descriptions(self)
    local descriptions = {}
    for name, tool in pairs(self.tools) do
        table.insert(descriptions, {
            name = name,
            description = tool.description,
            parameters = tool.parameters
        })
    end
    return descriptions
end

function ToolManager.execute_tool(self, tool_name, params)
    local tool = self.tools[tool_name]
    if not tool then
        self.logger:error("Tool not found: " .. tool_name)
        return { success = false, error = "Tool not found: " .. tool_name }
    end

    self.logger:debug("Executing tool: " .. tool_name, { params = params })

    local success, result = pcall(tool.execute, params)

    if success then
        return { success = true, result = result }
    else
        self.logger:error("Tool execution failed: " .. result)
        return { success = false, error = result }
    end
end

function ToolManager.parse_tool_calls(self, model_output)
    local tool_calls = {}

    for tool_name, params_str in model_output:gmatch("<tool%s+name=\"(.*)\"%s+params=\"(.*)\"%s+/>") do
        local params = {}
        for param, value in params_str:gmatch("([^=,]+)=([^,]+)") do
            params[param] = value
        end

        table.insert(tool_calls, {
            name = tool_name,
            params = params
        })
    end

    return tool_calls
end

return ToolManager
