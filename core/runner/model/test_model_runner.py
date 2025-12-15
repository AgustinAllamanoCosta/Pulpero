from core.runner.model.model_runner import Runner
from core.runner.model.parser import Parser
from core.runner.model.prompts import chat, generate_prompt_file
from core.util.logger import Logger
from pathlib import Path
import os
import platform

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

def test_talk_with_model():
    model_path = Path(OSCommands.get_model_dir()) / "deepseek-coder-v2-lite-instruct.gguf"
    default_config = {
        "context_window": 1024,
        "temp": "0.1",
        "num_threads": "4",
        "top_p": "0.4",
        "model_name": "deepseek-coder-v2-lite-instruct.gguf",
        "model_path": str(model_path),
        "llama_repo": "https://github.com/ggerganov/llama.cpp.git",
        "os": platform.system(),
        "pulpero_ready": False,
        "response_size": "1024"
    }

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
