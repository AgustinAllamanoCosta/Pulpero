local Pairing = {}

function Pairing.new(ui, runner, config)
    local self               = setmetatable({}, { __index = Chat })
    self.ui                  = ui
    self.config              = config
    self.modal_open           = false
    self.runner              = runner

    local keymap_opts        = { noremap = true, silent = false }
    vim.api.nvim_buf_set_keymap(self.ui.input_buf, 'i', '<CR>',
        '<Esc>:PulperoSubmitFeatDescription<CR>',
        keymap_opts)
    return self
end
function Pairing.open(self)
    if self.modal_open then self:close() end

    if self.ui.desc_win then
        self.ui:open_feat_desc_input()
    else
        self.ui:create_desc_box()
    end
    self.modal_open = true
end

function Pairing.submit_description(self)
    local message = vim.api.nvim_buf_get_lines(self.ui.desc_input, 0, -1, false)[1]

    if message and message ~= "" then
        vim.api.nvim_buf_set_lines(self.ui.desc_input, 0, -1, false, { "" })
        vim.schedule(function()
            local success, response = self.runner:initPairingSession(message)
        end)
    end
    self:close()
end

function Pairing.close(self)
    if self.modal_open == true then
        self.ui:close_desc()
        self.modal_open = false
    end
end

return Pairing
