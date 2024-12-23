local Runner = require('pulpero.core.model_runner')
local Setup = require('pulpero.core.setup')
local Logger = require('pulpero.core.logger')
local Parser = require('pulpero.core.parser')
local UI = require('pulpero.ui')

local M = {}
local runner = nil
local parser = nil
local logger = nil
local setup = nil
local ui = nil

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

function M.setup()
    logger = Logger.new()
    logger:clear_logs()
    local logger_config = logger:getConfig()
    setup = Setup.new(logger)
    local config = setup:configure_plugin()
    local current_os = setup:get_platform()
    logger:setup("Current OS " .. current_os)
    logger:setup("Configuration ", config)
    logger:setup("Configuration logger", logger_config)
    setup:prepear_env()

    parser = Parser.new(config)
    runner = Runner.new(config, logger, parser)
    ui = UI.new(config)

    vim.api.nvim_create_user_command('ExpFn', function()
        local selected_code = get_visual_selection()
        local filetype = vim.bo.filetype

        ui:start_spiner()
        vim.schedule(function()
            local success, result = runner:explain_function(filetype, selected_code)

            ui:stop_spiner()

            if success then
                ui:show_explanation(result)
            else
                ui:show_error(result)
            end
        end)
    end, { range = true })

    vim.api.nvim_create_user_command('Refactor', function()
        local selected_code = get_visual_selection()
        local filetype = vim.bo.filetype

        ui:start_spiner()
        vim.schedule(function()
            local success, result = runner:refactor_function(filetype, selected_code)

            ui:stop_spiner()

            if success then
                ui:show_explanation(result)
            else
                ui:show_error(result)
            end
        end)
    end, { range = true })
end

return M
