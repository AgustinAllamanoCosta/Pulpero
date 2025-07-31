local String = require('String')
local OSCommands = require('OSCommands')
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

function Logger.new(class_name, testEnv)
    local self = setmetatable({}, { __index = Logger })
    config.debug_file = "pulpero_".. class_name .."_debug.log"
    config.setpup_file = "pulpero_".. class_name .."_setup.log"
    config.command_output = "pulpero_".. class_name .."_command.log"
    config.error_file = "pulpero_".. class_name .."_error.log"
    self:configured_logger_path_base_on_OS()
    self:clear_logs()
    self.testEnv = testEnv
    return self
end

function Logger.get_config(self)
    return config
end

function Logger.configured_logger_path_base_on_OS(self)
    config.directory = OSCommands:get_temp_dir()
    config.debug_path = OSCommands:create_path_by_OS(config.directory, config.debug_file)
    config.error_path = OSCommands:create_path_by_OS(config.directory, config.error_file)
    config.command_path = OSCommands:create_path_by_OS(config.directory, config.command_output)
    config.setup_path = OSCommands:create_path_by_OS(config.directory, config.setup_file)
end

function Logger.clear_logs(self)
    self:clear_log_file(config.debug_path, config.title_debug)
    self:clear_log_file(config.error_path, config.title_error)
    self:clear_log_file(config.setup_path, config.title_setup)
    self:clear_log_file(config.command_path, config.title_command)
end

function Logger.setup(self, message, data)
    self:write_in_log(config.setup_path, message, data)
end

function Logger.debug(self, message, data)
    self:write_in_log(config.debug_path, message, data)
end

function Logger.error(self, error_text)
    self:write_in_log(config.error_path, error_text, nil)
end

function Logger.command_output(self, output, data)
    self:write_in_log(config.command_path, output, data)
end

function Logger.clear_log_file(self, file_path, file_title)
    local file = io.open(file_path, "w")
    if file then
        file:write(file_title)
        file:close()
    end
end

function Logger.write_in_log(self, path, message, data)
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
        if data then
            print("Data")
            print(String:toString(data))
        end
    end
end

return Logger
