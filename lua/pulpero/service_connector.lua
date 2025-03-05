-- service_connector.lua
local ServiceConnector = {}
local json = require('util.JSON')

function ServiceConnector.new()
    local self = setmetatable({}, { __index = ServiceConnector })
    self.pipe = nil
    self.service_process = nil
    self.callbacks = {}
    self.request_id = 0
    return self
end

function ServiceConnector:start_service()
    local stdin = vim.loop.new_pipe(false)
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)

    local service_path = -- path to your service script

    self.service_process = vim.loop.spawn('lua', {
        args = {service_path},
        stdio = {stdin, stdout, stderr}
    }, function(code, signal)
        -- Handle service exit
    end)

    -- Set up data handling
    stdout:read_start(function(err, data)
        if err then
            -- Handle error
        elseif data then
            self:handle_response(data)
        end
    end)

    stderr:read_start(function(err, data)
        if err or data then
            -- Log any errors from the service
        end
    end)

    self.pipe = {stdin = stdin, stdout = stdout, stderr = stderr}
    return true
end

function ServiceConnector:send_request(method, params, callback)
    self.request_id = self.request_id + 1
    local request = {
        id = self.request_id,
        method = method,
        params = params
    }

    self.callbacks[self.request_id] = callback

    local success, encoded = pcall(json.encode, request)
    if success then
        self.pipe.stdin:write(encoded .. "\n")
    else
        -- Handle encoding error
    end
    return self.request_id
end

function ServiceConnector:handle_response(data)
    local success, decoded = pcall(json.decode, data)
    if success and decoded.requestId and self.callbacks[decoded.requestId] then
        self.callbacks[decoded.requestId](decoded.error, decoded.result)
        self.callbacks[decoded.requestId] = nil
    end
end

function ServiceConnector:stop_service()
    if self.service_process then
        self.service_process:kill(15) -- SIGTERM
        self.pipe.stdin:close()
        self.pipe.stdout:close()
        self.pipe.stderr:close()
        self.service_process = nil
        self.pipe = nil
    end
end

return ServiceConnector
