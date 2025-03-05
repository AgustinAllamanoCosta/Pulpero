local Chat = {}
local pulpero_key = "Pulpero"
local user_key = "User"
local system_key = "System"

function Chat.new(ui, service)
    local self        = setmetatable({}, { __index = Chat })
    self.ui           = ui
    self.chat_open    = false
    self.service      = service
    self.code_snippet = nil
    self.code         = nil
    return self
end

function Chat.update(self, message)
    self.ui:update_chat_content(message)
end

function Chat.open(self)
    if self.chat_open then self:close() end

    if self.ui.chat_win then
        self.ui:open_chat()
    else
        self.ui:create_chat_sidebar()
    end
    self.chat_open    = true
    local keymap_opts = { noremap = true, silent = false }
    vim.api.nvim_buf_set_keymap(self.ui.input_buf, 'i', '<CR>',
        '<Esc>:PulperoSendChat<CR>',
        keymap_opts)
end

function Chat.clear(self)
    vim.api.nvim_buf_set_option(self.ui.chat_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(self.ui.chat_buf, 0, -1, false, { "" })
    vim.api.nvim_win_set_cursor(self.ui.chat_win, { 0, 0 })
    vim.api.nvim_buf_set_option(self.ui.chat_buf, 'modifiable', false)
    self.service:clear_model_cache(function(err, result)
        if err then
            self:append_message(system_key, "Error clearing cache: " .. err)
        end
    end)
end

function Chat.update_current_file_context(self, file_data, amount_of_lines)
    self.service:update_current_file_content(file_data, amount_of_lines, function(err, result)
        if err then
            print("Error updating file context: ")
            print(err)
        end
    end)
end

function Chat.append_message(self, sender, content)
    if not self.chat_open then
        return
    end

    vim.api.nvim_buf_set_option(self.ui.chat_buf, 'modifiable', true)
    local current_lines = vim.api.nvim_buf_get_lines(self.ui.chat_buf, 0, -1, false)
    local message_lines = vim.split(content, '\n')

    table.insert(current_lines, "")

    if sender == user_key then
        table.insert(current_lines, "😎 " .. sender .. ": " .. message_lines[1])
    elseif sender == pulpero_key then
        table.insert(current_lines, "🦶 " .. sender .. ": " .. message_lines[1])
    elseif sender == system_key then
        table.insert(current_lines, "🤖 " .. sender .. ": " .. message_lines[1])
    end

    for i = 2, #message_lines do
        table.insert(current_lines, "    " .. message_lines[i])
    end

    vim.api.nvim_buf_set_lines(self.ui.chat_buf, 0, -1, false, current_lines)
    vim.api.nvim_win_set_cursor(self.ui.chat_win, { #current_lines, 0 })
    vim.api.nvim_buf_set_option(self.ui.chat_buf, 'modifiable', false)
end

function Chat.submit_message(self)
    if not self.chat_open then
        return
    end
    local message = vim.api.nvim_buf_get_lines(self.ui.input_buf, 0, -1, false)[1]

    if message and message ~= "" then
        vim.api.nvim_buf_set_lines(self.ui.input_buf, 0, -1, false, { "" })

        self:append_message(user_key, message)
        self:append_message(pulpero_key, "⏲️  Cooking...")
        self.service:talk_with_model(message, function(err, result)
            if err then
                self.ui:append_message(pulpero_key, "🛑 Error: " .. err)
                return
            end

            if result and result.success then
                -- Replace "Cooking..." message with actual response
                self.ui:append_message(pulpero_key, result.message)

                -- Set code snippet if available
                if result.code then
                    self.code = result.code
                end

                self:append_message(system_key,
                    "🚨 ! Note: This explanation is AI-generated and should be verified for accuracy. ! 🚨")
            else
                self.ui:update_message(pulpero_key, "🛑 Error: Failed to get response from model")
            end
        end)
    end
end

function Chat.close(self)
    if self.chat_open == true then
        self.ui:close_chat()
        self.chat_open = false
    end
end

function Chat.show_message(self, message)
    if not self.chat_open then
        self:open()
    end
    self:append_message("Assistant", message)
end

return Chat
