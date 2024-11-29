local Logger = {}
local PluginData = {}
local UI = {}

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
        debug_file = "pulpero_debug.log",
        error_file = "pulpero_error.log"
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

local function clean_model_output(raw_output)
    raw_output = raw_output:gsub("<|im_start|>system.-<|im_start|>user.-purpose:", "")

    raw_output = raw_output:gsub("<|im_start|>", "")
    raw_output = raw_output:gsub("<|im_end|>", "")

    raw_output = raw_output:gsub("%[end of text%]", "")
    raw_output = raw_output:gsub("^%s+", "")
    raw_output = raw_output:gsub("%s+$", "")

    local sections = {
        "Purpose:",
        "Implementation:",
        "Patterns & Techniques:",
        "Notable Behaviors:"
    }

    local paragraphs = {}
    for para in raw_output:gmatch("[^\n]+") do
        if para:match("%S") then  -- Only keep non-empty paragraphs
            table.insert(paragraphs, para)
        end
    end

    local formatted_output = {}
    if #paragraphs >= 1 then
        table.insert(formatted_output, sections[1])
        table.insert(formatted_output, "  " .. paragraphs[1])
        table.insert(formatted_output, "")
    end

    if #paragraphs >= 2 then
        table.insert(formatted_output, sections[2])
        table.insert(formatted_output, "  " .. paragraphs[2])
        table.insert(formatted_output, "")
    end

    if #paragraphs >= 3 then
        table.insert(formatted_output, sections[3])
        table.insert(formatted_output, "  " .. paragraphs[3])
        table.insert(formatted_output, "")
    end

    if #paragraphs >= 4 then
        table.insert(formatted_output, sections[4])
        table.insert(formatted_output, "  " .. paragraphs[4])
    end

    return table.concat(formatted_output, "\n")
end

local function run_local_model(context, language)
    PluginData.logger:debug("Starting function explanation", {
        language = language,
        context_length = #context
    })

    local prompt = string.format([[<|im_start|>system
You are a code explanation expert. Analyze this code and provide a clear explanation with these sections:
1. Main purpose of the function
2. How it works internally
3. Important patterns or techniques it uses
4. Any notable behaviors or side effects

Format your response in clear paragraphs, one for each section.
<|im_end|>
<|im_start|>user
Explain this %s function:

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

    result = clean_model_output(result)

    PluginData.logger:debug("Processed result", {
        cleaned_length = #result
    })

    return result
end

function UI.create_loading_animation()
    local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local current_frame = 1
    local timer = nil
    local loading_buf = nil
    local loading_win = nil

    local function create_loading_window()
        loading_buf = vim.api.nvim_create_buf(false, true)

        local width = 30
        local height = 1
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

        loading_win = vim.api.nvim_open_win(loading_buf, false, opts)
        return loading_buf, loading_win
    end

    local function update_spinner()
        if loading_buf and vim.api.nvim_buf_is_valid(loading_buf) then
            vim.api.nvim_buf_set_lines(loading_buf, 0, -1, false,
                {string.format("  %s  Analyzing function...", frames[current_frame])})
            current_frame = (current_frame % #frames) + 1
        else
            if timer then
                timer:stop()
            end
        end
    end

    local function start()
        local buf, win = create_loading_window()
        timer = vim.loop.new_timer()
        timer:start(0, 100, vim.schedule_wrap(update_spinner))
        return buf, win
    end

    local function stop()
        if timer then
            timer:stop()
            timer:close()
        end
        if loading_win and vim.api.nvim_win_is_valid(loading_win) then
            vim.api.nvim_win_close(loading_win, true)
        end
        if loading_buf and vim.api.nvim_buf_is_valid(loading_buf) then
            vim.api.nvim_buf_delete(loading_buf, { force = true })
        end
    end

    return {
        start = start,
        stop = stop
    }
end

function UI.show_explanation(text)

    local width = math.min(120, vim.o.columns - 4)
    local min_height = 10
    local lines = vim.split(text, '\n')

    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end

    table.insert(lines, "")
    table.insert(lines, string.rep("─", width - 2))
    table.insert(lines, "Note: This explanation is AI-generated and should be verified for accuracy.")
    table.insert(lines, "Press 'q' or <Esc> to close this window.")

    local content_height = #lines
    local height = math.min(math.max(content_height, min_height), vim.o.lines - 4)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = ' Function Analysis ',
        title_pos = 'center'
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_win_set_option(win, 'wrap', true)
    vim.api.nvim_win_set_option(win, 'conceallevel', 2)

    local last_lines = #lines
    if last_lines > 2 then
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', last_lines - 1, 0, -1)
        pcall(vim.api.nvim_buf_add_highlight, buf, -1, 'Comment', last_lines, 0, -1)
    end

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', {silent = true, noremap = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', {silent = true, noremap = true})

    return buf, win
end

function PluginData.explain_function()
    local language = vim.bo.filetype
    if not PluginData.config.supported_languages[language] then
        print("Language not supported: " .. language)
        return
    end

    local loading = UI.create_loading_animation()
    loading.start()

    vim.schedule(function()
        local context = extract_function_context()
        local explanation = run_local_model(context, language)
        loading.stop()
        UI.show_explanation(explanation)
    end)
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

    vim.api.nvim_create_user_command('ExpFn', function()
        PluginData.logger:clear_logs()
        PluginData.explain_function()
    end, {})
end

return PluginData
