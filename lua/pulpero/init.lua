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
local ModelManager = require('core.model_manager')
local Setup = require('setup')
local Runner = require('model_runner')
local Pairing = require('pairing')
local Logger = require('logger')
local Parser = require('parser')
local UI = require('ui')
local Chat = require('chat')

local M = {}
local model_name = "deepseek-coder-v2-lite-instruct.gguf"
local default_settings = {
    context_window = 1024,
    temp = "0.1",
    num_threads = "4",
    top_p = "0.4",
    model_name = model_name,
    model_path = OSCommands:createPathByOS(OSCommands:getModelDir(), model_name),
    llama_repo = "https://github.com/ggerganov/llama.cpp.git",
    os = OSCommands:getPlatform(),
    pulpero_ready = false,
    response_size = "1024"
}
local model_manager = nil
local runner = nil
local parser = nil
local logger = nil
local setup = nil
local ui = nil
local chat = nil
local pairing = nil
local enable = false

function M.setup()
    logger = Logger.new()
    logger:clearLogs()
    local logger_config = logger:getConfig()
    model_manager = ModelManager.new(logger, default_settings)
    setup = Setup.new(logger, model_manager, default_settings)
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
    enable = true

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

    local function execute_command(callback, object)
        if config.pulpero_ready and enable then
            callback(object)
        else
            local model_exit = model_manager:isModelDownloaded()
            if enable then
                if model_exit then
                    print("The model is downloading")
                elseif not model_manager.config.model_assemble then
                    print("The model is not ready yet, we are assemble")
                end
            else
                print("The plugin is disable")
            end
        end
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWrite" }, {
        callback = update_current_file
    })

    vim.api.nvim_create_user_command('PulperoOpenChat', function()
            execute_command(chat.open, chat)
    end, { range = true, desc = "Open the chat windows, if it is open in another tab close that windows and open a new one in the current tab"})

    vim.api.nvim_create_user_command('PulperoCloseChat', function()
        execute_command(chat.close, chat)
    end, { range = true, desc = "Close the current open chat" })

    vim.api.nvim_create_user_command('PulperoSendChat', function()
        execute_command(chat.submit_message, chat)
    end, { range = true, desc = "Send the current input chat buffer to the model and update the chat history" })

    vim.api.nvim_create_user_command('PulperoClearModelCache', function()
        execute_command(runner.clearModelCache, runner)
    end, { range = true, desc = "Delete the model cache and the chat history" })

    vim.api.nvim_create_user_command('PulperoStartPairingSession', function()
        execute_command(pairing.open, pairing)
    end, { range = true, desc = "Start a new pairing session and override the chat history" })

    vim.api.nvim_create_user_command('PulperoSubmitFeatDescription', function()
        local function submit(obj)
            pairing:submit_description()
            chat:open()
        end
        execute_command(submit, nil)
    end, { range = true, desc = "Add a feature description to a new or a already started pairing session" })

    vim.api.nvim_create_user_command('PulperoEndsPairingSession', function()
        execute_command(runner.endPairingSession, runner)
    end, { range = true, desc = "End an ongoing pairing session" })

    vim.api.nvim_create_user_command('PulperoEnable', function()
        local model_exit = model_manager:isModelDownloaded()
        if model_exit and not enable then
            enable = true
        else
            if not model_exit then
                print("The model is downloading")
            else
                print("The model is not ready yet, we are assemble")
            end
        end
    end, { range = true, desc = "Enable the plugin for running unless the IA model is not ready yet" })

    vim.api.nvim_create_user_command('PulperoDisable', function()
        enable = false
    end, { range = true, desc = "Disable the plugin for running or execute any command" })
end

return M
