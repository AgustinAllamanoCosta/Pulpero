local OSCommands = require('OSCommands')
local json = require('JSON')
local Logger = require('logger')
local uv = vim.loop

local ServiceConnector = {}

local SOCKET_DIR = OSCommands:get_temp_dir()
local SOCKET_PATH = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.sock")
local PID_FILE = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.pid")
local SERVICE_SCRIPT = OSCommands:create_path_by_OS(OSCommands:get_core_path(), 'service.lua')
local service_started = false

function ServiceConnector.new()
    local self = setmetatable({}, { __index = ServiceConnector })
    self.pipe = nil
    self.connected = false
    self.callbacks = {}
    self.request_id = 0
    self.pending_data = ""
    self.reconnect_attempts = 0
    self.max_reconnect_attempts = 5
    self.logger = Logger.new("service_connector")
    self.logger:debug("Script path ", { path = SERVICE_SCRIPT })
    return self
end

function ServiceConnector:is_service_running()
    if not OSCommands:file_exists(PID_FILE) then
        self.logger:debug("Service is not running, PID file does not exists")
        return false
    end

    self.logger:debug("Checking if the service is running")
    local file = io.open(PID_FILE, "r")
    if not file then
        self.logger:debug("Service is not running, PID file does not exists")
        return false
    end
    local pid_str = file:read("*a")
    file:close()
    local pid = tonumber(pid_str)
    if not pid then
        self.logger:debug("Service is not running, cannot read the PID from the file")
        return false
    end

    if OSCommands:is_windows() then
        self.logger:debug("Looking for the processes on Windows")
        local result = os.execute('tasklist /FI "PID eq ' .. pid .. '" 2>NUL | find "' .. pid .. '"')
        return result == 0
    else
        self.logger:debug("Looking for the processes on Darwing or Linux")
        local result = os.execute('kill -0 ' .. pid .. ' 2>/dev/null')
        return result == 0
    end
end

function ServiceConnector:start_service()
    self.logger:debug("Starting Pulpero service")

    if not OSCommands:file_exists(SERVICE_SCRIPT) then
        self.logger:error("Service script not found", { path = SERVICE_SCRIPT })
        return false
    end
    local handle, pid
    local args = { SERVICE_SCRIPT }
    if OSCommands:is_windows() then
        self.logger:debug("Is windows, starting service", { args })
        handle, pid = uv.spawn('lua', {
            args = args,
            detached = true,
            hide = true
        })
    else
        self.logger:debug("Is Linux or Darwing, starting service", { args })
        handle, pid = uv.spawn('lua', {
            args = args,
            detached = true
        })
    end
    if not handle then
        self.logger:error("Failed to start service process", { pid = pid })
        return false
    end
    handle:unref()
    uv.sleep(1000)
    self.logger:debug("Service started", { pid = pid })
    return true
end

function ServiceConnector:process_data(data)
    if data then
        self.pending_data = self.pending_data .. data
        while true do
            local end_pos = self.pending_data:find("\n")
            if not end_pos then break end
            local message = self.pending_data:sub(1, end_pos - 1)
            self.pending_data = self.pending_data:sub(end_pos + 1)
            self:handle_response(message)
        end
    end
end

function ServiceConnector:connect()
    if self.connected then
        return true
    end
    self.logger:debug("Plugin is not connected to the service", { SOCKET_PATH })

    if not OSCommands:file_exists(SOCKET_PATH) then
        self.logger:debug("Socket file not found")
        service_started = self:is_service_running()
        if not service_started then
            self.logger:debug("Service is not running starting a new one")
            service_started = self:start_service()
            if not service_started then
                return false
            end
            self.logger:debug("Waiting for the service to complete")
            uv.sleep(1000)
            if not OSCommands:file_exists(SOCKET_PATH) then
                self.logger:error("Socket file still not found after starting service")
                return false
            end
        else
            self.logger:error("Service appears to be running but socket file not found")
            return false
        end
    end

    self.logger:debug("Socket file found, trying to connect...", { path = SOCKET_PATH })
    self.pipe = uv.new_pipe(false)
    local success, err = pcall(function()
        self.pipe:connect(SOCKET_PATH)
    end)
    if not success then
        self.logger:error("Failed to connect to service socket", { error = err })
        self.pipe:close()
        self.pipe = nil
        return false
    end
    self.pipe:read_start(function(err, data)
        if err then
            self.logger:error("Error reading from service", { error = err })
            self:handle_disconnect()
            return
        end
        if data then
            self:process_data(data)
        else
            self:handle_disconnect()
        end
    end)
    self.connected = true
    self.reconnect_attempts = 0
    self.logger:debug("Connected to service socket")
    self:send_request("prepear_env", {}, nil)
    return true
