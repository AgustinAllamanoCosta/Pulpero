from pathlib import Path
import platform
from core.managers.model.manager import ModelManager
from core.runner.model.model_runner import RunnerConfig
from core.socket.data_model import ServerRequest, ServerResponse
from core.socket.methods import Methods
from core.socket.setup import Setup
from core.util.OSCommands import OSCommands
from core.util.logger import Logger

model_path = str(Path(OSCommands.get_model_dir()) / "deepseek-coder-v2-lite-instruct.gguf")
logger = Logger('Test methods', True)
model_runner_config = RunnerConfig(1024, 0.1, 3, 0.4, "deepseek-coder-v2-lite-instruct.gguf", model_path, "https://github.com/ggerganov/llama.cpp.git", platform.system(), False, 1024)

def test_get_download_status():

    model_manager: ModelManager = ModelManager(logger, model_runner_config)
    setup: Setup = Setup(logger, model_manager, model_runner_config)
    methods: Methods = Methods(logger, model_manager, setup)

    model_manager.clean_status_file()
    server_request: ServerRequest = ServerRequest(method='get_download_status', Id=1, params={})
    service_response: ServerResponse = methods.adapter(server_request)

    assert service_response.result == 'downloading'

def test_get_service_status():

    model_manager: ModelManager = ModelManager(logger, model_runner_config)
    setup: Setup = Setup(logger, model_manager, model_runner_config)
    methods: Methods = Methods(logger, model_manager, setup)

    model_manager.clean_status_file()
    server_request: ServerRequest = ServerRequest(method='get_service_status', Id=1, params={})
    service_response: ServerResponse = methods.adapter(server_request)
    expected_status = f'{{ running: True, model_ready: False, download_status: downloading }}'

    assert service_response.result == expected_status

def test_toggle():

    model_manager: ModelManager = ModelManager(logger, model_runner_config)
    setup: Setup = Setup(logger, model_manager, model_runner_config)
    methods: Methods = Methods(logger, model_manager, setup)

    model_manager.clean_status_file()
    toogle_server_request: ServerRequest = ServerRequest(method='toggle', Id=1, params={})
    methods.adapter(toogle_server_request)
    status_server_request: ServerRequest = ServerRequest(method='get_service_status', Id=1, params={})
    service_response: ServerResponse = methods.adapter(status_server_request)
    expected_status = f'{{ running: False, model_ready: False, download_status: downloading }}'

    assert service_response.result == expected_status

def test_prepear_env():

    model_manager: ModelManager = ModelManager(logger, model_runner_config)
    setup: Setup = Setup(logger, model_manager, model_runner_config)
    methods: Methods = Methods(logger, model_manager, setup)

    model_manager.clean_status_file()
    server_request: ServerRequest = ServerRequest(method='prepear_env', Id=1, params={})
    service_response: ServerResponse = methods.adapter(server_request)
    expected_status = True

    assert service_response.result == expected_status
