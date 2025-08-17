local History = {}
local user_key = "User"
local assistant_key = "Assistant"

function History.new(context)
    local self = setmetatable({}, { __index = History })
    self.chat_context = nil

    if context == nil then
        self.chat_context = self:create_new_chat_context()
    else
        self.chat_context = context
    end

    return self
end

function History:create_new_chat_context()
    return {
        messages = {},
        max_messages = 8,
        current_tokens = 0
    }
end

function History:update_chat_context_as_assistant(content)
    self:update_chat_context(assistant_key, content)
end

function History:update_chat_context_as_user(content)
    self:update_chat_context(user_key, content)
end

function History:update_chat_context(role, content)
    table.insert(self.chat_context.messages, {
        role = role,
        content = content
    })

    while #self.chat_context.messages > self.chat_context.max_messages do
        table.remove(self.chat_context.messages, 1)
    end

end

function History:build_chat_history()
    local history = ""

    for _, msg in ipairs(self.chat_context.messages) do
        if msg.role == user_key then
            history = history .. "User:" .. msg.content .. "\n"
        else
            history = history .. "Assistant: " .. msg.content .. "\n"
        end
    end

    return history
end

function History:generate_chat_history()
    local current_chat_history = self:build_chat_history()
    local chat_history = ""

    if current_chat_history ~= "" then
        chat_history = "Chat History:\n" .. current_chat_history .. "\nEnd History"
    end

    return chat_history
end

function History:clear()
   self.chat_context = self:create_new_chat_context()
end

return History
