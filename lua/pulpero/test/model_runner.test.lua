local luaunit = require('luaunit')
local runner = luaunit.LuaUnit.new()
local Prompts = require('pulpero.core.prompts')
local Runner = require('pulpero.core.model_runner')
local Parser = require('pulpero.core.parser')
local Setup = require('pulpero.core.setup')
local Logger = require('pulpero.core.logger')

local loggerConsoleOutput = false

-- Integration test run manually
function testShouldProcessTheCode()
    local logger = Logger.new(loggerConsoleOutput)
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

function testShouldResponseARefactorOfTheCode()
    local logger = Logger.new(loggerConsoleOutput)
    logger:clearLogs()
    local setup = Setup.new(logger)
    setup:configurePlugin()
    local config = setup:prepearEnv()
    local parser = Parser.new(config)
    local runner = Runner.new(config, logger, parser)

    local code = [[
    public async ensureCore(): Promise<string> {
        const currentVersion = await this.getCurrentVersion();
        const latestVersion = await this.getLatestVersionInfo();

        if (!currentVersion || currentVersion !== latestVersion.version) {
            await vscode.window.withProgress(
                {
                    location: vscode.ProgressLocation.Notification,
                    title: "Updating Pulpero Core",
                    cancellable: false
                },
                async (progress) => {
                    if (this.isLocal) {
                        progress.report({ message: "Sync is in process..." });
                        const tmpFile = path.join(this.pathToLocalCore, 'core-local.tar.gz');
                        console.debug("Looking for the core in local folder ", tmpFile);
                        console.debug("Local version information", latestVersion);
                        this.extractLocalFile(tmpFile, latestVersion.version);
                        progress.report({ message: "Sync is complete" });

                    } else {
                        progress.report({ message: "Downloading..." });
                        const response = await fetch(latestVersion.url);
                        const tmpFile = path.join(this.storageUri.fsPath, 'core-download.tar.gz');

                        const fileStream = fs.createWriteStream(tmpFile);

                        fs.mkdirSync(path.dirname(tmpFile), { recursive: true });

                        await new Promise((resolve, reject) => {
                            response.body.pipe(fileStream);
                            response.body.on('error', reject);
                            fileStream.on('finish', resolve);
                        });
                        await this.extractLocalFile(tmpFile, latestVersion.version)

                        fs.unlinkSync(tmpFile);
                        progress.report({ message: "Installation complete" });
                    }
                }
            );
        }

        return this.coreDir;
    }
    ]]
    local language = "typescript"
    local modelResponse = runner:runLocalModel(code, language, Prompts.refactor_prompt)

    print("Model response")
    print(modelResponse)
    luaunit.assertNotNil(modelResponse)
end

function testShouldResponseTheCodeIsToLargeToBeAnalyze()
    local logger = Logger.new(loggerConsoleOutput)
    logger:clearLogs()
    local setup = Setup.new(logger)
    setup:configurePlugin()
    local config = setup:prepearEnv()
    config.context_window = 100
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
