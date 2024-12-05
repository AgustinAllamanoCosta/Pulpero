local plugin_root = vim.fn.fnamemodify(vim.api.nvim_get_runtime_file("lua/pulpero/init.lua", false)[1], ":h:h:h:h")

local function require_core(module)
    local path = plugin_root .. "/core/" .. module .. ".lua"
    local chunk, err = loadfile(path)
    if not chunk then
        error("Could not load module " .. module .. ": " .. err)
    end
    return chunk()
end

local Runner = require_core('model_runner')
local Setup = require_core('setup')
local Logger = require_core('logger')
local Parser = require_core('parser')

local M = {}
local runner = nil
local parser = nil
local logger = nil
local setup = nil

local function get_visual_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local lines = vim.api.nvim_buf_get_lines(
        0,
        start_pos[2] - 1,  -- Convert from 1-based to 0-based indexing
        end_pos[2],
        false
    )

    if #lines == 0 then
        return nil
    end

    return table.concat(lines, "\n")
end

function M.setup()
    logger = Logger.new()
    logger:clear_logs()
    setup = Setup.new(logger)
    local config = setup:configure_plugin()
    setup:prepear_env()

    parser = Parser.new(config)
    runner = Runner.new(config, logger, parser)

    vim.api.nvim_create_user_command('ExpFn', function()
        M.explain_selection()
    end, {range = true})
end

function M.explain_selection()
    local selected_code = get_visual_selection()
    local filetype = vim.bo.filetype
    local success, result = runner:explain_function(selected_code, filetype)
    if success then
        require('pulpero.ui'):show_explanation(result)
    else
        require('pulpero.ui'):show_error(result)
    end
end

return M
