local M = {}
local current_file = debug.getinfo(1, "S").source:sub(2)
local plugin_root = current_file:match("(.*/)"):sub(1, -2):match("(.*/)"):sub(1, -2)

local paths = {
    plugin_root .. "/?.lua",
    plugin_root .. "/?/init.lua",
    plugin_root .. "/pulpero/?.lua",
}

for _, path in ipairs(paths) do
    if not package.path:match(path:gsub("[%.%/]", "%%%1")) then
        package.path = path .. ";" .. package.path
    end
end

local UI = require('ui')
local Virtual_Text = require('virtual_text')
local Chat = require('chat')
local Service_Connector = require('service_connector')
local Realtime_Feedback = require('realtime_feedback')

local virtual_text = Virtual_Text.new()
local ui = UI.new()
local service = Service_Connector.new()
local chat = Chat.new(ui, service)
local realtime_feedback = Realtime_Feedback.new(virtual_text, service)
local last_working_dir = ""

local function update_code_context()
    local bufnr = vim.api.nvim_get_current_buf()
    if bufnr == ui.chat_buf or bufnr == ui.input_buf then
        return false
    end
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = bufnr })

    if buftype == "" then
        local current_file_path = vim.api.nvim_buf_get_name(0)
        local cwd = vim.loop.cwd()
        chat.file_context = {
            current_working_dir = cwd,
            current_file_name   = string.match(current_file_path, "[^/\\]+$"),
            current_file_path   = current_file_path,
        }
        if cwd ~= last_working_dir and service.connected then
            last_working_dir = cwd
            service:update_project_context(cwd, function(err, _)
                if err then
                    print("Pulpero: failed to update project context: " .. tostring(err))
                end
            end)
        end
    end
end

function M.setup()
    if not service:connect() then
        return
    end

    local group = vim.api.nvim_create_augroup("PulperoRealtimeFeedback", { clear = true })
    chat:close()

    vim.api.nvim_create_user_command('PulperoOpenChat', function()
            chat:open()
        end,
        {
            range = true,
            desc =
            "Open the chat windows, if it is open in another tab close that windows and open a new one in the current tab"
        })

    vim.api.nvim_create_user_command('PulperoCloseChat', function()
        chat:close()
    end, { range = true, desc = "Close the current open chat" })

    vim.api.nvim_create_user_command('PulperoSendChat', function()
        chat:submit_message()
    end, { range = true, desc = "Send the current input chat buffer to the model and update the chat history" })

    vim.api.nvim_create_user_command('PulperoClearModelCache', function()
        virtual_text:clear_all()
        chat:clear()
    end, { range = true, desc = "Delete the model cache and the chat history" })

    vim.api.nvim_create_user_command('PulperoToggle', function()
        service:toggle_service(function(err, data) if err then print("Error toggling the service " .. err) end end)
    end, { range = true, desc = "Enable or Disable the plugin for running unless the IA model is not ready yet" })

    vim.api.nvim_create_user_command('PulperoFullScreen', function()
        chat:open(true)
    end, { range = true, desc = "Open Pulpero in full-screen mode in a new tab" })

    vim.api.nvim_create_user_command('PulperoClearVirtual', function()
        virtual_text:clear_all()
    end, {
        range = true,
        desc = "Clear all Pulpero virtual text feedback"
    })

    vim.api.nvim_create_user_command('PulperoFeedback', function()
        local current_time = vim.loop.hrtime() / 1000000
        virtual_text:clear_all()
        if realtime_feedback.state.mode_timer then
            vim.fn.timer_stop(realtime_feedback.state.mode_timer)
        end
        realtime_feedback:analyze_current_context_always(current_time)
    end, {
        range = true,
        desc = "Analyze the current contxt of the cursor with Pulpero"
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPre", "BufNewFile" }, {
        callback = function()
            update_code_context()
        end
    })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        callback = function()
            realtime_feedback:reset()
        end
    })

    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
        group = group,
        callback = function()
            if realtime_feedback.state.typing_timer ~= nil then
                vim.fn.timer_stop(realtime_feedback.state.typing_timer)
            end

            realtime_feedback.state.typing_timer = vim.fn.timer_start(realtime_feedback.config.debounce_ms,
                function()
                    realtime_feedback:analyze_current_context()
                end)
        end
    })
end

return M
