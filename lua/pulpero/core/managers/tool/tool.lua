local Tool = {}

function Tool.new(name, description, parameters, callback)
    local self = setmetatable({}, { __index = Tool })
    self.name = name
    self.description = description
    self.parameters = parameters
    self.execute = callback
    return self
end

return Tool
