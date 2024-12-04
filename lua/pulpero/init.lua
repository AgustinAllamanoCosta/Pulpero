local Runner = require('pulpero.model_runner')
local Setup = require('pulpero.setup')
local UI = require('pulpero.ui')
local Logger = require('pulpero.logger')
local Parser = require('pulpero.parser')

local PluginData = {}
PluginData.config = {}
local runner = nil
local setup = nil
local parser = nil
local ui = nil
local logger = nil

function PluginData.setup()
    logger = Logger.new()
    logger:clear_logs()
    setup = Setup.new(logger)
    local config = setup:configure_plugin()
    setup:prepear_env()

    parser = Parser.new(config)
    ui = UI.new(config)

    runner = Runner.new(config, logger, parser, ui)

    vim.api.nvim_create_user_command('ExpFn', function()
        runner:explain_function()
    end, {})
end

return PluginData
