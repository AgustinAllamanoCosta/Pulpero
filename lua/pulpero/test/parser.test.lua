local luaunit = require('luaunit')
local Parser = require('parser')
local ModelResponse = [[<|system|>
You are a code explanation expert. Provide concise, non-repetitive explanations focusing on the key functionality.
<|user|>
Explain this lua function:

function Parser.new(config)
    local self = setmetatable({}, { __index = Parser })
    if config == nil then
        error("Config in parser can not be nil")
    end
    self.config = config
    return self
end
<|assistant|>
In the Lua function `Parser.new`, the `config` parameter is passed as an argument to the `setmetatable()` function. This function is used to create a new instance of the `Parser` class, which is a table with the following properties:

1. `config`: This is a table that contains the configuration settings for the parser. The `config` table is passed as an argument to the `setmetatable()` function, which creates a new table with the same properties.

2. `self`: This is the base class for the `Parser` class, which is the table that is created by the `setmetatable()` function.

3. `config`: This is the table that contains the configuration settings for the parser. The `config` table is passed as an argument to the `setmetatable()` function, which creates a new table with the same properties.

The `Parser` class is a table with the following properties:

1. `config`: This is the configuration settings for the parser. This is a table with the following properties:

   - `input_file`: This is the name of the input file.
   - `output_

]]
local config = { maxLineLength = 110 }
local parser = Parser.new(config)

function testParseAModelMessageDifferentFromNil()
    local parserResult = parser:cleanModelOutput(ModelResponse)
    local line = parserResult:sub(1,parserResult:find('\n'))
    luaunit.assertNotNil(parserResult)
    luaunit.assertTrue(#line <= config.maxLineLength)
end

function testReturnNilFromAnEmptyString()
    local parserResult = parser:cleanModelOutput("")
    luaunit.assertNil(parserResult)
end

function testReturnNilFromNilValue()
    local parserResult = parser:cleanModelOutput(nil)
    luaunit.assertNil(parserResult)
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit( runner:runSuite() )
