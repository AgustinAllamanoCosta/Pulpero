local Methods = {}
local Runner = require('model_runner')
local Router = require('router.router')
local History = require('history.manager')
local ToolManager = require('managers.tool.manager')
local tools = require('tools')
local Parser = require('parser')
local uv = require('luv')

function Methods.new(logger, model_manager, setup)
    local self = setmetatable({}, { __index = Methods })
    self.logger = logger
    self.model_manager = model_manager
    self.router = nil
    self.history = nil
    self.setup = setup
    self.is_ready = false
    self.enable = true
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
        response = self:execute(function(methods)

            local file_context_data = {}
            self.logger:debug("talk with model request ", request)

            if request.params.file_context_data == nil then
                file_context_data = {
                    current_working_dir = "",
                    current_file_name = "",
                    current_file_path = ""
                }
            else
                file_context_data = request.params.file_context_data
            end

            return methods.router:route(request.params.message, file_context_data)
        end, response, method)
    elseif method == "prepear_env" then
        local function prepear_env(methods)
            if not methods.is_ready then
                local config = methods.setup:prepear_env()

                local tool_manager = ToolManager.new(methods.logger)

                tool_manager:register_tool(tools.create_create_file_tool(methods.logger))
                tool_manager:register_tool(tools.create_get_file_tool(methods.logger))
                tool_manager:register_tool(tools.create_find_file_tool(methods.logger))

                local parser = Parser.new(methods.logger)
                local runner = Runner.new(config, methods.logger, parser)
                methods.history = History.new(nil)

                methods.router = Router.new(config, methods.logger, runner, tool_manager, methods.history)
                methods.is_ready = true
            end
            return methods.is_ready
        end
        local success, result = pcall(prepear_env, self)
        if success then response.result = result else response.error = result end
        return response
    elseif method == "clear_model_cache" then
        response = self:execute(function(methods)
            methods.history:clear()
            return true
        end, response, method)
    elseif method == "get_download_status" then
        response = self:execute(function(methods)
            return methods.model_manager:get_download_status()
        end, response, method)
    elseif request.method == "get_service_status" then
        response = self:execute(function(methods)
            local status = methods.model_manager:get_status_from_file()
            return {
                running = true,
                model_ready = methods:service_is_ready(),
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
        local success, result = pcall(callback, self)
        if success then
            response.result = result
        else
            self.logger:error("Something went wrong when executing " .. name)
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