end

function ServiceConnector:handle_disconnect()
    self.logger:debug("Disconnected from service")
    if self.pipe then
        self.pipe:close()
        self.pipe = nil
    end
    self.connected = false
    if self.reconnect_attempts < self.max_reconnect_attempts then
        self.reconnect_attempts = self.reconnect_attempts + 1
        local delay = math.min(100 * (2 ^ self.reconnect_attempts), 5000) -- Exponential backoff with max 5s
        self.logger:debug("Attempting reconnection", {
            attempt = self.reconnect_attempts,
            delay = delay
        })
        vim.defer_fn(function()
            if not self.connected then
                self:connect()
            end
        end, delay)
    else
        self.logger:error("Maximum reconnection attempts reached")
    end
end

function ServiceConnector:handle_response(data)
    local success, decoded = pcall(json.decode, data)
    if not success then
        self.logger:error("Failed to decode response", { data = data })
        return
    end
    if not decoded.requestId or not self.callbacks[decoded.requestId] then
        self.logger:debug("Received response with no matching callback", { requestId = decoded.requestId })
        return
    end
    self.logger:debug("Response from service to requestId ", decoded)
    self.callbacks[decoded.requestId](decoded.error, decoded.result)
    self.callbacks[decoded.requestId] = nil
end

function ServiceConnector:send_request(method, params, callback)
    if not self.connected then
        if not self:connect() then
            if callback then
                callback("Not connected to service", nil)
            end
            return nil
        end
    end
    self.request_id = self.request_id + 1
    local request = {
        id = self.request_id,
        method = method,
        params = params
    }
    if callback then
        self.callbacks[self.request_id] = callback
    end
    local success, encoded = pcall(json.encode, request)
    if not success then
        self.logger:error("Failed to encode request", { error = encoded })
        if callback then
            callback("Failed to encode request: " .. tostring(encoded), nil)
            self.callbacks[self.request_id] = nil
        end
        return nil
    end
    self.pipe:write(encoded .. "\n")
    return self.request_id
end

function ServiceConnector:talk_with_model(message, file_context_data, callback)
    return self:send_request("talk_with_model", { message = message, file_context_data = file_context_data }, callback)
end

function ServiceConnector:update_current_file_content(file_data, amount_of_lines, callback)
    return self:send_request("update_current_file_content", {
        file_data = file_data,
        amount_of_lines = amount_of_lines
    }, callback)
end

function ServiceConnector:clear_model_cache(callback)
    return self:send_request("clear_model_cache", {}, callback)
end

function ServiceConnector:init_pairing_session(feature_description, callback)
    return self:send_request("init_pairing_session", {
        feature_description = feature_description
    }, callback)
end

function ServiceConnector:end_pairing_session(callback)
    return self:send_request("end_pairing_session", {}, callback)
end

function ServiceConnector:get_download_status(callback)
    return self:send_request("get_download_status", {}, callback)
end

function ServiceConnector:get_service_status(callback)
    return self:send_request("get_service_status", {}, callback)
end

function ServiceConnector:toggle_service(callback)
    return self:send_request("toggle", {}, callback)
end

function ServiceConnector:disconnect()
    if self.pipe then
        self.pipe:close()
        self.pipe = nil
    end
    self.connected = false
    self.callbacks = {}
    self.logger:debug("Disconnected from service")
end

return ServiceConnector
