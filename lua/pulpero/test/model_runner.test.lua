local luaunit = require('luaunit')
local runner = luaunit.LuaUnit.new()
local Prompts = require('prompts')
local Runner = require('model_runner')
local ToolManager = require('managers.tool.manager')
local ModelManager = require('model_manager')
local OSCommands = require('OSCommands')
local Parser = require('parser')
local Setup = require('setup')
local Logger = require('logger')

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

    local code = [[
function Runner.new(config, logger, parser)
    local self = setmetatable({}, { __index = Runner })
    if config == nil then
        error("Model Runner config is nil")
    end
    if logger == nil then
        error("Model Runner logger is nil")
    end
    if parser == nil then
        error("Model Runner parser is nil")
    end
    self.config = config
    self.logger = logger
    self.parser = parser
    return self
end
    ]]

    local complete_prompt = string.format(Prompts.chat, "", "", code)
    local prompt_file = Prompts:generate_prompt_file(complete_prompt)
    local model_response = model_runner:talk_with_model(prompt_file)

    luaunit.assertNotNil(model_response)
end

function test_define_the_query_as_chat()
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

    local user_query = [[
    Hi how are you?
    ]]

    local complete_prompt = string.format(Prompts.intent_prompt, "", user_query)
    local prompt_file = Prompts:generate_prompt_file(complete_prompt)
    local model_response = model_runner:talk_with_model(prompt_file)

    luaunit.assertNotNil(model_response)
    luaunit.assertTrue(model_response:gsub("%s+", ""):gsub("\n", "") == "general_chat")
end

function test_should_call_a_tool_for_get_the_content()
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

    local user_query = [[Can you show me the content of the file ci.sh at the path /user/home/agustinallamano/]]
    local context_data = ""
    local tool_call_description = tool_manager:generate_tools_description()
    local chat_history = ""

    local complete_prompt = string.format(
        Prompts.file_operation,
        context_data,
        tool_call_description,
        chat_history,
        user_query
    )
    local prompt_file = Prompts:generate_prompt_file(complete_prompt)
    local model_response = model_runner:talk_with_model(prompt_file)

    luaunit.assertNotNil(model_response)
    luaunit.assertStrIContains(model_response,'<tool name="show_file_content" params="path=/user/home/agustinallamano/ci.sh" />')
end

function test_should_generate_the_final_response_with_the_context_information()
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

    local user_query = [[Can you show me the content of the file ci.sh at the path /user/home/agustinallamano/]]
    local tool_response = [[ content file: export AWS_CREDENTIALS=kljalkdjlajsdlkjasdoiqwueipou109234u ]]


    local complete_response = string.format(Prompts.generate_final_response, user_query, tool_response)
    local prompt_file = Prompts:generate_prompt_file(complete_response)
    local final_response = model_runner:talk_with_model(prompt_file)

    luaunit.assertNotNil(final_response)
end

runner:setOutputType("text")
os.exit(runner:runSuite())
