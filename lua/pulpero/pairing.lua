local Pairing = {}

function Pairing.new(ui, runner, config)
    local self               = setmetatable({}, { __index = Pairing })
    self.ui                  = ui
    self.config              = config
    self.modal_open           = false
    self.runner              = runner
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
    local keymap_opts        = { noremap = true, silent = false }
    vim.api.nvim_buf_set_keymap(self.ui.desc_buf, 'i', '<CR>',
        '<Esc>:PulperoSubmitFeatDescription<CR>',
        keymap_opts)
end

function Pairing.submit_description(self)
    local message = vim.api.nvim_buf_get_lines(self.ui.desc_buf, 0, -1, false)[1]

    if message and message ~= "" then
        vim.api.nvim_buf_set_lines(self.ui.desc_buf, 0, -1, false, { "" })
        self.runner:initPairingSession(message)
    end
    self:close()
end

function Pairing.endParingSession(self) 
    self.runner:endParingSession()
end

function Pairing.close(self)
    if self.modal_open == true then
        self.ui:close_desc()
        self.modal_open = false
    end
end

return Pairing
