local json = require('util.JSON')
local OSCommands = require('util.OSCommands')
local Logger = require('logger')
local uv = vim.loop

local ServiceConnector = {}

local SOCKET_DIR = OSCommands:get_temp_dir() or "/tmp"
local SOCKET_PATH = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.sock")
local PID_FILE = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.pid")
local SERVICE_SCRIPT = OSCommands:create_path_by_OS(vim.fn.stdpath('data'), 'pulpero/socket_service.lua')

function ServiceConnector.new()
    local self = setmetatable({}, { __index = ServiceConnector })
    self.pipe = nil
    self.connected = false
    self.callbacks = {}
    self.request_id = 0
    self.pending_data = ""
    self.reconnect_attempts = 0
    self.max_reconnect_attempts = 5
    self.logger = Logger.new()
    return self
end

-- Check if the service is already running by checking PID file
function ServiceConnector:is_service_running()
    if not OSCommands:file_exists(PID_FILE) then
        return false
    end
    -- Read PID from file
    local file = io.open(PID_FILE, "r")
    if not file then
        return false
    end
    local pid_str = file:read("*a")
    file:close()
    local pid = tonumber(pid_str)
    if not pid then
        return false
    end
    -- Check if process is running (platform specific)
    if OSCommands:is_windows() then
        -- Windows
        local result = os.execute('tasklist /FI "PID eq ' .. pid .. '" 2>NUL | find "' .. pid .. '"')
        return result == 0
    else
        -- Unix-like
        local result = os.execute('kill -0 ' .. pid .. ' 2>/dev/null')
        return result == 0
    end
end

-- Start the service as a detached process
function ServiceConnector:start_service()
    self.logger:debug("Starting Pulpero service")
    -- Ensure service script exists
    if not OSCommands:file_exists(SERVICE_SCRIPT) then
        self.logger:error("Service script not found", { path = SERVICE_SCRIPT })
        return false
    end
    local handle, pid
    local args = { SERVICE_SCRIPT }
    if OSCommands:is_windows() then
        handle, pid = uv.spawn('lua', {
            args = args,
            detached = true,
            hide = true
        })
    else
        handle, pid = uv.spawn('lua', {
            args = args,
            detached = true
        })
    end
    if not handle then
        self.logger:error("Failed to start service process", { pid = pid })
        return false
    end
    -- Unref the process so it can run independently
    handle:unref()
    -- Wait a moment for the service to initialize
    uv.sleep(1000)
    self.logger:debug("Service started", { pid = pid })
    return true
end

-- Process incoming data and extract complete JSON messages
function ServiceConnector:process_data(data)
    if data then
        self.pending_data = self.pending_data .. data
        -- Process all complete messages
        while true do
            local end_pos = self.pending_data:find("\n")
            if not end_pos then break end
            local message = self.pending_data:sub(1, end_pos - 1)
            self.pending_data = self.pending_data:sub(end_pos + 1)
            self:handle_response(message)
        end
    end
end

-- Connect to the service socket
function ServiceConnector:connect()
    if self.connected then
        return true
    end
    -- Check if socket file exists
    if not OSCommands:file_exists(SOCKET_PATH) then
        self.logger:debug("Socket file not found", { path = SOCKET_PATH })
        -- Try to start the service if it's not running
        if not self:is_service_running() then
            if not self:start_service() then
                self.logger:error("Failed to start service")
                return false
            end
            -- Wait a bit for the service to create the socket
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

    -- Create a new pipe
    self.pipe = uv.new_pipe(false)
    -- Connect to the socket
    local success, err = pcall(function()
        self.pipe:connect(SOCKET_PATH)
    end)
    if not success then
        self.logger:error("Failed to connect to service socket", { error = err })
        self.pipe:close()
        self.pipe = nil
        return false
    end
    -- Set up data handling
    self.pipe:read_start(function(err, data)
        if err then
            self.logger:error("Error reading from service", { error = err })
            self:handle_disconnect()
            return
        end
        if data then
            self:process_data(data)
        else
            -- EOF - socket closed
            self:handle_disconnect()
        end
    end)
    self.connected = true
    self.reconnect_attempts = 0
    self.logger:debug("Connected to service socket")
    self:send_request("prepear_env", {}, nil)
    return true
end

-- Handle disconnection and attempt reconnection
function ServiceConnector:handle_disconnect()
    self.logger:debug("Disconnected from service")
    if self.pipe then
        self.pipe:close()
        self.pipe = nil
    end
    self.connected = false
    -- Attempt reconnection with backoff
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

-- Process a response from the service
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
    -- Call the callback with error and result
    self.callbacks[decoded.requestId](decoded.error, decoded.result)
    -- Clean up
    self.callbacks[decoded.requestId] = nil
end

-- Send a request to the service
function ServiceConnector:send_request(method, params, callback)
    -- Make sure we're connected
    if not self.connected then
        if not self:connect() then
            if callback then
                callback("Not connected to service", nil)
            end
            return nil
        end
    end
    -- Create a new request ID
    self.request_id = self.request_id + 1
    local request = {
        id = self.request_id,
        method = method,
        params = params
    }
    -- Store the callback
    if callback then
        self.callbacks[self.request_id] = callback
    end
    -- Encode and send the request
    local success, encoded = pcall(json.encode, request)
    if not success then
        self.logger:error("Failed to encode request", { error = encoded })
        if callback then
            callback("Failed to encode request: " .. tostring(encoded), nil)
            self.callbacks[self.request_id] = nil
        end
        return nil
    end
    -- Write to the pipe
    self.pipe:write(encoded .. "\n")
    return self.request_id
end

-- Wrapper methods for common service operations
function ServiceConnector:talk_with_model(message, callback)
    return self:send_request("talk_with_model", { message = message }, callback)
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

-- Close the connection
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

