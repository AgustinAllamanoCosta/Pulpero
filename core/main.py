import asyncio
from pathlib import Path
import platform
from core.managers.model.manager import ModelManager
from core.runner.model.model_runner import RunnerConfig
from core.server.methods import Methods
from core.server.server import Server
from core.server.setup import Setup
from core.util.OSCommands import OSCommands
from core.util.logger import Logger

global model_name
model_name: str = "deepseek-coder-v2-lite-instruct.gguf"

async def initialize_service(logger: Logger) -> RunnerConfig:
    logger.debug("Initialize service dependencies")
    model_manager = ModelManager(logger, default_settings)
    logger.info("Init Setup")
    setup = Setup(logger, model_manager, default_settings)
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
        context_window = 1024,
        temp = 0.1,
        num_threads = 4,
        top_p = 0.4,
        model_name = model_name,
        model_path = str(Path(OSCommands.get_model_dir()) / model_name),
        llama_repo = "https://github.com/ggerganov/llama.cpp.git",
        os = platform.system(),
        pulpero_ready = False,
        response_size = 1024
    )

    new_logger = Logger("service", False)
    new_logger.clear_logs()
    logger_config = new_logger.get_config()
    new_logger.setup("Configuration logger", logger_config)
    asyncio.run(initialize_service(new_logger))
