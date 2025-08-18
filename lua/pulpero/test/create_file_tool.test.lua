local CreateFileTool = require('tool.create_file')
local Logger = require('logger')
local OSCommands = require('OSCommands')
local luaunit = require('luaunit')

local logger = Logger.new("Create_File_Tool_Test", false)

function test_should_create_a_file_with_content()
  local tool = CreateFileTool.create_create_file_tool(logger)
  local work_dir = OSCommands:get_work_dir()

  local params = { path =  work_dir .. "/test.txt", content="some content" }

  tool.execute(params)

  local content = OSCommands:get_file_content(params.path)
  luaunit.assertNotNil(content)
  luaunit.assertTrue(content == params.content)

  OSCommands:delete_file(params.path)
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
