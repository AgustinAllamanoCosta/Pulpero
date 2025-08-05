local ToolManager = {}

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

    self.logger:debug("Executing tool: " .. tool_name, { params = params })

    local success, result = pcall(tool.execute, params)

    if success then
        return { success = true, result = result }
    else
        self.logger:error("Tool execution failed: " .. result)
        return { success = false, error = result }
    end
end

return ToolManager
