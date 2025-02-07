local OSCommands = require('core.util.OSCommands')
local Runner = require('model_runner')
local Pairing = require('pairing')
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
local pairing = nil
local enable = true

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
    pairing = Pairing.new(ui, runner, config)
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
        if enable then
            logger:debug("Processing request by native lua plugin")
            local selected_code = get_visual_selection()
            local filetype = vim.bo.filetype
            local success, result = function_ex(runner, filetype, selected_code)
            chat:show_message(result)
            logger:debug("Processing completed")
        else
            logger:debug("Pulpero is disable")
        end
    end

    local function should_update_file(bufnr)
        if bufnr == ui.chat_buf or bufnr == ui.input_buf then
            return false
        end

        local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
        return buftype == '' -- Only update for normal buffers
    end

    local function get_current_file()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        return table.concat(lines, "\n")
    end

    local function update_current_file()
        if should_update_file(vim.api.nvim_get_current_buf()) then
            local current_file = get_current_file()
            runner:updateCurrentFileContent(current_file)
        end
    end

    local function get_cursor_context()
        local cursor_line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based line number
        local buffer = vim.api.nvim_get_current_buf()

        local start_line = math.max(cursor_line - 5, 1)
        local end_line = cursor_line + 5

        local lines = vim.api.nvim_buf_get_lines(buffer, start_line - 1, end_line, false)
        local context = table.concat(lines, "\n")

        return {
            cursor_line = cursor_line,
            context = context,
            relative_cursor = cursor_line - start_line + 1 -- Position of cursor in the context
        }
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWrite" }, {
        callback = update_current_file
    })

    vim.api.nvim_create_user_command('PulperoExpFn', function()
        execute_function_and_show(runner.explainFunction)
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoRefactor', function()
        execute_function_and_show(runner.refactorFunction)
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoOpenChat', function()
        if enable then
            chat.open(chat)
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoCloseChat', function()
        if enable then
            chat.close(chat)
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoSendChat', function()
        if enable then
            chat:submit_message()
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoClearModelCache', function()
        if enable then
            runner:clearModelCache()
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoStartPairingSession', function()
        if enable then
            pairing:open();
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoSubmitFeatDescription', function()
        if enable then
            pairing:submit_description();
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoEndsPairingSession', function()
        if enable then
            runner:endPairingSession()
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoCodeComplete', function()
        if enable then
            local cursorInfo = get_cursor_context()
            local filetype = vim.bo.filetype
            local success, code = runner:completeCode(filetype, cursorInfo)
            if success then
                local cursor_pos = vim.api.nvim_win_get_cursor(0)
                local line = cursor_pos[1] - 1
                local col = cursor_pos[2]

                local completion_lines = vim.split(code, "\n")

                local current_line = vim.api.nvim_get_current_line()

                local new_line = current_line:sub(1, col) .. completion_lines[1] .. current_line:sub(col + 1)
                vim.api.nvim_buf_set_lines(0, line, line + 1, false, { new_line })

                if #completion_lines > 1 then
                    vim.api.nvim_buf_set_lines(0, line + 1, line + 1, false,
                        { unpack(completion_lines, 2) })
                end
            else
                logger:debug("Completion failed: ", { result = code })
            end
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoEnable', function()
        enable = true
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoDisable', function()
        enable = false
    end, { range = true })
end

return M
