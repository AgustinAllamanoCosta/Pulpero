local json             = require('util.JSON')
local ModelManager     = require('core.model_manager')
local Setup            = require('setup')
local Runner           = require('model_runner')
local Logger           = require('logger')
local Parser           = require('parser')
local OSCommands       = require('core.util.OSCommands')
local model_name       = "deepseek-coder-v2-lite-instruct.gguf"

local logger           = nil
local setup            = nil
local parser           = nil
local runner           = nil
local config           = nil
local logger_config    = nil
local model_manager    = nil
local current_os       = OSCommands:getPlatform()
local enable           = true

local default_settings = {
    context_window = 1024,
    temp = "0.1",
    num_threads = "4",
    top_p = "0.4",
    model_name = model_name,
    model_path = OSCommands:createPathByOS(OSCommands:getModelDir(), model_name),
    llama_repo = "https://github.com/ggerganov/llama.cpp.git",
    os = OSCommands:getPlatform(),
    pulpero_ready = false,
    response_size = "1024"
}

function Config_service()
    logger = Logger.new()
    logger:clearLogs()
    logger_config = logger:getConfig()
    model_manager = ModelManager.new(logger, default_settings)
    setup = Setup.new(logger, model_manager, default_settings)
    config = setup:configurePlugin()
    logger:setup("Current OS " .. current_os)
    logger:setup("Configuration ", config)
    logger:setup("Configuration logger", logger_config)
    setup:prepearEnv()
    parser = Parser.new(config, logger)
    runner = Runner.new(config, logger, parser)
    return config
end

local function service_is_ready()
    if model_manager == nil then
        error("ModelManager con not be nil in service")
    end
    if logger == nil then
        error("Logger can not be nil in service")
    end

    local status = model_manager:getStatusFromFile()
    if status == "completed" then
        if enable then
            return true
        else
            logger:debug("The machine spirit is sleeping", { status = status, enable = enable })
            return false
        end
    else
        logger:debug("The machine spirit is not ready yet, ", { status = status, enable = enable })
        return false
    end
end

function Run_service()
    while true do
        local line = io.read()
        if not line then break end
        local response = Process_request(line)
        if response then
            io.stdout:write(response .. '\n')
            io.stdout:flush()
        end
    end
end

function Process_request(request_str)
    if logger == nil then
        error("Logger can not be nil in service")
    end
    if runner == nil then
        error("Runner can not be nil in service")
    end

    logger:debug("Processing request by service in core ", { request = request_str })
    local success_json, request = pcall(json.decode, request_str)
    if not success_json then
        return json.encode({
            error = "Invalid JSON request"
        })
    end
    if not request then
        error("Request process fail")
    end

    local response = {
        requestId = request.id,
        result = nil,
        error = nil
    }
    local runner_response = { success = nil, result = nil }
    logger:debug("Decoded request", { request = request })

    if request.method == "explain_function" then
        if service_is_ready() then
            runner_response = runner:explain_function(
                request.params.language,
                request.params.code
            )
        end
    elseif request.method == "talk_with_model" then
        if service_is_ready() then
            runner_response = runner:talkWithModel(
                request.message
            )
        end
    elseif request.method == "update_current_file_content" then
        if service_is_ready then
            runner_response = runner:updateCurrentFileContent(
                request.file_data,
                request.amount_of_lines
            )
        end
    elseif request.method == "clear_model_cache" then
        if service_is_ready() then
            runner_response = runner:clearModelCache()
        end
    elseif request.method == "toggle" then
        enable = not enable
    else
        response.error = "Unknown method"
    end

    if runner_response and runner_response.success then
        response.result = runner_response.result
    else
        response.error = runner_response.result
    end

    local encodeResponse = json.encode(response)
    logger:debug("Request processed ", { id = response.requestId, encodedResponse = encodeResponse })
    return encodeResponse
end
