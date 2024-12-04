local Parser = {}

function Parser.new(config)
    local self = setmetatable({}, { __index = Parser })
    self.config = config
    return self
end

function Parser.get_visual_selection(self)
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

return Parser
