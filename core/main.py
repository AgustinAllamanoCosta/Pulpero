import asyncio
import os
from pathlib import Path
import platform
from core.managers.model.model_manager import ModelManager
from core.runner.model.model_runner import RunnerConfig
from core.socket.methods import Methods
from core.socket.server import Server
from core.socket.setup import Setup
from core.util.logger import Logger

global logger, model_name
logger: Logger | None = None
model_name: str = "deepseek-coder-v2-lite-instruct.gguf"

class OSCommands:
    @classmethod
    def get_model_dir(cls):
        source_path = cls.get_data_path()
        final_path = source_path / "model"
        final_path.mkdir(parents=True, exist_ok=True)
        return final_path

    @staticmethod
    def get_data_path():
        home = Path.home()
        if os.name == 'nt':
            return Path(os.getenv('APPDATA', home)) / 'pulpero'
        else:
            return home / '.local' / 'share' / 'pulpero'

def initialize_logger(param_logger: Logger | None) -> None
    if param_logger is None:
        logger = Logger("service", False)
        logger.clear_logs()
        logger_config = logger.get_config()
        logger.setup("Configuration logger", logger_config)
    else:
        logger = param_logger

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

    initialize_logger(logger)

    if logger is None:
        raise ValueError('Logger can not be None')

    asyncio.run(initialize_service(logger))
