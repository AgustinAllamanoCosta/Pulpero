local Chat = {}
local pulpero_key = "Pulpero"
local user_key = "User"
local system_key = "System"

function Chat.new(ui, service )
    local self        = setmetatable({}, { __index = Chat })
    self.ui           = ui
    self.chat_open    = false
    self.service      = service
    self.code_snippet = nil
    self.code         = nil
    self.file_context = nil
    return self
end

function Chat.open(self, full_screen)
    full_screen = full_screen or false
    if self.chat_open then self:close() end

    if full_screen then
        self.ui:create_chat_fullscreen()
    else
        if self.ui.chat_win then
            self.ui:open_chat()
        else
            self.ui:create_chat_sidebar()
        end
    end
    self.chat_open    = true
    local keymap_opts = { noremap = true, silent = false }
    vim.api.nvim_buf_set_keymap(self.ui.input_buf, 'i', '<CR>',
        '<Esc>:PulperoSendChat<CR>',
        keymap_opts)
end

function Chat.clear(self)
    self.service:clear_model_cache(function(err, result)
        if err then
            self:append_message(system_key, "Error clearing cache: " .. err)
        end
    end)
    if self.ui.chat_buf and self.ui.chat_win then
        vim.api.nvim_buf_set_option(self.ui.chat_buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(self.ui.chat_buf, 0, -1, false, { "" })
        vim.api.nvim_win_set_cursor(self.ui.chat_win, { 0, 0 })
        vim.api.nvim_buf_set_option(self.ui.chat_buf, 'modifiable', false)
    end
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

function Chat.replace_last_message(self, sender, content)
    if not self.chat_open then
        return
    end

    vim.api.nvim_buf_set_option(self.ui.chat_buf, 'modifiable', true)
    local current_lines = vim.api.nvim_buf_get_lines(self.ui.chat_buf, 0, -1, false)
    local message_lines = vim.split(content, '\n')

    table.insert(current_lines, "")

    table.remove(current_lines)
    table.remove(current_lines)
    if sender == user_key then
        current_lines[#current_lines+1] = "😎 " .. sender .. ": " .. message_lines[1]
    elseif sender == pulpero_key then
        current_lines[#current_lines+1] = "🦶 " .. sender .. ": " .. message_lines[1]
    elseif sender == system_key then
        current_lines[#current_lines+1] =  "🤖 " .. sender .. ": " .. message_lines[1]
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

        self:replace_last_message(user_key, message)
        self:append_message(pulpero_key, "⏲️  Cooking...")
        self.service:talk_with_model(message, self.file_context, function(err, result)
            vim.schedule(function()
                if err then
                    self:replace_last_message(pulpero_key, "🛑 Error: " .. err)
                    return
                end

                if result then
                    if type(result) == "table" and result.type == "buffer_edit" then
                        self:apply_buffer_edit(result)
                        local msg = result.message and result.message:gsub("\\n", "\n") or "Buffer edit applied."
                        self:replace_last_message(pulpero_key, msg)
                    else
                        local message_to_append = result:gsub("\\n", "\n")
                        self:replace_last_message(pulpero_key, message_to_append)
                    end

                    self:append_message(system_key,
                        "🚨 ! Note: This explanation is AI-generated and should be verified for accuracy. ! 🚨")
                else
                    self:replace_last_message(pulpero_key, "🛑 Error: Failed to get response from model")
                end
            end)
        end)
    end
end

function Chat.apply_buffer_edit(self, edit_response)
    local target_path = edit_response.path
    local new_content = edit_response.content

    if not target_path or target_path == "" then
        self:append_message(system_key, "⚠️ Buffer edit failed: no file path provided by model.")
        return
    end

    if not new_content then
        self:append_message(system_key, "⚠️ Buffer edit failed: no content provided by model.")
        return
    end

    local target_buf = nil
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            if vim.api.nvim_buf_get_name(bufnr) == target_path then
                target_buf = bufnr
                break
            end
        end
    end

    if target_buf then
        local normalised = new_content:gsub("\r\n", "\n"):gsub("\r", "\n")
        local lines = vim.split(normalised, "\n", { plain = true })
        if lines[#lines] == "" then
            table.remove(lines)
        end
        vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, lines)
        self:append_message(system_key, "✅ Buffer updated.")
    else
        self:append_message(system_key,
            "⚠️ File '" .. target_path .. "' is not currently open in the editor. " ..
            "Open it and re-run the request to apply the edit.")
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
