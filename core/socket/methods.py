from core.managers.history.manager import HistoryManager
from core.managers.tool.manager import ToolManager
from core.runner.model.model_runner import Runner
from core.runner.model.parser import Parser
from core.util.logger import Logger
from core.managers.model import ModelManager
from core.socket.server import ServerRequest, ServerResponse
from core.router.router import FileContextData, RouterManager
from core.managers.tool.tools import tools

class Methods:

    logger: Logger
    model_manager: ModelManager
    router: RouterManager | None
    history: HistoryManager | None
    setup: SetupManager
    is_ready: bool
    enable: bool

    def __init__(self, logger: Logger, model_manager: ModelManager, setup) -> None:

        self.logger = logger
        self.model_manager = model_manager
        self.router = None
        self.history = None
        self.setup = setup
        self.is_ready = False
        self.enable = True

    def service_is_ready(self) -> bool:
        self.logger.info("checking if the service is ready")
        status = self.model_manager.get_status_from_file()
        self.logger.debug(f"Model status { status }")
        if status is "completed":
            self.logger.debug("Service download status is completed")
            if self.enable is True:
                self.logger.debug("Service is enable")
                return True
            else:
                self.logger.debug(f"The machine spirit is sleeping { self.enable }" )
                return False
        else:
            self.logger.debug("The machine spirit is not ready yet")
            return False

    def adapter(self, request: ServerRequest) -> ServerResponse:
        response = ServerResponse(requestId = request.Id, result = None, error = None)
        method = request.method

        match method:
            case "talk_with_model":
                if self.router is None:
                    response.error = 'router can not be None'
                    return response

                file_context: FileContextData = FileContextData(current_working_dir = '', current_file_name = '', current_file_path = '')
                if request.params.file_context is not None:
                    file_context = request.params.file_context
                response.result = self.router.route(request.params.message, file_context)
                return response

            case "get_live_code_feedback":
                if self.router is None:
                    response.error = 'router can not be None'
                    return response

                response.result = self.router.code_suggestion_pipeline(request.params.content, request.params.user_cursor)
                return response

            case "prepear_env":
                if not self.is_ready:
                    config = self.setup.prepear_env()

                    tool_manager = ToolManager(self.logger)

                    tool_manager.register_tool(tools['create_create_file_tool'](self.logger))
                    tool_manager.register_tool(tools['create_get_file_tool'](self.logger))
                    tool_manager.register_tool(tools['create_find_file_tool'](self.logger))

                    parser = Parser(self.logger)
                    runner = Runner(config, self.logger, parser)
                    self.history = HistoryManager(None)

                    self.router = RouterManager(self.logger, runner, tool_manager, self.history)
                    self.is_ready = True
                    response.result = self.is_ready
                return response

            case "clear_model_cache":
                if self.history is not None:
                    self.history.clear()
                response.result = True
                return response

            case "get_download_status":
                response.result = self.model_manager.get_download_status()
                return response

            case "get_service_status":
                status = self.model_manager.get_status_from_file()
                service_status = self.service_is_ready()
                response.result = f'{{ running: True, model_ready: {service_status}, download_status: {status} }}'
                return response

            case "toggle":
                self.enable = not self.enable
                response.result = self.enable
                return response

            case _:
                response.error = f"Unknown method: {request.method}"
                return response
