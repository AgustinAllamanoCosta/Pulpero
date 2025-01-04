local String = require('pulpero.util.String')
local OSCommands = require('pulpero.util.OSCommands')
local Logger = {}
local config = {
    directory = "/tmp",
    debug_file = "pulpero_debug.log",
    setup_file = "pulpero_setup.log",
    command_output = "pulpero_command.log",
    error_file = "pulpero_error.log",
    debug_path = "",
    error_path = "",
    command_path = "",
    setup_path = "",
    title_setup = "=== New SetUp Session Started ===\n",
    title_command = "=== New Command Session Started ===\n",
    title_error = "=== New Error Session Started ===\n",
    title_debug = "=== New Debug Session Started ===\n"
}

function Logger.new(testEnv)
    local self = setmetatable({}, { __index = Logger })
    self:configuredLoggerPathBaseOnOS()
    self:clearLogs()
    self.testEnv = testEnv
    return self
end

function  Logger.getConfig(self)
    return config
end

function Logger.configuredLoggerPathBaseOnOS(self)
    local os_name = OSCommands:getPlatform()

    if os_name == "linux" then
        local tmp = os.getenv("TMPDIR")
        if tmp then
            config.directory = tmp
        else
            local candidates = {
                "/tmp",
                "/var/tmp",
                "/usr/tmp"
            }

            for _, path in ipairs(candidates) do
                local file = io.open(path .. "/test_write", "w")
                if file then
                    file:close()
                    os.remove(path .. "/test_write")
                    config.directory = path
                    return
                end
            end
        end

        config.debug_path = string.format("%s/%s", config.directory, config.debug_file)
        config.error_path = string.format("%s/%s", config.directory, config.error_file)
        config.command_path = string.format("%s/%s", config.directory, config.command_output)
        config.setup_path = string.format("%s/%s", config.directory, config.setup_file)
    elseif os_name == "darwin" then

        config.debug_path = string.format("%s/%s", config.directory, config.debug_file)
        config.error_path = string.format("%s/%s", config.directory, config.error_file)
        config.command_path = string.format("%s/%s", config.directory, config.command_output)
        config.setup_path = string.format("%s/%s", config.directory, config.setup_file)
    elseif os_name == "windows" then

        local temp = os.getenv("TEMP")
        if temp then
            config.directory = temp
        else
            local tmp = os.getenv("TMP")
            if tmp then
                config.directory = tmp
            else
                config.directory =  "C:\\Windows\\Temp"
            end
        end

        config.debug_path = string.format("%s\\%s", config.directory, config.debug_file)
        config.error_path = string.format("%s\\%s", config.directory, config.error_file)
        config.command_path = string.format("%s\\%s", config.directory, config.command_output)
        config.setup_path = string.format("%s\\%s", config.directory, config.setup_file)
    end
end

function Logger.clearLogs(self)
    self:clearLogFile(config.debug_path, config.title_debug)
    self:clearLogFile(config.error_path, config.title_error)
    self:clearLogFile(config.setup_path, config.title_setup)
    self:clearLogFile(config.command_path, config.title_command)
end

function Logger.setup(self, message, data)
    self:writeInLog(config.setup_path, message, data)
end

function Logger.debug(self, message, data)
    self:writeInLog(config.debug_path, message, data)
end

function Logger.error(self, error_text)
    self:writeInLog(config.error_path, error_text, nil)
end

function Logger.commandOutput(self, output, data)
    self:writeInLog(config.command_path, output, data)
end

function Logger.clearLogFile(self, file_path, file_title)
    local file = io.open(file_path, "w")
    if file then
        file:write(file_title)
        file:close()
    end
end

function Logger.writeInLog(self, path, message, data)
    if path == nil then
        error("Logger path can not be nil")
    end
    local log_file = io.open(path, "a")
    local message_template = [[
%s: %s
Data: %s
----------------------------------------
]]
    if data then
        log_file:write(string.format(message_template, os.date("%Y-%m-%d %H:%M:%S"), message, String:toString(data)))
    else
        log_file:write(string.format(message_template, os.date("%Y-%m-%d %H:%M:%S"), message, ""))
    end
    log_file:close()
    if self.testEnv then
        print(message)
    end
end

return Logger
