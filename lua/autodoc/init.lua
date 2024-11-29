local Logger = {}
local PluginData = {}

PluginData.config = {
    supported_languages = {
        python = {
            doc_style = '"""',
            indent = '    '
        },
        javascript = {
            doc_style = '/**',
            indent = '  '
        },
        typescript = {
            doc_style = '/**',
            indent = '  '
        },
        typescriptreact = {
            doc_style = '/**',
            indent = '  '
        },
        lua = {
            doc_style = '---',
            indent = '    '
        }
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
    PluginData.logger:debug("Starting documentation generation", {
        language = language,
        context_length = #context
    })
    local prompt = string.format([[Write a documentation comment for this %s function:

%s

Instructions:
1. Start with /** and end with */
2. Include @param for parameters
3. Include @returns for return value
4. Be brief and clear
5. Only output the documentation, nothing else
]], language, context)

    PluginData.logger:debug("Generated prompt", {prompt = prompt})

    local tmp_prompt = os.tmpname()
    local f = io.open(tmp_prompt, 'w')

    f:write(prompt)
    f:close()

    local command = string.format(
        '%s -m %s --temp 0.1 -f %s -n 256',
        PluginData.config.llama_cpp_path,
        PluginData.config.model_path,
        tmp_prompt
    )

    PluginData.logger:debug("Executing command", {command = command})

    local handle = io.popen(command .. " 2>/tmp/autodoc_error.log")
    local result = handle:read("*a")
    local success, exit_type, exit_code = handle:close()

    PluginData.logger:debug("Command execution completed", {
        success = success,
        exit_type = exit_type,
        exit_code = exit_code
    })

    local error_log = io.open("/tmp/autodoc_error.log", "r")
    if error_log then
        local errors = error_log:read("*a")
        error_log:close()
        debug_log("Error log contents", {errors = errors})
    end

    os.remove(tmp_prompt)

    PluginData.logger:debug("Raw model output", {output = result})

    local cleaned_result = result:match("(/[*][*].-[*]/)")
    if not cleaned_result then
        cleaned_result = result:match('(""".-""")')
    end

    PluginData.logger:debug("Cleaned output", {cleaned = cleaned_result or "No match found"})

    if not cleaned_result then
        return "/** \n * Documentation generation failed. Check /tmp/autodoc_debug.log for details \n */"
    end

    return cleaned_result
end

local function insert_documentation(doc_text, language)
    local lang_config = PluginData.config.supported_languages[language]
    if not lang_config then
        print("Language not supported for documentation")
        return
    end

    local current_line = vim.fn.line('.')
    local current_indent = vim.fn.indent(current_line)
    local indent_str = string.rep(lang_config.indent, math.floor(current_indent / #lang_config.indent))

    local formatted_doc = {}
    if lang_config.doc_style == '/**' then
        table.insert(formatted_doc, indent_str .. '/**')

        for line in doc_text:gmatch("[^\r\n]+") do
            table.insert(formatted_doc, indent_str .. ' * ' .. line)
        end

        table.insert(formatted_doc, indent_str .. ' */')
    else
        for line in doc_text:gmatch("[^\r\n]+") do
            table.insert(formatted_doc, indent_str .. lang_config.doc_style .. ' ' .. line)
        end
    end

    vim.api.nvim_buf_set_lines(0, current_line - 1, current_line - 1, false, formatted_doc)
end

function PluginData.generate_doc()
    local language = vim.bo.filetype
    if not PluginData.config.supported_languages[language] then
        print("Language not supported: " .. language)
        return
    end

    local context = extract_function_context()
    local doc = run_local_model(context, language)
    insert_documentation(doc, language)
end

function PluginData.setup(opts)
    local default_settings = {
        model_path = vim.fn.expand('/Users/agustinallamanocosta/repo/personal/AI/models/tinyLlama'),
        llama_cpp_path = vim.fn.expand('~/.local/bin/llama/llama-cli'),
        context_window = 512,
        memory_limit = "512MB",
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
        PluginData.generate_doc()
    end, {})
end

return PluginData
