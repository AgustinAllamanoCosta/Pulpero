local VirtualText = {}

function VirtualText.new()
    local self = setmetatable({}, { __index = VirtualText })
    self.namespace = vim.api.nvim_create_namespace('pulpero_feedback')
    self.active_feedback = {}
    return self
end

function VirtualText:show_at_line(response, line_number)
    local bufnr = vim.api.nvim_get_current_buf()

    local vir_text = {}
    for line in string.gmatch(response, "[^\n]+") do
        table.insert(vir_text, { { line, "Comment" } })
    end

    local virt_text_opts = {
        id = math.random(1000000),
        priority = 50,
        hl_mode = "blend",
        virt_lines_leftcol = false,
        virt_lines = vir_text,
        sign_text = "🦶"
    }

    vim.api.nvim_buf_set_extmark(bufnr, self.namespace, line_number, 0, virt_text_opts)

    table.insert(self.active_feedback, {
        bufnr = bufnr,
        line = line_number,
        id = virt_text_opts.id,
        type = "Completion",
        timestamp = os.time()
    })
end

function VirtualText:clear_all()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, self.namespace, 0, -1)

    for i = #self.active_feedback, 1, -1 do
        if self.active_feedback[i].bufnr == bufnr then
            table.remove(self.active_feedback, i)
        end
    end
end

return VirtualText
