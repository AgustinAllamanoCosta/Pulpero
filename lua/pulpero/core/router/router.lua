local prompts = require("prompts")
local Router = {}

function Router.new(config, logger, model_runner, tool_manager, history)
    local self = setmetatable({}, { __index = Router })
    if config == nil then
        error("Router config is nil")
    end
    if logger == nil then
        error("Router logger is nil")
    end
    if model_runner == nil then
        error("Router model runner is nil")
    end
    if tool_manager == nil then
        error("Router tool manager is nil")
    end
    if history == nil then
        error("Router history manager is nil")
    end

    self.history = history
    self.tool_manager = tool_manager
    self.model_runner = model_runner
    self.config = config
    self.logger = logger
    self.file_context_data = nil

    return self
end

function Router:route(user_message, file_context_data)
    self.file_context_data = file_context_data

    -- detect when a topic change and switch context or clean the cache
    -- Add some basic security check of prompt leaking
    local intention = self:detect_intention(user_message):gsub("%s+", ""):gsub("\n", "")
    local response = "No pipeline category found"

    if intention == "file_operations" then
        response = self:file_pipeline(user_message)
    elseif intention == "code_analysis" then
        response = self:code_analysis_pipeline(user_message)
    elseif intention == "general_chat" then
        response = self:general_chat_pipeline(user_message)
    end

    return response
end

function Router:detect_intention(user_message)
    local complete_prompt = string.format(prompts.intent_prompt, self.history:generate_chat_history(), user_message)
    local prompt_file = prompts:generate_prompt_file(complete_prompt)
    local model_response = self.model_runner:talk_with_model(prompt_file)
    os.remove(prompt_file)
    return model_response
end

function Router:file_pipeline(user_message)
    local file_context_data_str = string.format(
        "Current working dir: %s\n Open file name: %s\n Open file dir path: %s\n",
        self.file_context_data.current_working_dir,
        self.file_context_data.current_file_name,
        self.file_context_data.current_file_path
    )

    local full_prompt = string.format(
        prompts.file_operation,
        file_context_data_str,
        self.tool_manager:generate_tools_description(),
        self.history:generate_chat_history(),
        user_message
    )
    local prompts_file = prompts:generate_prompt_file(full_prompt)
    local model_response_with_tool_call = self.model_runner:talk_with_model(prompts_file)

    local tool_response = self.tool_manager:execute_tool_if_exist_call(model_response_with_tool_call)
    self.history:update_chat_context_as_user(user_message)

    local final_response_prompt = string.format(prompts.generate_final_response, user_message, tool_response)
    local final_prompts_file = prompts:generate_prompt_file(final_response_prompt)
    local final_response = self.model_runner:talk_with_model(final_prompts_file)
    self.history:update_chat_context_as_assistant(final_response)

    return final_response
end

function Router:code_analysis_pipeline(user_message)
    local file_context_data_str = string.format(
        "Current working dir: %s\n Open file name: %s\n Open file dir path: %s\n",
        self.file_context_data.current_working_dir,
        self.file_context_data.current_file_name,
        self.file_context_data.current_file_path
    )

    local final_response = ""
    local full_prompt = string.format(
        prompts.code,
        file_context_data_str,
        self.tool_manager:generate_tools_description(),
        self.history:generate_chat_history(),
        user_message
    )
    local prompts_file = prompts:generate_prompt_file(full_prompt)
    local model_response_with_tool_call = self.model_runner:talk_with_model(prompts_file)

    local tool_response = self.tool_manager:execute_tool_if_exist_call(model_response_with_tool_call)

    self.history:update_chat_context_as_user(user_message)

    local final_response_prompt = string.format(prompts.generate_final_response, user_message, tool_response)
    local final_prompts_file = prompts:generate_prompt_file(final_response_prompt)
    final_response = self.model_runner:talk_with_model(final_prompts_file)
    self.history:update_chat_context_as_assistant(final_response)

    return final_response
end

function Router:general_chat_pipeline(user_message)
    local file_context_data_str = string.format(
        "Current working dir: %s\n Open file name: %s\n Open file dir path: %s\n",
        self.file_context_data.current_working_dir,
        self.file_context_data.current_file_name,
        self.file_context_data.current_file_path
    )

    local chat_history = self.history:generate_chat_history()
    local full_prompt = string.format(prompts.chat, file_context_data_str, chat_history, user_message)
    local prompts_file = prompts:generate_prompt_file(full_prompt)

    self.history:update_chat_context_as_user(user_message)
    local final_response = self.model_runner:talk_with_model(prompts_file)
    self.history:update_chat_context_as_assistant(final_response)

    return final_response
end

return Router
