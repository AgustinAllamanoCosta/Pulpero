local Logger = {}
local config = {
    directory = "/tmp",
    debug_file = "pulpero_debug.log",
    setup_file = "pulpero_setup.log",
    command_output = "pulpero_command.log",
    error_file = "pulpero_error.log"
}

function Logger.new()
    local self = setmetatable({}, { __index = Logger })
    self.debug_path = string.format("%s/%s", config.directory, config.debug_file)
    self.error_path = string.format("%s/%s", config.directory, config.error_file)
    self.command_path = string.format("%s/%s", config.directory, config.command_output)
    self.setup_path = string.format("%s/%s", config.directory, config.setup_file)
    return self
end

function Logger.toString(self, table)
    local result = "{"
    for k, v in pairs(table) do
        if type(k) == "string" then
            result = result.."[\""..k.."\"]".."="
        end

        if type(v) == "table" then
            result = result .. self:toString(v)
        elseif type(v) == "boolean" then
            result = result .. tostring(v)
        else
            result = result .. "\"" .. v .. "\""
        end
        result = result .. ","
    end
    if result ~= "{" then
        result = result:sub(1, result:len()-1)
    end
    return result .. "}"
end

function Logger.clear_logs(self)
    local debug_file = io.open(self.debug_path, "w")
    if debug_file then
        debug_file:write("=== New Debug Session Started ===\n")
        debug_file:close()
    end
    local error_file = io.open(self.error_path, "w")
    if error_file then
        error_file:write("=== New Error Session Started ===\n")
        error_file:close()
    end
    local command_file = io.open(self.command_path, "w")
    if command_file then
        command_file:write("=== New Command Session Started ===\n")
        command_file:close()
    end
    local setup_file = io.open(self.setup_path, "w")
    if setup_file then
        setup_file:write("=== New SetUp Session Started ===\n")
        setup_file:close()
    end
end

function Logger.setup(self, message, data)
    local debug_file = io.open(self.setup_path, "a")
    if debug_file then
        debug_file:write(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message .. "\n")
        if data then
            debug_file:write("Data: " .. self:toString(data) .. "\n")
        end
        debug_file:write("----------------------------------------\n")
        debug_file:close()
    end
end

function Logger.debug(self, message, data)
    local debug_file = io.open(self.debug_path, "a")
    if debug_file then
        debug_file:write(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message .. "\n")
        if data then
            debug_file:write("Data: " .. self:toString(data) .. "\n")
        end
        debug_file:write("----------------------------------------\n")
        debug_file:close()
    end
end

function Logger.error(self, error_text)
    local error_file = io.open(self.error_path, "a")
    if error_file then
        error_file:write(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. error_text .. "\n")
        error_file:write("----------------------------------------\n")
        error_file:close()
    end
end

return Logger
