local Setup = {}

function Setup.new(logger)
    local self = setmetatable({}, { __index = Setup })
    self.logger = logger
    self.command_output = logger.command_path
    return self
end

function Setup.execute_command(self, command)
    local formatted_command
    if package.config:sub(1,1) == '\\' then
        formatted_command = string.format('%s >> "%s" 2>>&1', command, self.command_output)
    else
        formatted_command = string.format('%s >> "%s" 2>&1', command, self.command_output)
    end

    self.logger:setup("Executing command: " .. command)
    local result = os.execute(formatted_command)

    if type(result) == "number" then
        return result == 0
    else
        return result
    end
end

function Setup.check_cmake_installed(self)
    self.logger:setup("Cheking if cmake is installed...")
    return self:execute_command("cmake --version")
end

function Setup.install_cmake(self)
    self.logger:setup("Installing CMake...")

    -- Detect OS
    local os_name = ""
    if package.config:sub(1,1) == '\\' then
        os_name = "windows"
    else
        local handle = io.popen("uname")
        if handle then
            os_name = handle:read("*l"):lower()
            handle:close()
        end
    end

    if os_name == "linux" then
        if not self:execute_command("sudo apt-get update && sudo apt-get install -y cmake") then
            return self:execute_command("sudo yum -y install cmake")
        end
    elseif os_name == "darwin" then
        return self:execute_command("brew install cmake")
    elseif os_name == "windows" then
        return self:execute_command("choco install cmake -y")
    end

    return false
end

function Setup.get_data_path(self)
    local sep = package.config:sub(1,1)  -- Gets OS path separator
    if os.getenv("HOME") then  -- Unix-like systems
        return os.getenv("HOME") .. sep .. ".local" .. sep .. "share" .. sep .. "pulpero"
    else  -- Windows
        return os.getenv("APPDATA") .. sep .. "pulpero"
    end
end

function Setup.file_exist(self, path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

function Setup.is_directory(self, path)
    local file = io.open(path)
    if file then
        local ok, err, code = file:read(1)
        file:close()
        return code == 21
    end
    return false
end

function Setup.create_directory(self, path)
    if package.config:sub(1,1) == '\\' then
        os.execute('mkdir "' .. path .. '"')
    else
        os.execute('mkdir -p "' .. path .. '"')
    end
end

function Setup.ensure_dir(self, path)
    self.logger:setup("Cheking if file exist " .. path)
    if self:is_directory(path) then
        self:create_directory(path)
    end
end

function Setup.download_model(self)
    self.logger:setup("Prepearing model")
    local data_dir = self:get_data_path()
    self:ensure_dir(data_dir)

    local model_path = data_dir .. '/model.gguf'
    if self:file_exist(model_path) then
        self.logger:setup("Model already exist skiping download")
        return model_path, 0
    end

    self.logger:setup("Downloading TinyLlama model (this may take a while)...")

    local download_command = string.format(
        'wget -O %s --header="Authorization: Bearer %s" %s',
        model_path,
        self.config.token,
        self.config.model
    )

    if self:execute_command(download_command) then
        self.logger:setup("Download ended")
        return model_path, 0
    else
        self.logger:setup("Failed to download the model")
        return "", 1
    end
end

function Setup.setup_llama(self)
    self.logger:setup("Preparing Llama cpp")

    if not self:check_cmake_installed() then
        self.logger:setup("CMake not found, attempting to install...")
        if not self:install_cmake() then
            self.logger:setup("Failed to install CMake. Please install it manually.")
            return "", 1
        end
        self.logger:setup("CMake installed successfully")
    end

    local data_dir = self:get_data_path()
    local llama_dir = data_dir .. '/llama.cpp'
    local llama_bin = llama_dir .. '/build/bin/llama-cli'

    if not self:file_exist(llama_dir) then
        local clone_command = string.format('git clone %s %s', self.config.llama_repo, llama_dir)
        if not self:execute_command(clone_command) then
            self.logger:setup("Failed to clone llama.cpp")
            return "", 1
        end
    else
        self.logger:setup("Llama is already cloned, skipping")
    end

    if not self:file_exist(llama_bin) then
        -- Create build directory
        local build_dir = llama_dir .. '/build'
        local mkdir_command = package.config:sub(1,1) == '\\' and
            string.format('mkdir "%s"', build_dir) or
            string.format('mkdir -p "%s"', build_dir)

        if not self:execute_command(mkdir_command) then
            self.logger:setup("Failed to create build directory")
            return "", 1
        end

        -- Build with CMake
        local build_commands = string.format(
            'cd "%s" && cmake .. && cmake --build . --config Release',
            build_dir
        )

        if not self:execute_command(build_commands) then
            self.logger:setup("Failed to compile llama.cpp")
            return "", 1
        end

    else
        self.logger:setup("Llama is already compiled, skipping")
    end

    return llama_bin, 0
end

function Setup.prepear_env(self)
    self.logger:setup("Prepearing env")
    local llama_path, llama_setup_result = self:setup_llama()
    local model_path, model_setup_result = self:download_model()

    if llama_setup_result == 0 and model_setup_result == 0 then
        self.config.llama_cpp_path = llama_path
        self.config.model_path = model_path
    else
        error("Failed to initialize Pulpero")
    end
end

function Setup.configure_plugin(self)
    local default_settings = {
        context_window = 512,
        temp = 0.1,
        num_threads = 4,
        top_p = 0.2,
        token="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",
        model = "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
        llama_repo = "https://github.com/ggerganov/llama.cpp.git"
    }

    local success, handle = pcall(io.popen, 'free -m | grep Mem: | awk \'{print $2}\'')
    if success and handle then
        local total_mem = tonumber(handle:read('*a'))
        handle:close()
        if total_mem and total_mem < 4096 then -- Less than 4GB RAM
            default_settings.context_window = 256
            default_settings.num_threads = 2
        elseif total_mem and total_mem < 8192 then -- Less than 8GB RAM
            default_settings.context_window = 512
            default_settings.num_threads = 4
        else -- 8GB or more RAM
            default_settings.context_window = 1024
            default_settings.num_threads = 6
        end
    end

    self.config = default_settings
    return default_settings
end

return Setup
