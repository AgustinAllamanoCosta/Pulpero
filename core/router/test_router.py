from pathlib import Path
from core.managers.history.manager import HistoryManager
from core.managers.tool.manager import ToolManager
from core.util.OSCommands import OSCommands
from core.util.logger import Logger
from core.router.router import FileContextData, RouterManager
from core.runner.model.model_runner import Runner, RunnerConfig
from core.runner.model.parser import Parser
import platform

def test_router_manager():

    model_path = str(Path(OSCommands.get_model_dir()) / "deepseek-coder-v2-lite-instruct.gguf")
    logger = Logger("Manager router test", True)

    parser = Parser(logger)
    tool_manager = ToolManager(logger)
    history = HistoryManager(None)

    model_runner_config = RunnerConfig(1024, 0.1, 3, 0.4, "deepseek-coder-v2-lite-instruct.gguf", model_path, "https://github.com/ggerganov/llama.cpp.git", platform.system(), False, 1024)
    model_runner = Runner(model_runner_config, logger, parser)

    file_context_data = FileContextData("","","")
    router = RouterManager(logger,model_runner, tool_manager, history)

    code = '''
function Runner.new(config, logger, parser)
    local self = setmetatable({}, { __index = Runner })
    if config == nil then
        error("Model Runner config is nil")
    end
    if logger == nil then
        error("Model Runner logger is nil")
    end
    if parser == nil then
        error("Model Runner parser is nil")
    end
    self.config = config
    self.logger = logger
    self.parser = parser
    return self
end
'''

    response = router.route(code, file_context_data)
    print(response)
