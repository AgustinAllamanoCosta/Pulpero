local FindFileTool = require('tool.find_file')
local Logger = require('logger')
local OSCommands = require('OSCommands')
local luaunit = require('luaunit')

local logger = Logger.new("Find_File_Tool_Test", false)

function test_should_find_a_file_and_return_the_path()
  local tool = FindFileTool.create_find_file_tool(logger)
  local work_dir = OSCommands:get_work_dir()

  local params = { name = "test.txt", dir=work_dir }
  local expected_path = OSCommands:create_path_by_OS(work_dir, params.name)

  OSCommands:create_file(expected_path)
  local path = tool.execute(params)

  luaunit.assertNotNil(path[1])
  luaunit.assertTrue(path[1] == expected_path )
  OSCommands:delete_file(expected_path)
end

function test_should_find_a_file_in_a_nested_folder_and_return_the_path()
  local tool = FindFileTool.create_find_file_tool(logger)
  local work_dir = OSCommands:get_work_dir()
  local nested_folder_path = OSCommands:create_path_by_OS(work_dir, "testFolder")

  OSCommands:create_directory(nested_folder_path)

  local params = { name = "test.txt", dir=work_dir }
  local expected_path = OSCommands:create_path_by_OS(nested_folder_path, params.name)

  OSCommands:create_file(expected_path)
  local path = tool.execute(params)

  luaunit.assertNotNil(path[1])
  luaunit.assertTrue(path[1] == expected_path )
  OSCommands:delete_file(expected_path)
  OSCommands:delete_folder(nested_folder_path)
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
