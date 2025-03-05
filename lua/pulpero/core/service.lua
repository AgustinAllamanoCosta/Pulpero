local json = require('util.JSON')
local ModelManager = require('model_manager')
local Setup = require('setup')
local Runner = require('model_runner')
local Logger = require('logger')
local Parser = require('parser')
local OSCommands = require('util.OSCommands')
local uv = vim.loop or require('luv')
local model_name = "deepseek-coder-v2-lite-instruct.gguf"

local SOCKET_DIR = OSCommands:get_temp_dir() or "/tmp"
local SOCKET_PATH = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.sock")
local PID_FILE = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.pid")

-- Service state
local logger = nil
local setup = nil
local parser = nil
local runner = nil
local config = nil
local logger_config = nil
local model_manager = nil
local current_os = OSCommands:get_platform()
local clients = {}
local server = nil
local enable = true

local default_settings = {
    context_window = 1024,
    temp = "0.1",
    num_threads = "4",
    top_p = "0.4",
    model_name = model_name,
    model_path = OSCommands:create_path_by_OS(OSCommands:get_model_dir(), model_name),
    llama_repo = "https://github.com/ggerganov/llama.cpp.git",
    os = OSCommands:get_platform(),
    pulpero_ready = false,
    response_size = "1024"
}

local function ensure_dependencies(function_name)
    if logger == nil then
        error("Logger can not be nil at service function: " .. function_name)
    end
    if setup == nil then
        error("Setup can not be nil at service function: " .. function_name)
    end
    if model_manager == nil then
        error("Model manager can not be nil at service function: " .. function_name)
    end
end

-- Write PID to file for service discovery
local function write_pid_file()
    ensure_dependencies("write_pid_file")
    local pid = uv.os_getpid()
    local file = io.open(PID_FILE, "w")
    if file then
        file:write(tostring(pid))
        file:close()
        logger:debug("PID file created", { pid = pid, path = PID_FILE })
        return true
    else
        logger:error("Failed to create PID file", { path = PID_FILE })
        return false
    end
end

local function clean_up()
    ensure_dependencies("clean_up")
    if server then
        server:close()
    end
    for _, client in ipairs(clients) do
        if not client.closed then
            client:close()
        end
    end
    os.remove(SOCKET_PATH)
    os.remove(PID_FILE)
    logger:debug("Service shutdown complete")
end

local function service_is_ready()
    ensure_dependencies("service_is_ready")
    if model_manager:getStatusFromFile() == "completed" then
        if enable then
            return true
        else
            logger:debug("The machine spirit is sleeping", { enable = enable })
            return false
        end
    else
        logger:debug("The machine spirit is not ready yet", { status = download_status.state, enable = enable })
        return false
    end
end

local function process_request(request_str)
    ensure_dependencies("process_request")
    logger:debug("Processing request by service", { request = request_str })
    local success_json, request = pcall(json.decode, request_str)
    if not success_json then
        return json.encode({
            requestId = 0,
            error = "Invalid JSON request",
            result = nil
        })
    end
    if not request then
        logger:error("Request process failed - empty request")
        return json.encode({
            requestId = request.id or 0,
            error = "Empty request",
            result = nil
        })
    end
    local response = {
        requestId = request.id,
        result = nil,
        error = nil
    }
    logger:debug("Decoded request", { request = request })
    if request.method == "talk_with_model" then
        if service_is_ready() then
            local success, result, code = runner:talkWithModel(request.params.message)
            response.result = {
                success = success,
                message = result,
                code = code
            }
        else
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "prepear_env" then
        config = setup:prepearEnv()
        runner = Runner.new(config, logger, parser)
        response.result = true
    elseif request.method == "update_current_file_content" then
        if service_is_ready() then
            runner:updateCurrentFileContent(
                request.params.file_data,
                request.params.amount_of_lines
            )
            response.result = true
        else
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "clear_model_cache" then
        if service_is_ready() then
            runner:clearModelCache()
            response.result = true
        else
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "init_pairing_session" then
        if service_is_ready() then
            runner:initPairingSession(request.params.feature_description)
            response.result = true
        else
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "end_pairing_session" then
        if service_is_ready() then
            runner:endPairingSession()
            response.result = true
        else
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "get_download_status" then
        response.result = model_manager:getStatusFromFile()
    elseif request.method == "get_service_status" then
        response.result = {
            running = true,
            model_ready = service_is_ready(),
            download_status = model_manager:getStatusFromFile(),
            pid = uv.os_getpid()
        }
    elseif request.method == "toggle" then
        enable = not enable
        response.result = enable
    else
        response.error = "Unknown method: " .. (request.method or "nil")
    end
    local encoded_response = json.encode(response)
    logger:debug("Request processed", { id = response.requestId, response = encoded_response })
    return encoded_response
end

local function on_client_connect(client)
    ensure_dependencies("on_client_connect")
    logger:debug("New client connected")
    table.insert(clients, client)
    -- Set up reading from client
    client:read_start(function(err, data)
        if err then
            logger:error("Error reading from client", { error = err })
            client:close()
            return
        end
        if data then
            -- Process the request and send response
            local response = process_request(data)
            client:write(response .. "\n")
        else
            -- EOF - client disconnected
            logger:debug("Client disconnected")
            client:close()
            -- Remove from clients table
            for i, c in ipairs(clients) do
                if c == client then
                    table.remove(clients, i)
                    break
                end
            end
        end
    end)
end

local function initialize_service(logger)
    model_manager = ModelManager.new(logger, default_settings)
    parser = Parser.new(logger)
    setup = Setup.new(logger, model_manager, default_settings)
    config = setup:configure_plugin()
    logger:setup("Service starting on OS: " .. current_os)
    logger:setup("Configuration ", config)
    return config
end

-- Setup socket server
local function setup_socket_server()
    ensure_dependencies("setup_socket_server")
    OSCommands:ensure_dir(SOCKET_DIR)
    -- Remove existing socket file if it exists
    if OSCommands:file_exists(SOCKET_PATH) then
        os.remove(SOCKET_PATH)
    end
    server = uv.new_pipe(false)
    local success, err = pcall(function()
        server:bind(SOCKET_PATH)
        server:listen(128, function(err)
            if err then
                logger:error("Socket listen error", { error = err })
                return
            end
            local client = uv.new_pipe(false)
            server:accept(client)
            on_client_connect(client)
        end)
    end)
    if not success then
        logger:error("Failed to set up socket server", { error = err })
        return false
    end
    logger:debug("Socket server listening", { path = SOCKET_PATH })
    return true
end

-- Main function to start the service
local function start_service(param_logger)
    if not param_logger then
        logger = Logger.new()
        logger:clear_logs()
        logger_config = logger:get_config()
        logger:setup("Configuration logger", logger_config)
    else
        logger = param_logger
    end
    initialize_service()
    if setup_socket_server() then
        write_pid_file()
        -- Setup signal handlers for clean shutdown
        for _, sig in ipairs({ 'SIGINT', 'SIGTERM' }) do
            uv.new_signal():start(sig, function()
                logger:debug("Received signal " .. sig .. ", shutting down")
                clean_up()
                os.exit(0)
            end)
        end
        logger:debug("Service started successfully")
        -- Keep the event loop running
        uv.run()
    else
        logger:error("Failed to start service")
        os.exit(1)
    end
end

-- Start the service
start_service()

