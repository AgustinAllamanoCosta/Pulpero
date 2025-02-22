local ModelManager = {}
local OSCommands = require('util.OSCommands')

function ModelManager.new(logger, default_config)
    local self = setmetatable({}, { __index = ModelManager })
    if logger == nil then
        error("ModelManager logger can not be nil")
    end
    self.logger = logger
    self.config = {
        temp_dir = OSCommands:getTempDir(),
        model_dir = OSCommands:getModelDir(),
        model_path = default_config.model_path,
        all_chunk_download = false,
        status_file = OSCommands:createPathByOS(OSCommands:getTempDir(), "pulpero_download_status.txt"),
        model_assemble = false
    }
    return self
end

function ModelManager.downloadAndAssembleModel(self)
    self.logger:debug("Starting background model download")

    -- Get the path to the download script relative to the plugin
    local script_path = OSCommands:createPathByOS(self.config.model_dir, "download_model.lua")

    -- Build the command with proper path handling
    local cmd
    if OSCommands:getPlatform() == 'windows' then
        cmd = string.format(
            'start /b lua "%s" "%s" "%s" "%s"',
            script_path,
            self.config.temp_dir,
            self.config.model_path,
            self.config.status_file
        )
    else
        cmd = string.format(
            'lua "%s" "%s" "%s" "%s" &',
            script_path,
            self.config.temp_dir,
            self.config.model_path,
            self.config.status_file
        )
    end

    return OSCommands:executeCommand(cmd) == 0
end

return ModelManager
