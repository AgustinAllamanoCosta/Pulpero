local Methods = {}
local Runner = require('runner.model.model_runner')
local ToolManager = require('managers.tool.manager')
local Parser = require('runner.model.parser')
local uv = require('luv')

function Methods.new(logger, model_manager)
    local self = setmetatable({}, { __index = Methods })
    self.logger = logger
    self.model_manager = model_manager
    self.runner = nil
    return self
end

function Methods.service_is_ready(self)
    self.logger:debug("checking if the service is ready")
    local status = self.model_manager:get_status_from_file()
    self.logger:debug("Model status ", { status })
    if status == "completed" then
        self.logger:debug("Service download status is completed")
        if self.enable then
            self.logger:debug("Service is enable")
            return true
        else
            self.logger:debug("The machine spirit is sleeping", { enable = self.enable })
            return false
        end
    else
        self.logger:debug("The machine spirit is not ready yet")
        return false
    end
end

function Methods.adapter(self, request)
    local response = {
        requestId = request.id,
        result = nil,
        error = nil
    }
    local method = request.method
    if method == "talk_with_model" then
        response = self:execute(function()
            return self.runner.talk_with_model(request.params.message)
        end, response, method)
    elseif method == "prepear_env" then
        response = self:execute(function()
            local config = self.setup:prepear_env()
            local tool_manager = ToolManager.new(self.logger)
            local parser = Parser.new(self.logger)
            self.runner = Runner.new(config, self.logger, parser, tool_manager)
            return true
        end, response, method)
    elseif method == "clear_model_cache" then
        response = self:execute(function()
            self.runner:clear_model_cache()
            return true
        end, response, method)
    elseif method == "get_download_status" then
        response = self:execute(function()
            return self.model_manager:get_download_status()
        end, response, method)
    elseif request.method == "get_service_status" then
        response = self:execute(function()
            local status = self.model_manager:get_status_from_file()
            return {
                running = true,
                model_ready = self:service_is_ready(),
                download_status = status,
                pid = uv.os_getpid()
            }
        end, response, method)
    elseif request.method == "toggle" then
        self.enable = not self.enable
        response.result = self.enable
    else
        response.error = "Unknown method: " .. (request.method or "nil")
    end
    return response
end

function Methods.execute(self, callback, response, name)
    if self:service_is_ready() then
        local success, result = pcall(callback)
        if success then
            response.result = result
        else
            self.logger:error("Something went wrong when executing" .. name)
            self.logger:error("Error: ", result)
            response.result = false
            response.error = result
        end
    else
        self.logger:debug("service is not ready yet to " .. name)
        response.result = false
        response.error = "Service not ready - model still loading"
    end
    return response
end

return Methods
