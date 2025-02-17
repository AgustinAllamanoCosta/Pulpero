local function addPulperoToPath()
    local current_file = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = current_file:match("(.*/)"):sub(1, -2):match("(.*/)"):sub(1, -2)

    local paths = {
        plugin_root .. "/?.lua",
        plugin_root .. "/?/init.lua",
        plugin_root .. "/pulpero/?.lua",
        plugin_root .. "/pulpero/core/?.lua",
        plugin_root .. "/pulpero/util/?.lua"
    }

    for _, path in ipairs(paths) do
        if not package.path:match(path:gsub("[%.%/]", "%%%1")) then
            package.path = path .. ";" .. package.path
        end
    end

    return plugin_root
end

local plugin_root = addPulperoToPath()
local OSCommands = require('core.util.OSCommands')
local Setup = require('setup')
local Runner = require('model_runner')
local Pairing = require('pairing')
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
    chat = Chat.new(ui, runner, parser, config)
    pairing = Pairing.new(ui, runner, config)
    chat:close()

    local function should_update_file(bufnr)
        if bufnr == ui.chat_buf or bufnr == ui.input_buf then
            return false
        end

        local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
        return buftype == '' -- Only update for normal buffers
    end

    local function get_current_file()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local amount_of_lines = table.getn(lines)
        return table.concat(lines, "\n"), amount_of_lines
    end

    local function update_current_file()
        if should_update_file(vim.api.nvim_get_current_buf()) then
            local current_file, amount_of_lines = get_current_file()
            runner:updateCurrentFileContent(current_file, amount_of_lines)
        else
            logger:debug('Should not update buffer')
        end
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWrite" }, {
        callback = update_current_file
    })

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
            pairing:open()
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoSubmitFeatDescription', function()
        if enable then
            pairing:submit_description()
            chat:open()
        end
    end, { range = true })

    vim.api.nvim_create_user_command('PulperoEndsPairingSession', function()
        if enable then
            runner:endPairingSession()
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
