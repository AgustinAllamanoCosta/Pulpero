local prompts = require "prompts"
local Runner = {}
local user_key = "User"
local assistant_key = "Assistant"
local cache_prompt_path = "/tmp/prompts.bin"
local nil_or_empty_response =
"It's looks like there is a problem with the answer generated by the model, try with a different query or line of code."
local error_file_permission = "Error to run the model, can not write the file for the temp prompt"
local error_message_template = [[
An error occurred while we process your query:
Error: %s

Possible solutions:
- Check if the model path is correct (%s)
- Ensure llama-cli is properly installed (%s)

You can check the logs at: %s]]

function Runner.new(config, logger, parser)
    local self = setmetatable({}, { __index = Runner })
    if config == nil then
        error("Model Runner config is nil")
    end
    if logger == nil then
        error("Model Runner logger is nil")
    end
    if parser == nil then
        error("Model Runner parser is nil")
    end
    self.current_file = nil
    self.config = config
    self.logger = logger
    self.parser = parser
    self.chat_context = self:createNewChatContext()
    self.is_file_context_available = false
    self.model_parameters = {
        repeat_penalty = "1.2",
        mirostat = "2",
        context_window = "4096",
        response_size = "1024",
        temp = "0.2",
        top_p = "0.3",
        num_threads = self.config.num_threads,
        model_path = self.config.model_path,
        llama_cpp_path = self.config.llama_cpp_path,
        command_debug_output = logger:getConfig().command_path
    }
    self.pairing_session = {
        feature = "",
        running = false
    }
    return self
end

function Runner.createNewChatContext(self)
    return {
        messages = {},
        max_messages = 10, -- Keep last 10 messages for context
        current_tokens = 0,
        max_tokens = 4096  -- Match your model's context window
    }
end

function Runner.generatePromptFile(self, prompt)
    self.logger:debug("Creating temp file with prompt")
    local tmp_prompt = os.tmpname()
    local tmp_prompt_file = io.open(tmp_prompt, 'w')
    if not tmp_prompt_file then
        self.logger:error(error_file_permission)
        return error_file_permission
    end
    tmp_prompt_file:write(prompt)
    tmp_prompt_file:close()
    self.logger:debug("File created", { tmp_file = tmp_prompt })
    return tmp_prompt
end

function Runner.runLocalModel(self, prompt, config)
    self.logger:debug("Configuration ", config)

    local tmp_prompt = self:generatePromptFile(prompt)
    local response_file = os.tmpname()

    self.logger:debug("Formatting command to execute")
    local command = string.format(
        '%s -m %s --temp %s --ctx-size %s --threads %s --top_p %s --repeat-penalty 1.2'
        .. ' --repeat-last-n 64 --mirostat %s --mirostat-lr 0.1 --mirostat-ent 5.0'
        .. ' -n %s'                                               -- Maximum tokens to generate
        .. ' --prompt-cache '.. cache_prompt_path                 -- Cache the prompt for faster loading
        .. ' -ngl 1'                                              -- Use GPU for better performance
        .. ' -b 512'                                              -- Batch size for processing
        .. ' -r "User:" --in-prefix " " --in-suffix "A:"'         -- Better chat handling
        .. ' -f %s 1> %s 2> %s',                                  -- Input file at the end
        config.llama_cpp_path,
        config.model_path,
        config.temp,
        config.context_window,
        config.num_threads,
        config.top_p,
        config.mirostat,
        config.response_size,
        tmp_prompt,
        response_file,
        config.command_debug_output
    )

    self.logger:debug("Executing command", { command = command })
    local success = os.execute(command)

    if not success then
        self.logger:error("Command execution failed")
        return nil_or_empty_response
    end

    local response = ""
    local response_handle = io.open(response_file, "r")
    if response_handle then
        local content = response_handle:read("*a")
        response_handle:close()
        response = content
    end

    os.remove(tmp_prompt)
    os.remove(response_file)
    self.logger:debug("Command execution completed", { response = response })

    if response == nil or response == '' then
        self.logger:error("The result is nil or empty")
        return nil_or_empty_response
    end
    local parser_result = self.parser:cleanModelOutput(response)
    self.logger:debug("Parse result ", { result = parser_result })
    return parser_result
end

function Runner:updateChatContext(role, content)
    table.insert(self.chat_context.messages, {
        role = role,
        content = content
    })

    while #self.chat_context.messages > self.chat_context.max_messages do
        table.remove(self.chat_context.messages, 1)
    end
end

function Runner:buildChatHistory()
    local history = ""
    for _, msg in ipairs(self.chat_context.messages) do
        if msg.role == user_key then
            history = history .. "User:" .. msg.content .. "\n"
        else
            history = history .. "Assistant: " ..msg.content
        end
    end
    return history
end

function Runner.clearModelCache(self)
    os.remove(cache_prompt_path)
    self.chat_context = self:createNewChatContext()
end

function Runner.talkWithModel(self, message)
    self.logger:debug("New query to the model ", { query = message })

    local current_chat_history = self:buildChatHistory()
    local dynamic_prompt = ""
    local context_file = ""
    local chat_history = ""

    if current_chat_history ~= "" then
        chat_history = "Chat History:\n" .. current_chat_history .. "\nEnd History"
    end

    if self.is_file_context_available then
        context_file = "Current open file code:\n```text\n" .. self.current_raw_file .. "\n```\nEnd File"
    end

    if self.pairing_session.running then
        dynamic_prompt = string.format(prompts.pairing, self.pairing_session.feature, context_file, chat_history, message)
    else
        dynamic_prompt = string.format(prompts.chat, context_file, chat_history, message)
    end

    self:updateChatContext(user_key, message)

    self.logger:debug("Full prompt", { prompt = dynamic_prompt })
    local success, result = pcall(self.runLocalModel, self, dynamic_prompt, self.model_parameters)

    if success then
        self:updateChatContext(assistant_key, result)
        return true, result
    else
        local error_path = self.logger:getConfig().directory
        self.logger:error("An error happen when we try to execute the function run_local_model ", { error = result })
        self.logger:debug("Formatting error message to render on UI")
        local error_message = string.format(
            error_message_template,
            tostring(result),
            self.config.model_path,
            self.config.llama_cpp_path,
            error_path)
        self.logger:debug("Error message to show ", { error_message = error_message })
        return false, error_message
    end
end

function Runner.updateCurrentFileContent(self, content, amount_of_lines)
    if content == nil or content == "" then
        self.is_file_context_available = false
    end
    if amount_of_lines <= 300 then
        self.current_raw_file = content
        self.is_file_context_available = true
    else
        self.logger:debug("File to long to load")
        self.is_file_context_available = false
    end
end

function Runner.initPairingSession(self, feature_description)
    self:clearModelCache()

    self.pairing_session.running = true
    self.pairing_session.feature = feature_description
end

function Runner.endPairingSession(self)
    self:clearModelCache()

    self.pairing_session.running = false
end

function Runner.runStandardQuery(self, language, context, query)
    if context == nil then
        error("Code to analyze can not be nil")
    end
    if language == nil then
        error("Language of the code to analyze can not be nil")
    end
    self:clearModelCache()
    local full_query = string.format(query, language, context)
    return self:talkWithModel(full_query)
end

return Runner
