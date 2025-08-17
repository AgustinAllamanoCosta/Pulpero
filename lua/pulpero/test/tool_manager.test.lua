local luaunit = require('luaunit')
local runner = luaunit.LuaUnit.new()
local ToolManager = require('managers.tool.manager')
local Logger = require('logger')

local loggerConsoleOutput = false

function test_should_parse_a_tool_call()
    local logger = Logger.new("Tool Manager Test", loggerConsoleOutput)
    logger:clear_logs()
    local tool_manager = ToolManager.new(logger)

    local model_with_tool_call = [[
        <tool name="show_file_content" params="path=/user/home/agustinallamano/ci.sh" />
    ]]
    local parse = tool_manager:parse_tool_calls(model_with_tool_call)

    luaunit.assertNotNil(parse[1]["params"])
    luaunit.assertNotNil(parse[1]["name"])
end

function test_should_parse_a_tool_call_with_multiple_params()
    local logger = Logger.new("Tool Manager Test", loggerConsoleOutput)
    logger:clear_logs()
    local tool_manager = ToolManager.new(logger)

    local model_with_tool_call = [[
        <tool name="show_file_content" params="path=/user/home/agustinallamano/ci.sh,workdir=some/other/dir" />
    ]]
    local parse = tool_manager:parse_tool_calls(model_with_tool_call)

    luaunit.assertNotNil(parse[1]["params"]["path"])
    luaunit.assertNotNil(parse[1]["params"]["workdir"])
    luaunit.assertNotNil(parse[1]["name"])
end

function test_should_parse_a_tool_call_with_multiple_params_with_white_spaces()
    local logger = Logger.new("Tool Manager Test", loggerConsoleOutput)
    logger:clear_logs()
    local tool_manager = ToolManager.new(logger)

    local model_with_tool_call = [[
        <tool name="show_file_content" params="path=/user/home/agustinallamano/ci.sh, workdir=some/other/dir" />
    ]]
    local parse = tool_manager:parse_tool_calls(model_with_tool_call)

    luaunit.assertNotNil(parse[1]["params"]["path"])
    luaunit.assertNotNil(parse[1]["params"]["workdir"])
    luaunit.assertNotNil(parse[1]["name"])
end

runner:setOutputType("text")
os.exit(runner:runSuite())
