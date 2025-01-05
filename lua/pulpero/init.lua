local OSCommands = require('util.OSCommands')
local Runner = require('model_runner')
local Setup = require('setup')
local Logger = require('logger')
local Parser = require('parser')
local UI = require('ui')

local M = {}
local runner = nil
local parser = nil
local logger = nil
local setup = nil
local ui = nil
local chat_win = nil
local chat_buff = nil

local function get_visual_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(
        0,
        start_pos[2] - 1,  -- Convert from 1-based to 0-based indexing
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
    if chat_win == nil then
        chat_win, chat_buff = ui:create_chat_sidebar()
    end
    ui:update_chat_content(result)
    logger:debug("Processing completed")
end

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

    parser = Parser.new(config)
    runner = Runner.new(config, logger, parser)
    ui = UI.new(config)

    vim.api.nvim_create_user_command('ExpFn', function()
        execute_function_and_show(runner.explain_function)
    end, { range = true })

    vim.api.nvim_create_user_command('Refactor', function()
        execute_function_and_show(runner.refactor_function)
    end, { range = true })
end

return M
