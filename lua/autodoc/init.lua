local ModelData = {}

ModelData.config = {
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
    }
}

local function extract_function_context()
    local line = vim.fn.line('.')
    local lines = vim.api.nvim_buf_get_lines(0, math.max(0, line - 5), line + 5, false)
    return table.concat(lines, '\n')
end

local function run_local_model(context, language)
    local prompt = string.format([[
    Generate brief documentation for this %s function.
    Include: parameters and return type.
    Context:
    %s
    Keep it concise.
    ]], language, context)

    local tmp_prompt = os.tmpname()
    local f = io.open(tmp_prompt, 'w')
    f:write(prompt)
    f:close()

    local command = string.format(
    '%s -m %s --temp 0.1 --ctx-size %d --threads %d -p "%s" -n 128',
    ModelData.config.llama_cpp_path,
    ModelData.config.model_path,
    ModelData.config.context_window,
    ModelData.config.num_threads,
    prompt
    )

    local handle = io.popen(command)
    local result = handle:read('*a')
    handle:close()
    os.remove(tmp_prompt)

    return result
end

local function insert_documentation(doc_text, language)
    local lang_config = ModelData.config.supported_languages[language]
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

function ModelData.generate_doc()
    local language = vim.bo.filetype
    if not ModelData.config.supported_languages[language] then
        print("Language not supported: " .. language)
        return
    end

    local context = extract_function_context()
    local doc = run_local_model(context, language)
    insert_documentation(doc, language)
end

function ModelData.setup(opts)
    local default_settings = {
        model_path = vim.fn.expand('/Users/agustinallamanocosta/repo/personal/AI/models/tinyLlama'),
        llama_cpp_path = vim.fn.expand('~/.local/bin/llama/llama-cli'),
        context_window = 512,
        memory_limit = "512MB",
        num_threads = 4
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

    ModelData.config = vim.tbl_deep_extend('force', ModelData.config, default_settings, opts or {})

    vim.api.nvim_create_user_command('AutoDoc', function()
        ModelData.generate_doc()
    end, {})
end

return ModelData
