ModelManager = require('model_manager')
Setup = require('setup')
Server = require('server')
Methods = require('methods')
Logger = require('logger')
OSCommands = require('OSCommands')

logger = nil
setup = nil
server = nil
methods = nil
config = nil
logger_config = nil
model_manager = nil
model_name = "deepseek-coder-v2-lite-instruct.gguf"
current_os = OSCommands:get_platform()

default_settings = {
    context_window = 1024,
    temp = "0.1",
    num_threads = "4",
    top_p = "0.4",
    model_name = model_name,
    model_path = OSCommands:create_path_by_OS(OSCommands:get_model_dir(), model_name),
    llama_repo = "https://github.com/ggerganov/llama.cpp.git",
    os = OSCommands:get_platform(),
    pulpero_ready = false,
    response_size = "1024"
}

def initialize_logger(param_logger)
    if not param_logger then
        logger = Logger.new("service", true)
        logger:clear_logs()
        logger_config = logger:get_config()
        logger:setup("Configuration logger", logger_config)
    else
        logger = param_logger

def initialize_service(logger)
    logger:debug("Initialize service dependencies")
    model_manager = ModelManager.new(logger, default_settings)
    logger:debug("Init Setup")
    setup = Setup.new(logger, model_manager, default_settings)
    logger:debug("Configuration plugin")
    config = setup:configure_plugin()
    logger:setup("Service starting on OS: " .. current_os)
    logger:setup("Configuration ", config)
    logger:debug("Finish service initialization")
    methods = Methods.new(logger, model_manager, setup)
    server = Server.new(logger, model_manager, methods)
    server:start()
    return config

initialize_logger(logger)
initialize_service(logger)
