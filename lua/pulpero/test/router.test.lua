local luaunit = require('luaunit')
local runner = luaunit.LuaUnit.new()
local Prompts = require('prompts')
local Runner = require('model_runner')
local Router = require('router.router')
local ToolManager = require('managers.tool.manager')
local ModelManager = require('model_manager')
local OSCommands = require('OSCommands')
local Parser = require('parser')
local Setup = require('setup')
local Logger = require('logger')
local History = require('history.manager')

local loggerConsoleOutput = false

-- Integration test run manually
function test_should_process_the_code()
    local default_config = {
        context_window = 1024,
        temp = "0.1",
        num_threads = "4",
        top_p = "0.4",
        model_name = "deepseek-coder-v2-lite-instruct.gguf",
        model_path = OSCommands:create_path_by_OS(OSCommands:get_model_dir(), "deepseek-coder-v2-lite-instruct.gguf"),
        llama_repo = "https://github.com/ggerganov/llama.cpp.git",
        os = OSCommands:get_platform(),
        pulpero_ready = false,
        response_size = "1024"
    }

    local logger = Logger.new("Model_Runner_Test", loggerConsoleOutput)
    logger:clear_logs()
    local model_manager = ModelManager.new(logger, default_config)
    local setup = Setup.new(logger, model_manager, default_config)
    setup:configure_plugin()
    local config = setup:prepear_env()
    local parser = Parser.new(logger)
    local model_runner = Runner.new(config, logger, parser)
    local tool_manager = ToolManager.new(logger)
    local history = History.new(nil)
    local router = Router.new(config, logger, model_runner, tool_manager, history)
    local context = { current_file_path = "/Users/agustinallamanocosta/repo/centralo/galactus/services/banners-api/src/app.ts" }

    local response = router:code_suggestion_pipeline(context)
    print(response)
end

runner:setOutputType("text")
os.exit(runner:runSuite())
