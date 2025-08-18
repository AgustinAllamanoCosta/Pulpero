local GetFileTool = require('tool.get_file')
local Logger = require('logger')
local OSCommands = require('OSCommands')
local luaunit = require('luaunit')

local logger = Logger.new("Get_File_Tool_Test", false)

function test_should_get_an_existing_file()
  local tool = GetFileTool.create_get_file_tool(logger)

  local params = { path = OSCommands:create_path_by_OS(OSCommands:get_work_dir(), "test.txt") }
  local expected_content = "some test content"

  local file = io.open(params.path, "w")
  if file ~= nil then
    file:write(expected_content)
    file:close()
  end

  local content = tool.execute(params)

  print(content)
  luaunit.assertNotNil(content)
  luaunit.assertTrue(content == expected_content)

  OSCommands:delete_file(params.path)
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
