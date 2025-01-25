local prompts = require "prompts"
local Runner = {}
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
    self.model_parameters = {
        repeat_penalty = "1.2",
        mirostat = "2",
        context_window = "4096",
        response_size = "512",
        temp = "0.2",
        top_p = "0.3",
        num_threads = self.config.num_threads,
        model_path = self.config.model_path,
        llama_cpp_path = self.config.llama_cpp_path,
        command_debug_output = logger:getConfig().command_path
    }
    return self
end

function Runner.createNewChatContext(self)
    return {
        messages = {},
        max_messages = 10,     -- Keep last 10 messages for context
        current_tokens = 0,
        max_tokens = 2048      -- Match your model's context window
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
        .. ' --prompt-cache prompt.bin'                           -- Cache the prompt for faster loading
        .. ' -ngl 1'                                              -- Use GPU for better performance
        .. ' -b 512'                                              -- Batch size for processing
        .. ' -r "User:" --in-prefix " " --in-suffix "Assistant:"' -- Better chat handling
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
        if msg.role == "user" then
            history = history .. "[INST] " .. msg.content .. " [/INST]"
        else
            history = history .. msg.content .. "</s>"
        end
    end
    return history
end

function Runner.clearModelCache(self)
    os.remove("./prompt.bin")
    self.chat_context = self:createNewChatContext()
end

function Runner.talkWithModel(self, message)
    self.logger:debug("New query to the model ", { query = message })
    self:updateChatContext("user", message)

    local chat_history = self:buildChatHistory()
    if self.current_file then
        local context = string.format("\nContext from current file:\n```\n%s\n```\n", self.current_file)
    end
    local dynamic_prompt = string.format(prompts.chat, chat_history)

    self.logger:debug("Full prompt", {prompt = dynamic_prompt})
    local success, result = pcall(self.runLocalModel, self, dynamic_prompt, self.model_parameters)

    if success then
        self:updateChatContext("assistant", result)
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

function Runner.updateCurrentFileContent(self, content)
    if content == nil or content == "" then
        return false
    end
    self.current_file_data = {}
    for file_line in string.gmatch(content, "(.-)%s*") do
        table.insert(self.current_file_data, { line = file_line, line_number = file_line:len() })
    end
    self.current_file = content
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

function Runner.explainFunction(self, language, context)
    local user_message = "Explain what this code does. Langua: %s Code: %s "
    return self:runStandardQuery(language, context, user_message)
end

function Runner.refactorFunction(self, language, context)
    local user_message = "Explain what this code does. Langua: %s Code: %s "
    return self:runStandardQuery(language, context, user_message)
end

function Runner.completeCode(self, language, context)
    return self:runStandardQuery(language, context, prompts.completiion_chat_template)
end

return Runner
