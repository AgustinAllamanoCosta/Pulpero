local OSCommands = require('OSCommands')
local luaunit = require('luaunit')
local Logger = require('logger')
local logger = Logger.new("test", true)

function test_create_logs_files_at_start()
  local config = logger:get_config()
  local debug_file = OSCommands:file_exists(config.debug_path)
  local error_file = OSCommands:file_exists(config.error_path)
  local setup_file = OSCommands:file_exists(config.setup_path)
  local command_file = OSCommands:file_exists(config.command_path)

  luaunit.assertTrue(debug_file)
  luaunit.assertTrue(error_file)
  luaunit.assertTrue(setup_file)
  luaunit.assertTrue(command_file)
end

function test_write_start_message_after_clean_logs()
  local config = logger:get_config()
  logger:clear_logs()
  local debug_text = OSCommands:get_file_content(config.debug_path)
  local error_text = OSCommands:get_file_content(config.error_path)
  local setup_text = OSCommands:get_file_content(config.setup_path)
  local command_text = OSCommands:get_file_content(config.command_path)

  luaunit.assertStrIContains(debug_text,config.title_debug)
  luaunit.assertStrIContains(error_text,config.title_error)
  luaunit.assertStrIContains(command_text,config.title_command)
  luaunit.assertStrIContains(setup_text,config.title_setup)
end

function test_write_in_debug_file()
  local config = logger:get_config()
  local message_to_log = "Some log message"
  logger:clear_logs()
  logger:debug(message_to_log)
  local debug_text = OSCommands:get_file_content(config.debug_path)

  luaunit.assertStrIContains(debug_text,message_to_log)
end

function test_write_in_setup_file()
  local config = logger:get_config()
  local message_to_log = "Some log message"
  logger:clear_logs()
  logger:setup(message_to_log)
  local setup_text = OSCommands:get_file_content(config.setup_path)

  luaunit.assertStrIContains(setup_text,message_to_log)
end

function test_write_in_error_file()
  local config = logger:get_config()
  local messageToLog = "Some log message"
  logger:clear_logs()
  logger:error(messageToLog)
  local error_text = OSCommands:get_file_content(config.error_path)

  luaunit.assertStrIContains(error_text,messageToLog)
end

function test_write_in_file_a_message_with_format()
  local config = logger:get_config()
  local message_to_log = "Some log message"
  local object_to_log = { message = "some data" }
  local expected_content = [[
=== New Command Session Started ===
%s: Some log message
Data: {
"message" = "some data",
}
----------------------------------------
]]
  logger:clear_logs()
  logger:write_in_log(config.command_path, message_to_log, object_to_log)
  local command_text = OSCommands:get_file_content(config.command_path)

  luaunit.assertIs(command_text, string.format(expected_content,os.date("%Y-%m-%d %H:%M:%S")))
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
