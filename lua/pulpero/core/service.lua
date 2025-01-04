local Runner = require('./model_runner')
local json = require('./json')
local Parser = require('./parser')
local Logger = require('./logger')
local Setup = require('./setup')

local logger = Logger.new()
local setup = Setup.new(logger)
local config = setup:configurePlugin()
local parser = Parser.new(config)
local runner = Runner.new(config, logger, parser)

local function process_request(request_str)
    logger:debug("Processing request by service in core ", { request = request_str })
    local success, request = pcall(json.decode, request_str)
    if not success then
        return json.encode({
            error = "Invalid JSON request"
        })
    end

    local response = {
        requestId = request.id
    }
    logger:debug("Decoded request", { request = request})

    if request.method == "explain_function" then
        local success, result = runner:explain_function(
            request.params.language,
            request.params.code
        )
        if success then
            response.result = result
        else
            response.error = result
        end
    else
        response.error = "Unknown method"
    end

    local encodeResponse = json.encode(response)
    logger:debug("Request processed ", { id = response.requestId, encodedResponse = encodeResponse })
    return encodeResponse
end

setup:prepearEnv()

while true do
    local line = io.read()
    if not line then break end
    local response = process_request(line)
    if response then
        io.stdout:write(response .. '\n')
        io.stdout:flush()
    end
end
