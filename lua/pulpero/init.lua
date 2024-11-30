local Runner = require('pulpero.model_runner')

local PluginData = {}
PluginData.config = {}
local runner = nil

function PluginData.setup(opts)
    local default_settings = {
        model_path = vim.fn.expand('/Users/agustinallamanocosta/repo/personal/AI/models/tinyLlama'),
        llama_cpp_path = vim.fn.expand('~/.local/bin/llama/llama-cli'),
        context_window = 512,
        temp = 0.1,
        num_threads = 4,
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

    local success, handle = pcall(io.popen, 'free -m | grep Mem: | awk \'{print $2}\'')
    if success and handle then
        local total_mem = tonumber(handle:read('*a'))
        handle:close()
        -- Adjust settings based on available memory
        if total_mem and total_mem < 4096 then -- Less than 4GB RAM
            default_settings.context_window = 256
            default_settings.num_threads = 2
        elseif total_mem and total_mem < 8192 then -- Less than 8GB RAM
            default_settings.context_window = 512
            default_settings.num_threads = 4
        else -- 8GB or more RAM
            default_settings.context_window = 1024
            default_settings.temp = 0.7
            default_settings.num_threads = 6
        end
    end

    PluginData.config = vim.tbl_deep_extend('force', PluginData.config, default_settings, opts or {})

    runner = Runner.new(PluginData.config)

    vim.api.nvim_create_user_command('ExpFn', function()
        runner:explain_function()
    end, {})
end

return PluginData
