local function add_pulpero_to_path()
    local current_file = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = current_file:match("(.*/)"):sub(1, -2):match("(.*/)"):sub(1, -2)

    local paths = {
        plugin_root .. "/?.lua",
        plugin_root .. "/?/init.lua",
        plugin_root .. "/core/?.lua",
        plugin_root .. "/core/util/?.lua"
    }

    for _, path in ipairs(paths) do
        if not package.path:match(path:gsub("[%.%/]", "%%%1")) then
            package.path = path .. ";" .. package.path
        end
    end

    return plugin_root
end

add_pulpero_to_path()

local json = require('core.util.JSON')
local uv = require('luv')

local SOCKET_PATH = "/tmp/pulpero.sock"
local client = uv.new_pipe(false)

local success, err = pcall(function()
    client:connect(SOCKET_PATH)
end)

if not success then
    print("Failed to connect: " .. tostring(err))
    os.exit(1)
end

print("Connected to service")

local function send_request(method, params)
    local request = {
        id = os.time(), -- simple unique ID
        method = method,
        params = params
    }
    local encoded = json.encode(request)
    client:write(encoded .. "\n")
    print("Sent request: " .. encoded)
end

client:read_start(function(err, data)
    if err then
        print("Error reading from service: " .. tostring(err))
        return
    end
    if data then
        print("Received response: " .. data)
        local success, decoded = pcall(json.decode, data)
        if success then
            print("Decoded response:")
            print("  Request ID: " .. tostring(decoded.requestId))
            print("  Error: " .. tostring(decoded.error))
            if decoded.result then
                print("  Result: " .. tostring(decoded.result))
            end
        else
            print("Failed to decode response")
        end
    end
end)

send_request("prepear_env", {})
send_request("get_service_status", {})
uv.run()
