local luaunit = require('luaunit')
local Logger = require('logger')
local OSCommands = require('OSCommands')

local loggerConsoleOutput = true

function test_should_extract_a_file()
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
