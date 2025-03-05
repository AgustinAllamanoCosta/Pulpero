local OSCommands = require('util.OSCommands')
local Setup = {}

function Setup.new(logger, model_manager, default_config)
    local self = setmetatable({}, { __index = Setup })
    if logger == nil then
        error("Setup logger can not be nil")
    end
    self.logger = logger
    self.command_output = logger:getConfig().command_path
    self.model_manager = model_manager
    self.default_settings = default_config
    return self
end

function Setup.executeCommandAndDump(self, command)
    local formatted_command
    if package.config:sub(1, 1) == '\\' then
        formatted_command = string.format('%s >> "%s" 2>>&1', command, self.command_output)
    else
        formatted_command = string.format('%s >> "%s" 2>&1', command, self.command_output)
    end
    self.logger:setup("Executing command: " .. command)
    local result = OSCommands:executeCommand(formatted_command)
    if type(result) == "number" then
        return result == 0
    else
        return result
    end
end

function Setup.checkCmakeInstalled(self)
    self.logger:setup("Checking if cmake is installed...")
    return self:executeCommandAndDump("cmake --version")
end

function Setup.installCmake(self)
    self.logger:setup("Installing CMake...")
    if OSCommands:isLinux() then
        if not self:executeCommandAndDump("sudo apt-get update && sudo apt-get install -y cmake") then
            return self:executeCommandAndDump("sudo yum -y install cmake")
        end
    elseif OSCommands:isDarwin() then
        return self:executeCommandAndDump("brew install cmake")
    elseif OSCommands:isWindows() then
        return self:executeCommandAndDump("choco install cmake -y")
    end
    return false
end

function Setup.generateLlamaPath(self)
    local llama_dir = OSCommands:createPathByOS(OSCommands:getDataPath(), 'llama.cpp')
    local build_dir = OSCommands:createPathByOS(llama_dir, 'build')
    local build_bin = OSCommands:createPathByOS(build_dir, 'bin')
    local dir_info = {
        llama_dir = llama_dir,
        llama_bin = OSCommands:createPathByOS(build_bin, 'llama-cli'),
        build_dir = build_dir
    }
    return dir_info
end

function Setup.setupLlama(self)
    self.logger:setup("Preparing Llama cpp")
    if not self:checkCmakeInstalled() then
        self.logger:setup("CMake not found, attempting to install...")
        if not self:installCmake() then
            self.logger:setup("Failed to install CMake. Please install it manually.")
            return "", 1
        end
        self.logger:setup("CMake installed successfully")
    end

    local dir_info = self:generateLlamaPath()

    if not OSCommands:fileExists(dir_info.llama_dir) then
        self.logger:setup("Cloning llama repo")
        local clone_command = string.format('git clone %s "%s"', self.config.llama_repo, dir_info.llama_dir)
        if not self:executeCommandAndDump(clone_command) then
            self.logger:setup("Failed to clone llama.cpp")
            return "", 1
        end
    else
        self.logger:setup("Llama is already cloned, skipping")
    end

    if not OSCommands:fileExists(dir_info.llama_bin) then
        self.logger:setup("Compile llama cpp repository")
        OSCommands:ensureDir(dir_info.build_dir)
        local build_commands = string.format('cd "%s" && cmake .. && cmake --build . --config Release',
            dir_info.build_dir)
        if not self:executeCommandAndDump(build_commands) then
            self.logger:setup("Failed to compile llama.cpp")
            return "", 1
        end
    else
        self.logger:setup("Llama is already compiled, skipping")
    end

    return dir_info.llama_bin, 0
end

function Setup.configureMemory(self, total_mem)
    if total_mem and total_mem < 8192 then      -- Less than 8GB RAM
        return 512, 2                           -- Conservative settings
    elseif total_mem and total_mem < 16384 then -- Less than 16GB RAM
        return 1024, 4
    else                                        -- 16GB or more RAM
        return 4096, 8
    end
end

function Setup.prepearEnv(self)
    self.logger:setup("Prepearing env")
    local llama_path, llama_setup_result = self:setupLlama()
    if llama_setup_result == 0 then
        self.config.llama_cpp_path = llama_path
    else
        error("Failed to initialize Pulpero")
    end
    --check if the model exist
    if true then
        self.config.pulpero_ready = true
    else
        self.config.pulpero_ready = false
        self.model_manager:downloadAndAssembleModel()
    end
    return self.config
end

function Setup.configurePlugin(self)
    local context_window = nil
    local threads = nil

    if OSCommands:isLinux() then
        local output = OSCommands:executeCommand("free -m | grep Mem:")
        if output then
            local memory = tonumber(output:match("Mem:%s+(%d+)"))
            context_window, threads = self:configureMemory(memory)
        end
    elseif OSCommands:isDarwin() then
        local output = OSCommands:executeCommand("sysctl hw.memsize")
        if output then
            local bytes = tonumber(output:match("hw.memsize: (%d+)"))
            if bytes then
                local memory = math.floor(bytes / (1024 * 1024)) -- Convert bytes to MB
                context_window, threads = self:configureMemory(memory)
            end
        end
    elseif OSCommands:isWindows() then
        local output = OSCommands:executeCommand("wmic ComputerSystem get TotalPhysicalMemory")
        if output then
            local bytes = tonumber(output:match("(%d+)"))
            if bytes then
                local memory = math.floor(bytes / (1024 * 1024)) -- Convert bytes to MB
                context_window, threads = self:configureMemory(memory)
            end
        end
    end

    self.default_settings.context_window = context_window
    self.default_settings.num_threads = threads
    self.config = self.default_settings

    self.logger:setup("Memory configured", { config = self.config })
    return self.config
end

return Setup
