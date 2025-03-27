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
local Runner = require('model_runner')
local Setup = require('setup')
local Logger = require('logger')
local Parser = require('parser')
local app = require('milua')

local runner = nil
local parser = nil
local logger = nil
local setup = nil
local config = {}

local function start()
    logger = Logger.new("init_plugin")
    logger:clear_logs()
    setup = Setup.new(logger)
    config = setup:configure_plugin()
    setup:prepear_env()

    parser = Parser.new(config)
    runner = Runner.new(config, logger, parser)

    app.add_handler(
        "GET",
        "/",
        function()
            return "The server is running"
        end)
    app.add_handler(
        "POST",
        "/explain",
        function(captures, query, headers, body)
            local lang = query.lang
            logger:debug("Processing request by API ")
            local success, message = runner:explain_function(body, lang)
            logger:debug("request processed ", { response = message, success = success })
            return message
        end)
    app.start()
end

start()
