from core.runner.model.model_runner import Runner, RunnerConfig
from core.runner.model.parser import Parser
from core.runner.model.prompts import chat, generate_prompt_file
from core.util.OSCommands import OSCommands
from core.util.logger import Logger
from pathlib import Path
import platform

def test_talk_with_model():
    model_path: str = str(Path(OSCommands.get_model_dir()) / "deepseek-coder-v2-lite-instruct.gguf")
    default_config: RunnerConfig = RunnerConfig(1024, 0.1, 4, 0.4, "deepseek-coder-v2-lite-instruct.gguf", model_path, "https://github.com/ggerganov/llama.cpp.git", platform.system(), False, 1024)

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

    logger = Logger("Talk with model test", True)
    parser = Parser(logger)

    runner = Runner(default_config, logger, parser)

    response = runner.talk_with_model(generate_prompt_file(chat % ("","",code)))
    print(response)
