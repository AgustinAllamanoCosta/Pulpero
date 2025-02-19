local ModelManager = {}
local OSCommands = require('util.OSCommands')

local amount_of_chunks = 19
local default_model = {
    size = 16702518048,
    chunks = amount_of_chunks,
    chunk_size = 880803840,
    chunks_info = {
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-1.tar.gz",
            checksum = "d0d6252996fccb5b62a3ba0fbc61562d3e2e1944f9ac795b3fa63ae4b217db1d"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-2.tar.gz",
            checksum = "97ab32f374850a97e9684e8037269c3c9735163bee18213e59a30dd3d8e289ac"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-3.tar.gz",
            checksum = "57fb74a59e4605743df3bb30e6b50990dafd84e76fe800a7083851f2255740d8"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-4.tar.gz",
            checksum = "4e85d81105560049b059a7da56910fab62da104d8d62b875acb1569c4cf6e0c2"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-5.tar.gz",
            checksum = "e583a99e45a19b6eb46281ce32cedeb9f0fed1e990eecdc3ca7de53b2506f853"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-6.tar.gz",
            checksum = "f6a930387692184faf15f4ef39ff79ce247d3e6532d52a508d7a7cfa088222a3"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-7.tar.gz",
            checksum = "24fa877645aa5993e7d2fb55423e03531c90eded60d0fdf4fcf560bbbcef5153"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-8.tar.gz",
            checksum = "9aa335732d2556cb3dd580299bc0c0b4a9973e81acb8ef9f137baf63c12ee15c"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-9.tar.gz",
            checksum = "82b3284afb2bce6694a8c7c42d730390c2acb6cd6df0f1e6334915c03fd6fb92"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-10.tar.gz",
            checksum = "dc83b84fdd1053987f80cec25340d447f7550c8cb24f373e2fff2cfa9866de55"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-11.tar.gz",
            checksum = "9a33572396e50300c7b8026dfb0c9408c8941d132bbe4c2956276e0f302b5bb9"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-12.tar.gz",
            checksum = "2073861a3e41aba20131eb0fd0a8ca8cc1f2afc3dd7926dfe237c640153b59db"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-13.tar.gz",
            checksum = "3b676e233d99c42ecf0a877dbe5cb520f85adb5f8452901c9adda1dff7de8c06"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-14.tar.gz",
            checksum = "e6338df01c03816ea8b7650fa08566ee8a5867735e473c4de6417abb48a89bd1"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-15.tar.gz",
            checksum = "6326cbbf084970bf77a6ac8006bd3008bb98c106272422301a02c4cd717ea68b"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-16.tar.gz",
            checksum = "013766b03f4c4b425cb4d9014b777b2e2ad9d7a5d057452b741c50e4010af2d0"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-17.tar.gz",
            checksum = "b5411f9c2d0e806e57bd77490062385dad31ed24a5f3e5a9b8ec127bcaec54a3"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-18.tar.gz",
            checksum = "89a39fcc307d7e30dabcec36ceefa984ed29f6cbd0736510a32d81f20bcbe746"
        },
        {
            url = "https://github.com/AgustinAllamanoCosta/Pulpero/releases/download/m0.1.0/deepseek.part-19.tar.gz",
            checksum = "d2fab1cb51d3f4106a083d4a3dc8c09b2b1eb4c43a18f45ea137589e4fc994b5"
        },
    }
}

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
        current_chunk = amount_of_chunks,
        all_chunk_download = false,
        model_assemble = false
    }
    return self
end

function ModelManager.verifyChecksum(self, file_path, expected_checksum)
    local command
    if OSCommands:getPlatform() == 'windows' then
        command = string.format('CertUtil -hashfile "%s" SHA256', file_path)
    else
        command = string.format('sha256sum "%s"', file_path)
    end
    self.logger:debug("Command to execute", { command })
    local handle = io.popen(command)
    if not handle then
        self.logger:error("Can execute the verify command checksum")
    end
    local result = handle:read("*a")
    handle:close()
    self.logger:debug("Raw command result", { result })
    local calculated_checksum = result:match("([a-fA-F0-9]+)")
    self.logger:debug("checksum calculated: ", { calculated_checksum })
    return calculated_checksum == expected_checksum
end

function ModelManager.downloadChunk(self, chunk_info, chunk_number)
    self.logger:debug("Downloading chunk", { chunk = chunk_number })
    local temp_file = OSCommands:createPathByOS(self.config.temp_dir, string.format("model_chunk_%d.tar.gz", chunk_number))
    self.config.current_chunk = chunk_number
    local download_command
    if OSCommands:getPlatform() == 'windows' then
        download_command = string.format(
            'powershell -Command "Invoke-WebRequest -Uri %s -OutFile %s"',
            chunk_info.url,
            temp_file
        )
    else
        download_command = string.format('curl -L "%s" -o "%s"', chunk_info.url, temp_file)
    end
    if not OSCommands:fileExists(temp_file) then
        local success = os.execute(download_command)
        if not success then
            self.logger:error("Failed to download chunk", { chunk = chunk_number })
            return false
        end
    end
    if not self:verifyChecksum(temp_file, chunk_info.checksum) then
        self.logger:error("Checksum verification failed", { chunk = chunk_number })
        os.remove(temp_file)
        return false
    end
    return temp_file
end

function ModelManager.extractChunk(self, chunk_file, chunk_number)
    self.logger:debug("Extracting chunk", { chunk = chunk_number })
    local extract_command
    if OSCommands:getPlatform() == 'windows' then
        extract_command = string.format('tar --transform="s,deepseek.part-*,deepseek.part-%s" -xzf "%s" -C "%s"',
            chunk_number, chunk_file, self.config.temp_dir)
    else
        extract_command = string.format('tar --transform="s,deepseek.part-*,deepseek.part-%s" -xzf "%s" -C "%s"',
            chunk_number, chunk_file, self.config.temp_dir)
    end
    local success = os.execute(extract_command)
    os.remove(chunk_file)
    return success
end

function ModelManager.assembleModel(self)
    self.logger:debug("Assembling model from chunks")
    local model_file = io.open(self.config.model_path, "wb")
    if model_file then
        for i = 1, default_model.chunks do
            local chunk_path = OSCommands:createPathByOS(self.config.temp_dir, string.format("deepseek.part-%d", i))
            local chunk_file = io.open(chunk_path, "rb")
            if not chunk_file then
                self.logger:error("Failed to open chunk file", { chunk = i })
                model_file:close()
                return false
            end
            local chunk_data = chunk_file:read("*a")
            model_file:write(chunk_data)
            chunk_file:close()
            os.remove(chunk_path)
        end
        model_file:close()
    else
        self.logger:error("Can not open the final model file. Path: " .. model_file)
    end
    return true
end

function ModelManager.downloadAndAssembleModel(self)
    self.logger:debug("Starting model download and assembly")
    OSCommands:ensureDir(self.config.model_dir)
    for i, chunk_info in ipairs(default_model.chunks_info) do
        self.logger:debug("Chunk Info", { chunk_info })
        local chunk_file = self:downloadChunk(chunk_info, i)
        if not chunk_file then
            return false
        end
        if not self:extractChunk(chunk_file, i) then
            return false
        end
    end
    self.config.all_chunk_download = true
    return self:assembleModel()
end

function ModelManager.isModelDownloaded(self)
    self.logger:debug("Model path ", { model_path = self.config.model_path })
    local file = io.open(self.config.model_path, "rb")
    if not file then
        return false
    end
    local size = file:seek("end")
    file:close()
    return size == default_model.size
end

return ModelManager
