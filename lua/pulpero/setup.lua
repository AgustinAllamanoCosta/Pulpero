local Setup = {}
local Logger = require('pulpero.logger')

function Setup.new ()
    local self = setmetatable({}, { __index = Setup })
    return self
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

    local cmd = string.format(
        'wget -O %s --header="Authorization: Bearer %s" %s 2>>%s',
        model_path,
        self.config.token,
        self.config.model,
        self.command_output
    )

    local result = os.execute(cmd)
    if result ~= 1 then
        self.logger:setup("Failed to download the model " .. result)
        return "", result
    end

    self.logger:setup("Download ended")
    return model_path, 0
end

function Setup.setup_llama(self)
    self.logger:setup("Prepearing Llama cpp")
    local data_dir = self:get_data_path()
    local llama_dir = data_dir .. '/llama.cpp'
    local llama_bin = llama_dir .. '/llama-cli'

    if self:file_exist(llama_dir) then
        self.logger:setup("Llama is already cloned skipping")
    else
        local clone_llama_command = string.format('git clone %s %s 2>>%s', self.config.llama_repo, llama_dir, self.command_output)
        local result = os.execute(clone_llama_command)
        if result ~= 1 then
            self.logger:setup("Failed to download the model " .. result)
            return "", result
        end
    end

    if self:file_exist(llama_bin) then
        self.logger:setup("Llama is already compile skipping")
    else
        local compile_llama_command = string.format('cd %s && make 2>>%s', llama_dir, self.command_output)
        local result = os.execute(compile_llama_command)
        if result ~= 1 then
            self.logger:setup("Failed to compile llama.cpp " .. result)
            return "", result
        end
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
        logs = {
            directory = "/tmp",
            debug_file = "pulpero_debug.log",
            setup_file = "pulpero_setup.log",
            command_output = "pulpero_command.log",
            error_file = "pulpero_error.log"
        },
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
    self.command_output = string.format('%s/%s', self.config.logs.directory, self.config.logs.setup_file)
    self.logger = Logger.new(self.config)
    self.logger:clear_logs()
    return default_settings, self.logger
end

return Setup
