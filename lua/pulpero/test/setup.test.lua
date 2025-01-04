local luaunit = require('luaunit')
local Setup = require('pulpero.core.setup')
local Logger = require('pulpero.core.logger')
local OSCommands = require('pulpero.util.OSCommands')

-- Test run manually
function testShouldDownloadLlamaAndTheModel()
    local logger = Logger.new(true)
    logger:clearLogs()
    local setup = Setup.new(logger)
    setup:configurePlugin()

    local dir_info = setup:generateLlamaPath()
    OSCommands:deleteFolder(dir_info.llama_dir)
    local dir_info_model = setup:generateModelPath()
    OSCommands:deleteFile(dir_info_model)

    setup:prepearEnv()

    luaunit.assertTrue(OSCommands:isDirectory(dir_info.llama_dir))
    luaunit.assertTrue(OSCommands:fileExists(dir_info.llama_bin))
    luaunit.assertTrue(OSCommands:fileExists(dir_info_model))
end

function testShouldNotDownloadLlamaAndTheModelIfTheFolderAndModelFileExists()

    local model_log_message = "Model already exist skipping download"
    local llama_log_message = "Llama is already cloned, skipping"

    local logger = Logger.new(true)
    logger:clearLogs()
    local config = logger:getConfig()
    local setup = Setup.new(logger)
    setup:configurePlugin()

    local dir_info = setup:generateLlamaPath()
    OSCommands:deleteFolder(dir_info.llama_dir)
    local dir_info_model = setup:generateModelPath()
    OSCommands:deleteFile(dir_info_model)

    setup:prepearEnv()
    setup:prepearEnv()
    local command_text = OSCommands:getFileContent(config.setup_path)

    luaunit.assertTrue(OSCommands:isDirectory(dir_info.llama_dir))
    luaunit.assertTrue(OSCommands:fileExists(dir_info_model))
    luaunit.assertStrIContains(command_text,model_log_message)
    luaunit.assertStrIContains(command_text,llama_log_message)
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
