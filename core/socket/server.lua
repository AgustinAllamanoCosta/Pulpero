local Server = {}
local OSCommands = require('util.OSCommands')
local json = require('JSON')
local uv = require('luv')

function Server.new(logger, model_manager, methods)
    local self = setmetatable({}, { __index = Server })
    self.logger = logger
    self.enable = true
    self.model_manager = model_manager
    self.runner = nil
    self.methods = methods
    self.clients = {}
    self.server = nil
    self.socket_dir = OSCommands:get_temp_dir()
    self.socket_path = OSCommands:create_path_by_OS(self.socket_dir, "pulpero.sock")
    self.pid_file = OSCommands:create_path_by_OS(self.socket_dir, "pulpero.pid")
    return self
end

function Server.process_request(self, request_str)
    self.logger:debug("Processing request by service", { request = request_str })
    local success_json, request = pcall(json.decode, request_str)
    if not success_json then
        self.logger:error("Error decoding JSON")
        return json.encode({
            requestId = 0,
            error = "Invalid JSON request",
            result = nil
        })
    end
    if not request then
        self.logger:error("Request process failed - empty request")
        return json.encode({
            requestId = request.id or 0,
            error = "Empty request",
            result = nil
        })
    end
    self.logger:debug("Decoded request", { request })

    local response = self.methods:adapter(request)

    local encoded_response = json.encode(response)
    self.logger:debug("Request processed", { id = response.requestId, response = encoded_response })
    return encoded_response
end

function Server.on_client_connect(self, client)
    self.logger:debug("New client connected")
    table.insert(self.clients, client)
    client:read_start(function(err, data)
        if err then
            self.logger:error("Error reading from client", { error = err })
            client:close()
            return
        end
        if data then
            for line in data:gmatch("[^\n]+") do
                local response = self:process_request(line)
                client:write(response .. "\n")
            end
        else
            self.logger:debug("Client disconnected")
            client:close()
            for i, c in ipairs(self.clients) do
                if c == client then
                    table.remove(self.clients, i)
                    break
                end
            end
        end
    end)
end

function Server.setup_socket_server(self)
    OSCommands:ensure_dir(self.socket_dir)
    if OSCommands:file_exists(self.socket_path) then
        os.remove(self.socket_path)
    end

    self.server = uv.new_pipe(false)
    local success, err = pcall(function()
        self.server:bind(self.socket_path)
        self.server:listen(128, function(err)
            if err then
                self.logger:error("Socket listen error", { error = err })
                return
            end
            local client = uv.new_pipe(false)
            self.server:accept(client)
            self:on_client_connect(client)
        end)
    end)
    if not success then
        self.logger:error("Failed to set up socket server", { error = err })
        return false
    end
    self.logger:debug("Socket server listening", { path = self.socket_path })
    return true
end

function Server.clean_up(self)
    if self.server then
        self.server:close()
    end
    for _, client in ipairs(self.clients) do
        if not client.closed then
            client:close()
        end
    end
    os.remove(self.socket_path)
    os.remove(self.pid_file)
    self.logger:debug("Service shutdown complete")
end

function Server.write_pid_file(self)
    local pid = uv.os_getpid()
    local file = io.open(self.pid_file, "w")
    if file then
        file:write(tostring(pid))
        file:close()
        self.logger:debug("PID file created", { pid = pid, path = self.pid_file })
        return true
    else
        self.logger:error("Failed to create PID file", { path = self.pid_file })
        return false
    end
end

function Server.start(self)
    if self:setup_socket_server() then
        self.logger:setup("Socket Server is ready writing in pide in file")
        self:write_pid_file()
        self.logger:setup("Create signal handlers")
        uv.new_signal():start("sigint", function()
            self.logger:debug("Received signal sigint, shutting down")
            self:clean_up()
            os.exit(0)
        end)
        uv.new_signal():start("sigterm", function()
            self.logger:debug("Received signal sigterm, shutting down")
            self:clean_up()
            os.exit(0)
        end)
        self.logger:debug("Service started successfully")
        uv.run()
    else
        self.logger:error("Failed to start service")
        os.exit(1)
    end
end

return Server
