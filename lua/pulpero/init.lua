local function add_pulpero_to_path()
    local current_file = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = current_file:match("(.*/)"):sub(1, -2):match("(.*/)"):sub(1, -2)

    local paths = {
        plugin_root .. "/?.lua",
        plugin_root .. "/?/init.lua",
        plugin_root .. "/pulpero/?.lua",
        plugin_root .. "/pulpero/?/init.lua",
        plugin_root .. "/pulpero/core/?.lua",
        plugin_root .. "/pulpero/core/?/init.lua",
        plugin_root .. "/pulpero/core/util/?.lua",
        plugin_root .. "/pulpero/core/util/?/init.lua",
        plugin_root .. "/pulpero/core/socket/?.lua",
        plugin_root .. "/pulpero/core/socket/?/init.lua",
        plugin_root .. "/pulpero/core/managers/?.lua",
        plugin_root .. "/pulpero/core/managers/?/init.lua",
        plugin_root .. "/pulpero/core/managers/tool/?.lua",
        plugin_root .. "/pulpero/core/managers/tool/?/init.lua",
        plugin_root .. "/pulpero/core/runner/model/?.lua",
        plugin_root .. "/pulpero/core/runner/model/?/init.lua",
        plugin_root .. "/pulpero/core/managers/model/?.lua",
        plugin_root .. "/pulpero/core/managers/model/?/init.lua",
        plugin_root .. "/pulpero/core/managers/audio/?.lua",
        plugin_root .. "/pulpero/core/managers/audio/?/init.lua",
    }

    for _, path in ipairs(paths) do
        if not package.path:match(path:gsub("[%.%/]", "%%%1")) then
            package.path = path .. ";" .. package.path
        end
    end

    return plugin_root
end

add_pulpero_to_path()

local M = {}
local UI = require('ui')
local Chat = require('chat')
local Pairing = require('pairing')
local Service_Connector = require('service_connector')

local ui = UI.new()
local service = Service_Connector.new()
local chat = Chat.new(ui, service)
local pairing = Pairing.new(ui, service)

local function submit_feat_desc()
    pairing:submit_description()
    chat:open()
end

local function should_update_file(bufnr)
    if bufnr == ui.chat_buf or bufnr == ui.input_buf then
        return false
    end
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    return buftype == ''
end

local function get_current_file()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local amount_of_lines = table.getn(lines)
    return table.concat(lines, "\n"), amount_of_lines
end

local function add_virtual_text()
    if chat.code then
        local bufnr = vim.api.nvim_get_current_buf()
        local ns_id = vim.api.nvim_create_namespace("pulpero_suggestion")
        vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row, col = cursor[1] - 1, cursor[2]
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
            virt_text = { { chat.code, "Comment" } },
            virt_text_pos = "inline"
        })
    end
end

local function update_code_data(self)
    if should_update_file(vim.api.nvim_get_current_buf()) then
        local current_file, amount_of_lines = get_current_file()
        chat:update_current_file_context(current_file, amount_of_lines)
        --add_virtual_text()
    end
end

function M.setup()
    if not service:connect() then
        print("Service not connected")
        return
    end
    chat:close()
    -- vim.api.nvim_create_autocmd({ "BufEnter", "BufWrite" }, {
    --     callback = update_code_data
    -- })
    --
    vim.api.nvim_create_user_command('PulperoOpenChat', function()
            chat:open()
        end,
        {
            range = true,
            desc =
            "Open the chat windows, if it is open in another tab close that windows and open a new one in the current tab"
        })

    vim.api.nvim_create_user_command('PulperoStatus', function()
        service:get_service_status(function(err, result)
            print(err)
            print(result)
        end)
    end, { range = true, desc = "Get the pulpero service status" })

    vim.api.nvim_create_user_command('PulperoCloseChat', function()
        chat:close()
    end, { range = true, desc = "Close the current open chat" })

    vim.api.nvim_create_user_command('PulperoSendChat', function()
        chat:submit_message()
    end, { range = true, desc = "Send the current input chat buffer to the model and update the chat history" })

    vim.api.nvim_create_user_command('PulperoClearModelCache', function()
        chat:clear()
    end, { range = true, desc = "Delete the model cache and the chat history" })

    vim.api.nvim_create_user_command('PulperoStartPairingSession', function()
        pairing:open()
    end, { range = true, desc = "Start a new pairing session and override the chat history" })

    vim.api.nvim_create_user_command('PulperoSubmitFeatDescription', function()
        submit_feat_desc()
    end, { range = true, desc = "Add a feature description to a new or a already started pairing session" })

    vim.api.nvim_create_user_command('PulperoEndsPairingSession', function()
        pairing:end_pairing_session()
    end, { range = true, desc = "End an ongoing pairing session" })

    vim.api.nvim_create_user_command('PulperoToggle', function()
        service:toggle_service(function(err, data) if err then print("Error toggling the service " .. err) end end)
    end, { range = true, desc = "Enable or Disable the plugin for running unless the IA model is not ready yet" })

    vim.api.nvim_create_user_command('PulperoFullScreen', function()
        chat:open(true)
    end, { range = true, desc = "Open Pulpero in full-screen mode in a new tab" })
end

return M
