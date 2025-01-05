local OSCommands = require('util.OSCommands')
local luaunit = require('luaunit')
local Logger = require('logger')
local logger = Logger.new()

function testCreateLogsFilesAtStart()
  local config = logger:getConfig()
  local debug_file = OSCommands:fileExists(config.debug_path)
  local error_file = OSCommands:fileExists(config.error_path)
  local setup_file = OSCommands:fileExists(config.setup_path)
  local command_file = OSCommands:fileExists(config.command_path)

  luaunit.assertTrue(debug_file)
  luaunit.assertTrue(error_file)
  luaunit.assertTrue(setup_file)
  luaunit.assertTrue(command_file)
end

function testWriteStartMessageAfterCleanLogs()
  local config = logger:getConfig()
  logger:clearLogs()
  local debug_text = OSCommands:getFileContent(config.debug_path)
  local error_text = OSCommands:getFileContent(config.error_path)
  local setup_text = OSCommands:getFileContent(config.setup_path)
  local command_text = OSCommands:getFileContent(config.command_path)

  luaunit.assertStrIContains(debug_text,config.title_debug)
  luaunit.assertStrIContains(error_text,config.title_error)
  luaunit.assertStrIContains(command_text,config.title_command)
  luaunit.assertStrIContains(setup_text,config.title_setup)
end

function testWriteInDebugFile()
  local config = logger:getConfig()
  local messageToLog = "Some log message"
  logger:clearLogs()
  logger:debug(messageToLog)
  local debug_text = OSCommands:getFileContent(config.debug_path)

  luaunit.assertStrIContains(debug_text,messageToLog)
end

function testWriteInSetupFile()
  local config = logger:getConfig()
  local messageToLog = "Some log message"
  logger:clearLogs()
  logger:setup(messageToLog)
  local setup_text = OSCommands:getFileContent(config.setup_path)

  luaunit.assertStrIContains(setup_text,messageToLog)
end

function testWriteInErrorFile()
  local config = logger:getConfig()
  local messageToLog = "Some log message"
  logger:clearLogs()
  logger:error(messageToLog)
  local error_text = OSCommands:getFileContent(config.error_path)

  luaunit.assertStrIContains(error_text,messageToLog)
end

function testWriteInFileAMessageWithFormat()
  local config = logger:getConfig()
  local messageToLog = "Some log message"
  local objectToLog = { message = "some data" }
  local expectedContent = [[
=== New Command Session Started ===
%s: Some log message
Data: {
"message" = "some data",
}
----------------------------------------
]]
  logger:clearLogs()
  logger:writeInLog(config.command_path, messageToLog, objectToLog)
  local command_text = OSCommands:getFileContent(config.command_path)

  luaunit.assertIs(command_text, string.format(expectedContent,os.date("%Y-%m-%d %H:%M:%S")))
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
