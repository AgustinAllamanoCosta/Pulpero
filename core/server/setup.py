from core.managers.model.manager import ModelManager
from core.runner.model.model_runner import RunnerConfig
from core.util.logger import Logger
import psutil

class ModelConfiguration:
    model_config: RunnerConfig
    clasi_config: RunnerConfig
    tool_config: RunnerConfig
    code_config: RunnerConfig

class Setup:

    logger: Logger
    command_output: str
    model_manager: ModelManager
    model_config: RunnerConfig
    clasi_config: RunnerConfig
    tool_config: RunnerConfig
    code_config: RunnerConfig

    def __init__(self, logger: Logger, model_manager: ModelManager, default_config: RunnerConfig, casi_config: RunnerConfig, tool_config: RunnerConfig, code_config: RunnerConfig):
        self.logger = logger
        self.command_output = logger.get_config().command_path
        self.model_manager = model_manager
        self.model_config = default_config
        self.clasi_config = casi_config
        self.tool_config = tool_config
        self.code_config = code_config

    def configure_memory(self, total_mem: int):
        if total_mem < 8192:
            return 512, 2
        elif total_mem < 16384:
            return 1024, 4
        else:
            return 8840, 8

    def prepear_env(self):
        self.logger.setup("Prepearing env")
        if self.model_manager.check_if_model_exist():
            self.model_config.pulpero_ready = True
        else:
            self.model_config.pulpero_ready = False
            self.model_manager.download_and_assemble_model()

        config = ModelConfiguration()
        config.model_config = self.model_config
        config.clasi_config = self.clasi_config
        config.tool_config = self.tool_config
        config.code_config = self.code_config
        return config

    def configure_plugin(self) -> RunnerConfig:
        context_window, threads = self.configure_memory(psutil.virtual_memory().available)
        self.model_config.context_window = context_window
        self.model_config.num_threads = threads
        self.logger.setup(f"Memory configured: {self.model_config.context_window} threads: {self.model_config.num_threads}")

        return self.model_config
