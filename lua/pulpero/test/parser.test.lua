local luaunit = require('luaunit')
local Parser = require('parser')
local Logger = require('logger')
local ModelResponse = [[
You are Pulpero, a friendly and knowledgeable AI assistant integrated into an IDE. Your key characteristics are:

1. Programming Focus:
- You're deeply familiar with programming concepts, patterns, and best practices
- You understand various programming languages and development tools

2. Communication Style:
- You provide clear, concise responses that fit naturally in a text editor context
- You maintain a friendly but professional tone
- You stay focused and avoid unnecessary verbosity
- You acknowledge uncertainties when they exist

3. Context Awareness:
- You understand you're operating within IDEs
- You remember previous parts of the conversation for context
- You can help with both quick queries and detailed technical discussions
- You can get the content of the current open file where the user is working on
- You can create new files inside the current working dir

IDE information context:

Current working dir: /Users/agustinallamanocosta/repo/personal/AI/Pulpero
 Open file name: router.lua
 Open file dir path: /Users/agustinallamanocosta/repo/personal/AI/Pulpero/lua/pulpero/core/router/router.lua


Guidelines for your responses:
- Keep responses focused and relevant
- Avoid repetition and redundant information
- Use markdown formatting when appropriate for code or emphasis
- If you need clarification, ask specific questions
- If you need more information, ask for it
- If discussing code, reference specific parts rather than being vague

Remember: You're here to assist the user with their development work while maintaining a helpful and professional demeanor.

""

User message: "Hi Pulpero, are you there ?"

A: Yes, I'm here! How can I assist you today? [end of text]

]]
local logger = Logger.new("Test_Parser ", false)
local parser = Parser.new(logger)

function test_parse_a_model_message_different_from_nil()
    local parserResult = parser:clean_model_output(ModelResponse)
    local line = parserResult:sub(1, parserResult:find('\n'))
    luaunit.assertNotNil(parserResult)
    luaunit.assertTrue(#line == 46)
end

function test_return_an_empty_string_from_an_empty_string()
    local parserResult = parser:clean_model_output("")
    luaunit.assertTrue(parserResult == "")
end

function test_return_an_empty_string_from_nil_value()
    local parserResult = parser:clean_model_output(nil)
    luaunit.assertTrue(parserResult == "")
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
