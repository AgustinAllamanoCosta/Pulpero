local ModelManager = {}
local OSCommands = require('util.OSCommands')
local json = require('JSON')
local chunks_info = {
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
    }
}

local status = {
    current_chunk = 0,
    total_chunks = #chunks_info,
    state = "downloading",
    error = "",
    downloaded_chunks = {},
    extracted_chunks = {}
}

function ModelManager.new(logger, default_config)
    local self = setmetatable({}, { __index = ModelManager })
    if logger == nil then
        error("ModelManager logger can not be nil")
    end
    self.logger = logger
    self.config = {
        temp_dir = OSCommands:get_temp_dir(),
        model_dir = OSCommands:get_model_dir(),
        model_path = default_config.model_path,
        all_chunk_download = false,
        status_file = OSCommands:create_path_by_OS(OSCommands:get_temp_dir(), "pulpero_download_status.txt"),
        model_assemble = false
    }
    if not OSCommands:file_exists(self.config.status_file) then
        self:write_status(self.config.status_file, status)
    end
    return self
end

function ModelManager.write_status(self, status_file, status)
    local f = io.open(status_file, "w")
    if f then
        f:write(json.encode(status))
        f:close()
    end
end

function ModelManager.get_status_from_file(self)
    local lines = {}
    self.logger:debug("Status file path ", { path = self.config.status_file })
    for line in io.lines(self.config.status_file) do
        lines[#lines + 1] = line
    end
    local success_json, status_json = pcall(json.decode, lines[1])
    if not success_json then
        self.logger:debug("Error decoding file ")
        self.logger:debug("Raw file " .. lines[1])
    end
    self.logger:debug("Status file ", status_json)
    return status_json.state
end

function ModelManager.download_chunk(self, chunk_url, output_file)
    local download_cmd
    if OSCommands:is_windows() then
        download_cmd = string.format('powershell -Command "Invoke-WebRequest -Uri %s -OutFile %s"', chunk_url,
            output_file)
    else
        download_cmd = string.format('curl -L "%s" -o "%s"', chunk_url, output_file)
    end
    return os.execute(download_cmd)
end

function ModelManager.verify_checksum(self, file_path, expected_checksum)
    local cmd
    if OSCommands:is_windows() then
        cmd = string.format('CertUtil -hashfile "%s" SHA256', file_path)
    else
        cmd = string.format('sha256sum "%s"', file_path)
    end
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    local calculated_checksum = result:match("([a-fA-F0-9]+)")
    return calculated_checksum == expected_checksum
end

function ModelManager.extract_chunk(self, chunk_file, chunk_number, temp_dir)
    local extract_cmd = string.format(
        'tar --transform="s,deepseek.part-*,deepseek.part-%s" -xzf "%s" -C "%s"',
        chunk_number,
        chunk_file,
        temp_dir
    )
    return os.execute(extract_cmd)
end

function ModelManager.assemble_model(self, temp_dir, model_path, num_chunks)
    local model_file = io.open(model_path, "wb")
    if not model_file then return false end
    for i = 1, num_chunks do
        local chunk_path = OSCommands:create_path_by_OS(temp_dir, string.format("deepseek.part-%d", i))
        local chunk_file = io.open(chunk_path, "rb")
        if chunk_file then
            local chunk_data = chunk_file:read("*a")
            model_file:write(chunk_data)
            chunk_file:close()
            os.remove(chunk_path)
        else
            model_file:close()
            return false
        end
    end
    model_file:close()
    return true
end

function ModelManager.check_if_model_exist(self)
    self.logger:debug("Checking if file exist ", { path = self.config.model_path })
    local file = OSCommands:file_exists(self.config.model_path)
    if file and status.state ~= "completed" then
        status.state = "completed"
        self:write_status(self.config.status_file, status)
    end
    self.logger:debug("Result ", { result = file })
    return file
end

function ModelManager.download_and_assemble_model(self)
    self.logger:debug("Starting background model download")

    for i, chunk_info in ipairs(chunks_info) do
        status.current_chunk = i
        status.state = "downloading"
        self:write_status(self.config.status_file, status)
        local temp_file = OSCommands:create_path_by_OS(self.config.temp_dir, string.format("model_chunk_%d.tar.gz", i))
        if self:download_chunk(chunk_info.url, temp_file) then
            -- Verify checksum
            if self:verify_checksum(temp_file, chunk_info.checksum) then
                table.insert(status.downloaded_chunks, i)
                self:write_status(self.config.status_file, status)
                status.state = "extracting"
                self:write_status(self.config.status_file, status)
                if self:extract_chunk(temp_file, i, self.config.temp_dir) then
                    table.insert(status.extracted_chunks, i)
                    os.remove(temp_file)
                else
                    status.state = "error"
                    status.error = string.format("Failed to extract chunk %d", i)
                    self:write_status(self.config.status_file, status)
                    os.exit(1)
                end
            else
                status.state = "error"
                status.error = string.format("Checksum verification failed for chunk %d", i)
                self:write_status(self.config.status_file, status)
                os.remove(temp_file)
                os.exit(1)
            end
        else
            status.state = "error"
            status.error = string.format("Failed to download chunk %d", i)
            self:write_status(self.config.status_file, status)
            os.exit(1)
        end
    end

    -- Assemble final model
    status.state = "assembling"
    self:write_status(self.config.status_file, status)

    if self:assemble_model(self.config.temp_dir, self.model_path, status.total_chunks) then
        status.state = "completed"
    else
        status.state = "error"
        status.error = "Failed to assemble model"
    end

    self:write_status(self.config.status_file, status)
end

return ModelManager
