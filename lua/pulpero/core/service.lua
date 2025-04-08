local function add_pulpero_to_path()
    local current_file = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = current_file:match("(.*/)"):sub(1, -2):match("(.*/)"):sub(1, -2)

    local paths = {
        plugin_root .. "/?.lua",
        plugin_root .. "/?/init.lua",
        plugin_root .. "/core/?.lua",
        plugin_root .. "/core/tool/?.lua",
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

local json = require('JSON')
local ModelManager = require('model_manager')
local Setup = require('setup')
local Runner = require('model_runner')
local ToolManager = require('tool.manager')
local Logger = require('logger')
local Parser = require('parser')
local OSCommands = require('util.OSCommands')
local uv = require('luv')
local model_name = "deepseek-coder-v2-lite-instruct.gguf"

local SOCKET_DIR = OSCommands:get_temp_dir()
local SOCKET_PATH = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.sock")
local PID_FILE = OSCommands:create_path_by_OS(SOCKET_DIR, "pulpero.pid")

-- Service state
local logger = nil
local setup = nil
local parser = nil
local runner = nil
local config = nil
local tool_manager = nil
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
    logger:debug("All dependencies are ready in " .. function_name)
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
    logger:debug("checking if the service is ready")
    local status = model_manager:get_status_from_file()
    logger:debug("Model status ", { status })
    if status == "completed" then
        logger:debug("Service download status is completed")
        if enable then
            logger:debug("Service is enable")
            return true
        else
            logger:debug("The machine spirit is sleeping", { enable = enable })
            return false
        end
    else
        logger:debug("The machine spirit is not ready yet")
        return false
    end
end

local function process_request(request_str)
    ensure_dependencies("process_request")
    logger:debug("Processing request by service", { request = request_str })
    local success_json, request = pcall(json.decode, request_str)
    if not success_json then
        logger:error("Error decoding JSON")
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

    logger:debug("Decoded request", { request })
    if request.method == "talk_with_model" then
        if service_is_ready() then
            local success, result, code = runner:talk_with_model(request.params.message)
            response.result = {
                success = success,
                message = result,
                code = code
            }
        else
            logger:debug("service is not ready yet to talk with the model")
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "prepear_env" then
        local success, result = pcall(setup.prepear_env, setup)
        if success then
            runner = Runner.new(result, logger, parser, tool_manager)
            response.result = true
        else
            response.error = result
            response.result = false
        end
    elseif request.method == "update_current_file_content" then
        if service_is_ready() then
            logger:debug("Updating the current file to the service")
            local success, result = pcall(runner.update_current_file_content, runner, request.params.file_data,
                request.params.amount_of_lines)
            response.result = success
            response.error = result
        else
            logger:debug("service is not ready yet to update the current file")
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "clear_model_cache" then
        if service_is_ready() then
            local success, result = pcall(runner.clear_model_cache, runner)
            response.result = success
            response.error = result
        else
            logger:debug("service is not ready yet to clear the cache")
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "init_pairing_session" then
        if service_is_ready() then
            local success, result = pcall(runner.init_pairing_session, runner, request.params.feature_description)
            response.result = success
            response.error = result
        else
            logger:debug("service is not ready yet to init a pairing session")
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "end_pairing_session" then
        if service_is_ready() then
            local success, result = pcall(runner.end_pairing_session, runner)
            response.result = success
            response.error = result
        else
            logger:debug("service is not ready yet to end the pairing session")
            response.error = "Service not ready - model still loading"
        end
    elseif request.method == "get_download_status" then
        local success, result = pcall(model_manager.get_status_from_file, model_manager)
        response.result = success
        response.error = result
    elseif request.method == "get_service_status" then
        local success, result = pcall(model_manager.get_status_from_file, model_manager)
        response.result = {
            running = true,
            model_ready = service_is_ready(),
            download_status = result,
            pid = uv.os_getpid()
        }
    elseif request.method == "toggle" then
        enable = not enable
        response.result = enable
    else
        response.error = "Unknown method: " .. (request.method or "nil")
    end

    logger:debug("Response generated", { response })
    local encoded_response = json.encode(response)
    logger:debug("Request processed", { id = response.requestId, response = encoded_response })
    return encoded_response
end

local function on_client_connect(client)
    ensure_dependencies("on_client_connect")
    logger:debug("New client connected")
    table.insert(clients, client)
    client:read_start(function(err, data)
        if err then
            logger:error("Error reading from client", { error = err })
            client:close()
            return
        end
        if data then
            for line in data:gmatch("[^\n]+") do
                local response = process_request(line)
                client:write(response .. "\n")
            end
        else
            logger:debug("Client disconnected")
            client:close()
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
    logger:debug("Initialize service dependencies")
    model_manager = ModelManager.new(logger, default_settings)
    logger:debug("Init Parser")
    parser = Parser.new(logger)
    logger:debug("Init Setup")
    setup = Setup.new(logger, model_manager, default_settings)
    logger:debug("Configuration plugin")
    config = setup:configure_plugin()
    logger:setup("Service starting on OS: " .. current_os)
    logger:setup("Configuration ", config)
    logger:debug("Finish service initialization")
    tool_manager = ToolManager.new(logger)
    return config
end

local function setup_socket_server()
    ensure_dependencies("setup_socket_server")
    OSCommands:ensure_dir(SOCKET_DIR)
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

local function start_service(param_logger)
    if not param_logger then
        logger = Logger.new("service", true)
        logger:clear_logs()
        logger_config = logger:get_config()
        logger:setup("Configuration logger", logger_config)
    else
        logger = param_logger
    end

    initialize_service(logger)
    if setup_socket_server() then
        logger:setup("Socket Server is ready writing in pide in file")
        write_pid_file()
        logger:setup("Create signal handlers")
        uv.new_signal():start("sigint", function()
            logger:debug("Received signal sigint, shutting down")
            clean_up()
            os.exit(0)
        end)
        uv.new_signal():start("sigterm", function()
            logger:debug("Received signal sigterm, shutting down")
            clean_up()
            os.exit(0)
        end)
        logger:debug("Service started successfully")
        uv.run()
    else
        logger:error("Failed to start service")
        os.exit(1)
    end
end

start_service()
