local Logger = {}
local PluginData = {}

PluginData.config = {
    supported_languages = {
        python = true,
        javascript = true,
        typescript = true,
        typescriptreact = true,
        lua = true,
        java = true,
        cpp = true
    },
    logs = {
        directory = "/tmp",
        debug_file = "autodoc_debug.log",
        error_file = "autodoc_error.log"
    }
}

function Logger.new(config)
    local self = setmetatable({}, { __index = Logger })
    self.debug_path = string.format("%s/%s", config.directory, config.debug_file)
    self.error_path = string.format("%s/%s", config.directory, config.error_file)
    return self
end

function Logger.clear_logs(self)
    local debug_file = io.open(self.debug_path, "w")
    if debug_file then
        debug_file:write("=== New Debug Session Started ===\n")
        debug_file:close()
    end

    local error_file = io.open(self.error_path, "w")
    if error_file then
        error_file:write("=== New Error Session Started ===\n")
        error_file:close()
    end
end

function Logger.debug(self, message, data)
    local debug_file = io.open(self.debug_path, "a")
    if debug_file then
        debug_file:write(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. message .. "\n")
        if data then
            debug_file:write("Data: " .. vim.inspect(data) .. "\n")
        end
        debug_file:write("----------------------------------------\n")
        debug_file:close()
    end
end

function Logger.error(self, error_text)
    local error_file = io.open(self.error_path, "a")
    if error_file then
        error_file:write(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. error_text .. "\n")
        error_file:write("----------------------------------------\n")
        error_file:close()
    end
end

local function extract_function_context()
    local line = vim.fn.line('.')
    local lines = vim.api.nvim_buf_get_lines(0, math.max(0, line - 5), line + 5, false)
    return table.concat(lines, '\n')
end

local function run_local_model(context, language)
    PluginData.logger:debug("Starting function explanation", {
        language = language,
        context_length = #context
    })

    local prompt = string.format([[<|im_start|>system
You are an expert programmer who excels at explaining code clearly and thoroughly. Analyze code and explain:
1. The main purpose of the function
2. How it works internally
3. Important patterns or techniques it uses
4. Any notable side effects or behaviors to be aware of
Keep explanations clear and thorough but concise.
<|im_end|>
<|im_start|>user
Explain this %s function's behavior and purpose:

%s
<|im_end|>
<|im_start|>assistant
]], language, context)

    PluginData.logger:debug("Generated prompt", {prompt = prompt})

    local tmp_prompt = os.tmpname()
    local f = io.open(tmp_prompt, 'w')

    f:write(prompt)
    f:close()

    local command = string.format(
        '%s -m %s --temp 0.1 -f %s -n 512 --top_p 0.2 2>>%s',
        PluginData.config.llama_cpp_path,
        PluginData.config.model_path,
        tmp_prompt,
        PluginData.config.logs.error_file
    )

    PluginData.logger:debug("Executing command", {command = command})

    local handle = io.popen(command)
    local result = handle:read("*a")
    local success, exit_type, exit_code = handle:close()

    PluginData.logger:debug("Command execution completed", {
        success = success,
        exit_type = exit_type,
        exit_code = exit_code
    })

    os.remove(tmp_prompt)

    result = result:gsub("<|im_start|>assistant", "")
    result = result:gsub("<|im_end|>", "")
    result = result:gsub("^%s+", "")

    PluginData.logger:debug("Processed result", {
        cleaned_length = #result
    })

    return result
end

local function show_explanation(text)
    local width = math.min(120, vim.o.columns - 4)
    local height = math.min(20, vim.o.lines - 4)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(text, '\n'))

    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded'
    }

    local win = vim.api.nvim_open_win(buf, true, opts)

    vim.api.nvim_win_set_option(win, 'wrap', true)
    vim.api.nvim_win_set_option(win, 'conceallevel', 2)

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {silent = true, noremap = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', {silent = true, noremap = true})
end

function PluginData.explain_function()
    local language = vim.bo.filetype
    if not PluginData.config.supported_languages[language] then
        print("Language not supported: " .. language)
        return
    end

    local context = extract_function_context()
    local explanation = run_local_model(context, language)
    show_explanation(explanation)
end

function PluginData.setup(opts)
    local default_settings = {
        model_path = vim.fn.expand('/Users/agustinallamanocosta/repo/personal/AI/models/tinyLlama'),
        llama_cpp_path = vim.fn.expand('~/.local/bin/llama/llama-cli'),
        context_window = 512,
        num_threads = 4,
        logs = {
            directory = "/tmp",
            debug_file = "autodoc_debug.log",
            error_file = "autodoc_error.log"
        }
    }

    local success, handle = pcall(io.popen, 'free -m | grep Mem: | awk \'{print $2}\'')
    if success and handle then
        local total_mem = tonumber(handle:read('*a'))
        handle:close()

        if total_mem and total_mem < 4096 then
            default_settings.context_window = 256
            default_settings.memory_limit = "256MB"
            default_settings.num_threads = 2
        end
    end
    PluginData.config = vim.tbl_deep_extend('force', PluginData.config, default_settings, opts or {})

    PluginData.logger = Logger.new(PluginData.config.logs)

    vim.api.nvim_create_user_command('AutoDoc', function()
        PluginData.logger:clear_logs()
        PluginData.explain_function()
    end, {})
end

return PluginData
