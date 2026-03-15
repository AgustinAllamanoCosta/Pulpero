local VirtualText = {}

function VirtualText.new()
    local self = setmetatable({}, { __index = VirtualText })
    self.namespace = vim.api.nvim_create_namespace('pulpero_feedback')
    self.active_feedback = {}
    return self
end

function VirtualText:show_at_line(response, line_number)
    local bufnr = vim.api.nvim_get_current_buf()
    local win_width = vim.opt.columns:get()

    local line_content = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
    local virt_text_opts = {
        id = math.random(1000000),
        virt_text = {},
        virt_text_pos = "eol",
        sign_text = "🦶"
    }

    if line_content ~= nil and #line_content + #response > win_width then
        local available_room = win_width - #line_content
        for i = 0, math.floor(#response / available_room), 1 do
            local final_line_number = line_number + i
            local offset = available_room * i
            virt_text_opts.virt_text = { { string.sub(response, offset, available_room + offset), "Comment" } }

            vim.api.nvim_buf_set_extmark(bufnr, self.namespace, final_line_number, 0, virt_text_opts)
            table.insert(self.active_feedback, {
                bufnr = bufnr,
                line = final_line_number,
                id = virt_text_opts.id,
                timestamp = os.time()
            })

            virt_text_opts.id = math.random(1000000)
            virt_text_opts.sign_text = ""
        end
    else
        virt_text_opts.virt_text = { { response, "Comment" } }
        vim.api.nvim_buf_set_extmark(bufnr, self.namespace, line_number, 0, virt_text_opts)
        table.insert(self.active_feedback, {
            bufnr = bufnr,
            line = line_number,
            id = virt_text_opts.id,
            timestamp = os.time()
        })
    end
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
