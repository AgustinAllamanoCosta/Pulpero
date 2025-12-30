
from core.managers.model.model_manager import ModelManager
from core.runner.model.model_runner import RunnerConfig
from core.util.logger import Logger
import psutil

class Setup:

    logger: Logger
    command_output: str
    model_manager: ModelManager
    config: RunnerConfig

    def __init__(self, logger: Logger, model_manager: ModelManager, default_config: RunnerConfig):
        if logger is None:
            raise ValueError("Setup logger can not be nil")
        self.logger = logger
        self.command_output = logger.get_config().command_path
        self.model_manager = model_manager
        self.config = default_config

    def configure_memory(self, total_mem: int):
        if total_mem < 8192:
            return 512, 2
        elif total_mem < 16384:
            return 1024, 4
        else:
            return 8840, 8

    def prepear_env(self) -> RunnerConfig:
        self.logger.setup("Prepearing env")
        if self.model_manager.check_if_model_exist():
            self.config.pulpero_ready = True
        else:
            self.config.pulpero_ready = False
            self.model_manager.download_and_assemble_model()

        return self.config

    def configure_plugin(self) -> RunnerConfig:
        context_window, threads = self.configure_memory(psutil.virtual_memory().available)
        self.config.context_window = context_window
        self.config.num_threads = threads
        self.logger.setup(f"Memory configured: {self.config.context_window} threads: {self.config.num_threads}")

        return self.config
