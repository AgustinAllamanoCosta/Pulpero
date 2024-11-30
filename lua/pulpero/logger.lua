local Logger = {}

function Logger.new(config)
    local self = setmetatable({}, { __index = Logger })
    self.debug_path = string.format("%s/%s", config.directory, config.debug_file)
    self.error_path = string.format("%s/%s", config.directory, config.error_file)
    return self
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
end

function Logger.debug(self, message, data)
    local debug_file = io.open(self.debug_path, "a")
    if debug_file then
        debug_file:write(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message .. "\n")
        if data then
            debug_file:write("Data: " .. vim.inspect(data) .. "\n")
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
