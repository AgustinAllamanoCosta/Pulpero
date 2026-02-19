import asyncio
from pathlib import Path
import platform
from core.managers.model.manager import ModelManager
from core.runner.model.model_runner import RunnerConfig
from core.server.methods import Methods
from core.server.socket_server import Server
from core.server.setup import Setup
from core.util.OSCommands import OSCommands
from core.util.logger import Logger

global model_name
global clasi_model_name
global tool_model_name
model_name: str = "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
code_model_name: str = "qwen2.5-coder-7b-instruct-q4_k_m.gguf"
clasi_model_name: str = "Llama-3.2-3B-Instruct-uncensored-IQ4_XS.gguf"
tool_model_name: str = "Llama-3.2-3B-Instruct-uncensored-IQ4_XS.gguf"

async def initialize_service(logger: Logger) -> RunnerConfig:
    logger.debug("Initialize service dependencies")
    model_manager = ModelManager(logger, default_settings)
    logger.info("Init Setup")
    setup = Setup(logger, model_manager, default_settings, default_clasi_model_settings, default_tool_model_settings, default_code_model_settings)
    logger.info("Configuration plugin")
    config = setup.configure_plugin()
    logger.setup(f"Service starting on OS: { platform.system() }")
    logger.setup("Configuration ", config)
    logger.info("Finish service initialization")
    methods = Methods(logger, model_manager, setup)
    server = Server(logger, methods)
    await server.start()
    return config

if __name__ == "__main__":

    default_settings: RunnerConfig = RunnerConfig(
        context_window = 2048,
        temp = 0.5,
        num_threads = -1,
        top_p = 0.4,
        model_name = model_name,
        model_path = str(Path(OSCommands.get_model_dir()) / model_name),
        os = platform.system(),
        response_size = 1024
    )

    default_code_model_settings: RunnerConfig = RunnerConfig(
        context_window = 2048,
        temp = 0.5,
        num_threads = -1,
        top_p = 0.4,
        model_name = code_model_name,
        model_path = str(Path(OSCommands.get_model_dir()) / code_model_name),
        os = platform.system(),
        response_size = 1024
    )

    default_clasi_model_settings: RunnerConfig = RunnerConfig(
        context_window = 2048,
        temp = 0.2,
        num_threads = -1,
        top_p = 0.4,
        model_name = clasi_model_name,
        model_path = str(Path(OSCommands.get_model_dir()) / clasi_model_name),
        os = platform.system(),
        response_size = 1024
    )

    default_tool_model_settings: RunnerConfig = RunnerConfig(
        context_window = 4096,
        temp = 0.5,
        num_threads = -1,
        top_p = 0.65,
        model_name = tool_model_name,
        model_path = str(Path(OSCommands.get_model_dir()) / tool_model_name),
        os = platform.system(),
        response_size = 512
    )

    new_logger = Logger("Server", True)
    new_logger.clear_logs()
    logger_config = new_logger.get_config()
    new_logger.setup("Configuration logger", logger_config)
    asyncio.run(initialize_service(new_logger))
