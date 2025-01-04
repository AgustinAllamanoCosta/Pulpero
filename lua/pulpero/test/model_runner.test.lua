local luaunit = require('luaunit')
local runner = luaunit.LuaUnit.new()
local Prompts = require('pulpero.core.prompts')
local Runner = require('pulpero.core.model_runner')
local Parser = require('pulpero.core.parser')
local Setup = require('pulpero.core.setup')
local Logger = require('pulpero.core.logger')

-- Integration test run manually
function testShouldProcessTheCode()
    local logger = Logger.new(true)
    logger:clearLogs()
    local setup = Setup.new(logger)
    setup:configurePlugin()
    local config = setup:prepearEnv()
    local parser = Parser.new(config)
    local runner = Runner.new(config, logger, parser)

    local code = [[
function Runner.new(config, logger, parser)
    local self = setmetatable({}, { __index = Runner })
    if config == nil then
        error("Model Runner config is nil")
    end
    if logger == nil then
        error("Model Runner logger is nil")
    end
    if parser == nil then
        error("Model Runner parser is nil")
    end
    self.config = config
    self.logger = logger
    self.parser = parser
    return self
end
    ]]
    local language = "lua"
    local modelResponse = runner:runLocalModel(code, language, Prompts.explain_prompt)

    luaunit.assertNotNil(modelResponse)
end

function testShouldResponseTheCodeIsToLargeToBeAnalyze()
    local logger = Logger.new(true)
    logger:clearLogs()
    local setup = Setup.new(logger)
    setup:configurePlugin()
    local config = setup:prepearEnv()
    local parser = Parser.new(config)
    local runner = Runner.new(config, logger, parser)

    local code = [[
function Runner.new(config, logger, parser)
    local self = setmetatable({}, { __index = Runner })
    if config == nil then
        error("Model Runner config is nil")
    end
    if logger == nil then
        error("Model Runner logger is nil")
    end
    if parser == nil then
        error("Model Runner parser is nil")
    end
    self.config = config
    self.logger = logger
    self.parser = parser
    return self
end

function Runner.new(config, logger, parser)
    local self = setmetatable({}, { __index = Runner })
    if config == nil then
        error("Model Runner config is nil")
    end
    if logger == nil then
        error("Model Runner logger is nil")
    end
    if parser == nil then
        error("Model Runner parser is nil")
    end
    self.config = config
    self.logger = logger
    self.parser = parser
    return self
end

function Runner.new(config, logger, parser)
    local self = setmetatable({}, { __index = Runner })
    if config == nil then
        error("Model Runner config is nil")
    end
    if logger == nil then
        error("Model Runner logger is nil")
    end
    if parser == nil then
        error("Model Runner parser is nil")
    end
    self.config = config
    self.logger = logger
    self.parser = parser
    return self
end
    ]]
    local language = "lua"
    local modelResponse = runner:runLocalModel(code, language, Prompts.explain_prompt)

    luaunit.assertStrIContains(modelResponse, "The code is to large to be analyze, try with a small section")
end

runner:setOutputType("text")
os.exit( runner:runSuite() )
