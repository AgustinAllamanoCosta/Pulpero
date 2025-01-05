local OSCommands = require('util.OSCommands')
local Setup = {}
local default_settings = {
    context_window = 1024,
    temp = "0.4",
    num_threads = "4",
    top_p = "0.4",
    token="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",
    model = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
    llama_repo = "https://github.com/ggerganov/llama.cpp.git",
    maxLineLength = 200,
    os = OSCommands:getPlatform()
}

function Setup.new(logger)
    local self = setmetatable({}, { __index = Setup })
    if logger == nil then
        error("Setup logger can not be nil")
    end
    self.logger = logger
    self.command_output = logger:getConfig().command_path
    return self
end

function Setup.executeCommandAndDump(self, command)
    local formatted_command
    if package.config:sub(1,1) == '\\' then
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
    local os_name = self.config.os
    if os_name == "linux" then
        if not self:executeCommandAndDump("sudo apt-get update && sudo apt-get install -y cmake") then
            return self:executeCommandAndDump("sudo yum -y install cmake")
        end
    elseif os_name == "darwin" then
        return self:executeCommandAndDump("brew install cmake")
    elseif os_name == "windows" then
        return self:executeCommandAndDump("choco install cmake -y")
    end
    return false
end

function Setup.generateLlamaPath(self)
    local dir_info = {
    llama_dir = "",
    llama_bin = "",
    build_dir = ""
    }
    if self.config.os == 'windows' then
        dir_info.llama_dir = OSCommands:getDataPath() .. '\\llama.cpp'
        dir_info.llama_bin = dir_info.llama_dir .. '\\build\\bin\\llama-cli'
        dir_info.build_dir = dir_info.llama_dir .. '\\build'
    else
        dir_info.llama_dir = OSCommands:getDataPath() .. '/llama.cpp'
        dir_info.llama_bin = dir_info.llama_dir .. '/build/bin/llama-cli'
        dir_info.build_dir = dir_info.llama_dir .. '/build'
    end
    return dir_info
end

function Setup.generateModelPath(self)
    local data_dir = OSCommands:getDataPath()
    OSCommands:ensureDir(data_dir)
    local model_path = ''
    if self.config.os == 'windows' then
        model_path =  data_dir .. '\\model.gguf'
    else
        model_path =  data_dir .. '/model.gguf'
    end
    return  model_path
end

function Setup.downloadModel(self)
    self.logger:setup("Prepearing model")
    local model_path = self:generateModelPath()

    self.logger:setup("Checking if file exist " .. model_path)
    if OSCommands:fileExists(model_path) then
        self.logger:setup("Model already exist skipping download")
        return model_path, 0
    end

    self.logger:setup("Downloading TinyLlama model (this may take a while)...")
    local download_command = string.format(
    'wget -O "%s" --header="Authorization: Bearer %s" %s',
    model_path,
    self.config.token,
    self.config.model)
    if self:executeCommandAndDump(download_command) then
        self.logger:setup("Download ended")
        return model_path, 0
    else
        self.logger:setup("Failed to download the model")
        return "", 1
    end
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
        local build_commands = string.format('cd "%s" && cmake .. && cmake --build . --config Release', dir_info.build_dir)
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
    if total_mem and total_mem < 4096 then -- Less than 4GB RAM
        return 256, 2
    elseif total_mem and total_mem < 8192 then -- Less than 8GB RAM
        return 512, 4
    else -- 8GB or more RAM
        return 3072, 6
    end
end

function Setup.prepearEnv(self)
    self.logger:setup("Prepearing env")
    local llama_path, llama_setup_result = self:setupLlama()
    local model_path, model_setup_result = self:downloadModel()
    if llama_setup_result == 0 and model_setup_result == 0 then
        self.config.llama_cpp_path = llama_path
        self.config.model_path = model_path
    else
        error("Failed to initialize Pulpero")
    end
    return self.config
end

function Setup.configurePlugin(self)
    local context_window = nil
    local threads = nil
    local platform = default_settings.os

    if platform == "linux" then
        local output = OSCommands:executeCommand("free -m | grep Mem:")
        if output then
            local memory = tonumber(output:match("Mem:%s+(%d+)"))
            context_window, threads = self:configureMemory(memory)
        end
    elseif platform == "darwin" then
        local output = OSCommands:executeCommand("sysctl hw.memsize")
        if output then
            local bytes = tonumber(output:match("hw.memsize: (%d+)"))
            if bytes then
                local memory = math.floor(bytes / (1024 * 1024))  -- Convert bytes to MB
                context_window, threads = self:configureMemory(memory)
            end
        end
    elseif platform == "windows" then
        local output = OSCommands:executeCommand("wmic ComputerSystem get TotalPhysicalMemory")
        if output then
            local bytes = tonumber(output:match("(%d+)"))
            if bytes then
                local memory = math.floor(bytes / (1024 * 1024))  -- Convert bytes to MB
                context_window, threads = self:configureMemory(memory)
            end
        end
    end

    default_settings.context_window = context_window
    default_settings.num_threads = threads
    self.config = default_settings

    self.logger:setup("Memory configured", { config = self.config })
    return self.config
end

return Setup
