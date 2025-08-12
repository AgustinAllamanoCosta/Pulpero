local prompts = require("prompts")
local json = require("JSON")
local Router = {}
local user_key = "User"
local error_file_permission = "Error to run the router, can not write the file for the temp prompt"

function Router.new(config, logger, model_runner, tool_manager)
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

    self.tool_manager = tool_manager
    self.model_runner = model_runner
    self.config = config
    self.logger = logger
    self.chat_context = self:create_new_chat_context()
    self.file_context_data = nil
    return self
end

function Router:create_new_chat_context()
    return {
        messages = {},
        max_messages = 8,
        current_tokens = 0,
        max_tokens = self.config.context_window
    }
end

-- PIPELINE SECTION

function Router:route(user_message, file_context_data)
    self.file_context_data = file_context_data

    -- detect when a topic change and switch context or clean the cache
    local intention = self:detect_intention(user_message):gsub("%s+", ""):gsub("\n", "")
    local response = "No pipeline category found"

    if intention == "file_operations" then
        response = self:file_pipeline(user_message)
    elseif intention == "web_research" then
        response = self:web_research_pipeline(user_message)
    elseif intention == "code_analysis" then
        response = self:code_analysis_pipeline(user_message)
    elseif intention == "general_chat" then
        response = self:general_chat_pipeline(user_message)
    elseif intention == "workflow" then
        response = self:workflow_pipeline(user_message)
    end
    return response
end

function Router:detect_intention(user_message)
    local complete_prompt = string.format(prompts.intent_prompt, self:generate_chat_history(), user_message)
    local prompt_file = self:generate_prompt_file(complete_prompt)
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
        self:generate_tools_description(),
        self:generate_chat_history(),
        user_message
    )
    local prompts_file = self:generate_prompt_file(full_prompt)
    local model_response_with_tool_call = self.model_runner:talk_with_model(prompts_file)

    local tool_calls = self:parse_tool_calls(model_response_with_tool_call)
    local tool_response = ""
    if #tool_calls > 0 then
        tool_response = self:process_tool_calls(tool_calls, model_response_with_tool_call)
    else
        tool_response = model_response_with_tool_call
    end

    self:update_chat_context('User', user_message)

    local final_response_prompt = string.format(prompts.generate_final_response, user_message, tool_response)
    local final_prompts_file = self:generate_prompt_file(final_response_prompt)
    local final_response = self.model_runner:talk_with_model(final_prompts_file)
    self:update_chat_context('Assistant', final_response)

    return final_response
end

function Router:web_research_pipeline(user_message)
    local final_response = "PIPELINE NOT IMPLEMENTED YET"
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
        self:generate_tools_description(),
        self:generate_chat_history(),
        user_message
    )
    local prompts_file = self:generate_prompt_file(full_prompt)
    local model_response_with_tool_call = self.model_runner:talk_with_model(prompts_file)

    local tool_calls = self:parse_tool_calls(model_response_with_tool_call)
    local tool_response = ""
    if #tool_calls > 0 then
        self.logger:debug()
        tool_response = self:process_tool_calls(tool_calls, model_response_with_tool_call)
    else
        tool_response = model_response_with_tool_call
    end

    self:update_chat_context('User', user_message)

    local final_response_prompt = string.format(prompts.generate_final_response, user_message, tool_response)
    local final_prompts_file = self:generate_prompt_file(final_response_prompt)
    final_response = self.model_runner:talk_with_model(final_prompts_file)
    self:update_chat_context('Assistant', final_response)

    return final_response
end

function Router:general_chat_pipeline(user_message)
    local file_context_data_str = string.format(
        "Current working dir: %s\n Open file name: %s\n Open file dir path: %s\n",
        self.file_context_data.current_working_dir,
        self.file_context_data.current_file_name,
        self.file_context_data.current_file_path
    )
    local chat_history = self:generate_chat_history()
    local full_prompt = string.format(prompts.chat, file_context_data_str, chat_history, user_message)
    local prompts_file = self:generate_prompt_file(full_prompt)

    self:update_chat_context('User', user_message)
    local final_response = self.model_runner:talk_with_model(prompts_file)
    self:update_chat_context('Assistant', final_response)
    return final_response
end

function Router:workflow_pipeline(user_message)
    local final_response = "PIPELINE NOT IMPLEMENTED YET"
    return final_response
end

-- GENERATE PROMPT FILE

function Router:generate_prompt_file(prompt)
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

function Router:clear_model_cache()
   self.chat_context = self:create_new_chat_context()
end

-- CHAT HISTORY SECTION

function Router:update_chat_context(role, content)
    table.insert(self.chat_context.messages, {
        role = role,
        content = content
    })

    while #self.chat_context.messages > self.chat_context.max_messages do
        table.remove(self.chat_context.messages, 1)
    end
end

function Router:build_chat_history()
    local history = ""
    for _, msg in ipairs(self.chat_context.messages) do
        if msg.role == user_key then
            history = history .. "User:" .. msg.content .. "\n"
        else
            history = history .. "Assistant: " .. msg.content
        end
    end
    return history
end

function Router:generate_chat_history()
    local current_chat_history = self:build_chat_history()
    local chat_history = ""

    if current_chat_history ~= "" then
        chat_history = "Chat History:\n" .. current_chat_history .. "\nEnd History"
    end
    return chat_history
end

-- TOOL CALL SECTION

function Router:generate_tools_description()
    local tool_descriptions = ""
    local tools = self.tool_manager:get_tool_descriptions()
    if #tools > 0 then
        for _, tool in ipairs(tools) do
            tool_descriptions = tool_descriptions .. string.format(
                "\n- Tool Name: \"%s\"\nDescription: \"%s\"\nCall Example: \"%s\"\n",
                tool.name,
                tool.description,
                tool.call_example
            )
        end
    end
    return tool_descriptions
end

function Router:parse_tool_calls(model_output)
    local tool_calls = {}

    for tool_name, params_str in model_output:gmatch("<tool%s+name=\"(.*)\"%s+params=\"(.*)\"%s+/>") do
        local params = {}
        for param, value in params_str:gmatch("([^=,]+)=([^,]+)") do
            params[param] = value
        end

        table.insert(tool_calls, {
            name = tool_name,
            params = params
        })
    end

    return tool_calls
end

function Router:process_tool_calls(tool_calls, prompt)
    for _, tool_call in ipairs(tool_calls) do
        self.logger:debug("Processing tool call", { tool = tool_call.name })

        local tool_result = self.tool_manager:execute_tool(tool_call.name, tool_call.params)

        local result_str
        if tool_result.success then
            result_str = string.format(
                "\nTool Result\nname: \"%s\"\nsuccess:\"true\"\nresult:\n\"%s\"",
                tool_call.name,
                json.encode(tool_result.result)
            )
        else
            result_str = string.format(
                "\nTool Result\nname: \"%s\"\nsuccess: \"false\"\nerror:\"%s\"",
                tool_call.name,
                tool_result.error
            )
        end

        local pattern = string.format("<tool name=\"%s\" params=\".*\" />", tool_call.name)
        prompt = prompt:gsub(pattern, result_str)
    end

    return prompt
end

return Router
