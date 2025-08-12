local luaunit = require('luaunit')
local Setup = require('setup')
local ModelManager = require('model_manager')
local Logger = require('logger')
local OSCommands = require('OSCommands')

local loggerConsoleOutput = true

-- Test run manually
function test_should_download_llama_and_the_model()
    local logger = Logger.new("SetUp test", loggerConsoleOutput)
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

    logger:clear_logs()

    local model_manager = ModelManager.new(logger, default_config)
    local setup = Setup.new(logger, model_manager, default_config)
    setup:configure_plugin()

    -- local dir_info = setup:generate_llama_path()
    -- OSCommands:delete_folder(dir_info.llama_dir)
    local dir_info_model = OSCommands:create_path_by_OS(OSCommands:get_model_dir(), default_config.model_name)
    OSCommands:delete_file(dir_info_model)

    setup:prepear_env()

    -- luaunit.assertTrue(OSCommands:is_directory(dir_info.llama_dir))
    -- luaunit.assertTrue(OSCommands:file_exists(dir_info.llama_bin))
    luaunit.assertTrue(OSCommands:file_exists(dir_info_model))
end

-- function testShouldNotDownloadLlamaAndTheModelIfTheFolderAndModelFileExists()
--
--     local model_log_message = "Model already exist skipping download"
--     local llama_log_message = "Llama is already cloned, skipping"
--
--     local logger = Logger.new(loggerConsoleOutput)
--     logger:clearLogs()
--     local config = logger:getConfig()
--     local setup = Setup.new(logger)
--     setup:configurePlugin()
--
--     local dir_info = setup:generateLlamaPath()
--     OSCommands:deleteFolder(dir_info.llama_dir)
--     local dir_info_model = setup:generateModelPath()
--     OSCommands:deleteFile(dir_info_model)
--
--     setup:prepearEnv()
--     setup:prepearEnv()
--     local command_text = OSCommands:getFileContent(config.setup_path)
--
--     luaunit.assertTrue(OSCommands:isDirectory(dir_info.llama_dir))
--     luaunit.assertTrue(OSCommands:fileExists(dir_info_model))
--     luaunit.assertStrIContains(command_text,model_log_message)
--     luaunit.assertStrIContains(command_text,llama_log_message)
-- end
--
local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
