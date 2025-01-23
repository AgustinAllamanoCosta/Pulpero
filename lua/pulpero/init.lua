local OSCommands = require('core.util.OSCommands')
local Runner = require('model_runner')
local Setup = require('setup')
local Logger = require('logger')
local Parser = require('parser')
local UI = require('ui')
local Chat = require('chat')

local M = {}
local runner = nil
local parser = nil
local logger = nil
local setup = nil
local ui = nil
local chat = nil

function M.setup()
    logger = Logger.new()
    logger:clearLogs()
    local logger_config = logger:getConfig()
    setup = Setup.new(logger)
    local config = setup:configurePlugin()
    local current_os = OSCommands:getPlatform()
    logger:setup("Current OS " .. current_os)
    logger:setup("Configuration ", config)
    logger:setup("Configuration logger", logger_config)
    setup:prepearEnv()

    parser = Parser.new(config, logger)
    runner = Runner.new(config, logger, parser)
    ui = UI.new(config)
    chat = Chat.new(ui, runner, config)
    chat:close()

    local function get_visual_selection()
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        local lines = vim.api.nvim_buf_get_lines(
            0,
            start_pos[2] - 1, -- Convert from 1-based to 0-based indexing
            end_pos[2],
            false
        )
        if #lines == 0 then
            return nil
        end
        return table.concat(lines, "\n")
    end

    local function execute_function_and_show(function_ex)
        logger:debug("Processing request by native lua plugin")
        local selected_code = get_visual_selection()
        local filetype = vim.bo.filetype
        local success, result = function_ex(runner, filetype, selected_code)
        chat:show_message(result)
        logger:debug("Processing completed")
    end

    vim.api.nvim_create_user_command('PulperoExpFn', function()
        execute_function_and_show(runner.explainFunction)
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoRefactor', function()
        execute_function_and_show(runner.refactorFunction)
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoOpenChat', function()
        chat.open(chat)
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoCloseChat', function()
        chat.close(chat)
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoSendChat', function()
        chat:submit_message()
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoClearModelCache', function()
        runner:clearModelCache()
    end, { range = true })
end

return M
