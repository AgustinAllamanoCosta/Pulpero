local Runner = {}
local OSCommands = require('util.OSCommands')
local prompts = require("prompts")
local nil_or_empty_response =  "It's looks like there is a problem with the answer generated by the model, try with another function or in a different line."
local error_file_permission = "Error to run the model, can not write the file for the temp prompt"

local error_message_template = [[
An error occurred while analyzing the code:
Error: %s

Possible solutions:
- Check if the model path is correct (%s)
- Ensure llama-cli is properly installed (%s)
- Verify the function context is valid
- Check if the language is supported

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
    self.config = config
    self.logger = logger
    self.parser = parser
    self.command_path = logger:getConfig().command_path
    return self
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

function Runner.runLocalModel(self, context, language, prompt)
    self.logger:debug("Configuration ",self.config)
    if context == nil then
        error("Code to analyze can not be nil")
    end
    if language == nil then
        error("Language of the code to analyze can not be nil")
    end

    if #context > self.config.context_window then
        return "The code is to large to be analyze, try with a small section"
    end

    self.logger:debug("Starting function explanation", {
        language = language,
        context_length = #context
    })
    local full_prompt = string.format(prompt, language, context)

    self.logger:debug("Generated prompt", {prompt = full_prompt})
    local tmp_prompt = self:generatePromptFile(full_prompt)

    self.logger:debug("Formatting command to execute")
    local command = string.format(
    '%s -m %s --temp %s -f %s -n 3072 --ctx-size %d --threads %s --top_p %s --rope-scaling "linear" --rope-freq-base 10000 2>>%s',
    self.config.llama_cpp_path,
    self.config.model_path,
    self.config.temp,
    tmp_prompt,
    self.config.context_window,
    self.config.num_threads,
    self.config.top_p,
    self.command_path)

    self.logger:debug("Executing command", {command = command})
    local success, exit_type, exit_code = OSCommands:executeCommand(command)

    self.logger:debug("Command execution completed", {
        success = success,
        exit_type = exit_type,
        exit_code = exit_code
    })
    os.remove(tmp_prompt)

    if success == nil or success == ''then
        self.logger:error("The result is nil or empty")
        return nil_or_empty_response
    end

    self.logger:debug("Parsing result", { result = success })
    local result = self.parser:cleanModelOutput(success)

    if result == nil or result == ''then
        self.logger:error("Parser return nil or ''")
        return nil_or_empty_response
    end

    self.logger:debug("Parse result", {
        cleaned_length = #result,
        result = result
    })
    return result
end

function Runner.processResult(self, success, result)
    if success then
        return true, result
    else
        local error_path  = self.logger:getConfig().directory
        self.logger:error("An error happen when we try to execute the function run_local_model ", { error = result })
        self.logger:debug("Formatting error message to render on UI")
        local error_message = string.format(
        error_message_template,
        tostring(result),
        self.config.model_path,
        self.config.llama_cpp_path,
        error_path)
        self.logger:debug("Error message to show ", { error_message = error_message })
        return false ,error_message
    end
end

function Runner.explain_function(self, language, context)
    local success, result = pcall(self.runLocalModel, self, context, language, prompts.explain_prompt)
    return self:processResult(success, result)
end

function Runner.refactor_function(self, language, context)
    local success, result = pcall(self.runLocalModel, self, context, language, prompts.refactor_prompt)
    return self:processResult(success, result)
end

return Runner
