from core.managers.history.manager import HistoryManager
from core.managers.model.manager import ModelManager
from core.managers.tool.manager import ToolManager
from core.managers.tool.tools import tools
from core.router.router import FileContextData, RouterManager
from core.runner.model.model_runner import Runner
from core.server.data_model import ServerRequest, ServerResponse
from core.server.setup import Setup
from core.util.logger import Logger
from core.util.OSCommands import OSCommands

class Methods:

    logger: Logger
    model_manager: ModelManager
    router: RouterManager | None
    history: HistoryManager | None
    loop_history: HistoryManager | None
    intention_history: HistoryManager | None
    setup: Setup
    is_ready: bool
    enable: bool

    def __init__(self, logger: Logger, model_manager: ModelManager, setup: Setup) -> None:

        self.logger = logger
        self.model_manager = model_manager
        self.router = None
        self.history = None
        self.loop_history = None
        self.file_history = None
        self.code_analysis_history = None
        self.code_suggestion_history = None
        self.intention_history = None
        self.setup = setup
        self.is_ready = False
        self.enable = True

    def service_is_ready(self) -> bool:
        self.logger.info("checking if the service is ready")
        status = self.model_manager.get_status_from_file()
        self.logger.debug(f"Model status { status }")
        if status == "completed":
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
                if request.params.get('file_context') is not None:
                    file_context.current_working_dir = request.params.get('file_context').get('current_working_dir')
                    file_context.current_file_path = request.params.get('file_context').get('current_file_path')
                    file_context.current_file_name = request.params.get('file_context').get('current_file_name')

                message: str = ''
                if request.params.get('message') != None:
                    message = request.params.get('message')

                response.result = self.router.route(message, file_context)
                return response

            case "get_live_code_feedback":
                if self.router is None:
                    response.error = 'router can not be None'
                    return response

                if request.params.get('content') is None or request.params.get('content') is dict[str, str]:
                    response.error = 'content need to be a string'
                    return response

                if request.params.get('user_cursor') is None or request.params.get('user_cursor') is dict[str, str]:
                    response.error = 'user cursor need to be a string'
                    return response

                content: str = request.params.get('content')
                # user_cursor: str = request.params.get('user_cursor')

                formatted_content = []

                for line in content:
                    formatted_content.append(f"{line['line_number']:4d} | {line['content']}")
                response.result = self.router.code_suggestion_pipeline('\n'.join(formatted_content))
                return response

            case "prepear_env":
                if not self.is_ready and self.enable:
                    env_config = self.setup.prepear_env()

                    if self.router is None:
                        tool_manager = ToolManager(self.logger)
                        tool_manager.register_tool(tools['create_create_file_tool'](self.logger))
                        tool_manager.register_tool(tools['create_get_file_tool'](self.logger))
                        tool_manager.register_tool(tools['create_find_file_tool'](self.logger))
                        tool_manager.register_tool(tools['create_list_directory_tool'](self.logger))
                        tool_manager.register_tool(tools['create_get_file_tree_tool'](self.logger))

                        research_tool_manager = ToolManager(self.logger)
                        research_tool_manager.register_tool(tools['create_web_search_tool'](self.logger))

                        code_analysis_runner = Runner(env_config.code_config, self.logger)
                        tool_executuion_runner = Runner(env_config.tool_config, self.logger)
                        clasi_runner = Runner(env_config.clasi_config, self.logger)
                        chat_runner = Runner(env_config.model_config, self.logger)
                        react_runner = Runner(env_config.model_config, self.logger)

                        if self.history is None:
                            history_path = str(OSCommands.get_data_path() / 'history.json')
                            self.history = HistoryManager(None, file_path=history_path)
                            self.history.load()

                        if self.loop_history is None:
                            self.loop_history = HistoryManager(None)

                        if self.code_suggestion_history is None:
                            self.code_suggestion_history = HistoryManager(None)

                        if self.intention_history is None:
                            self.intention_history = HistoryManager(None)

                        self.router = RouterManager(
                                self.logger,
                                code_analysis_runner,
                                tool_executuion_runner,
                                clasi_runner,
                                chat_runner,
                                react_runner,
                                tool_manager,
                                research_tool_manager,
                                self.history,
                                self.intention_history,
                                self.code_suggestion_history,
                                self.loop_history
                        )
                    self.is_ready = True
                    response.result = self.is_ready
                return response

            case "update_project_context":
                cwd = request.params.get('cwd')
                if cwd and self.history is not None:
                    from core.managers.tool.get_file_tree import get_file_tree
                    tree_tool = get_file_tree(self.logger)
                    tree_result = tree_tool.callback({'path': cwd})
                    if tree_result.success:
                        self.history.update_chat_context_as_assistant(
                            f"Current project structure at {cwd}:\n{tree_result.result}"
                        )
                        self.history.flush()
                response.result = True
                return response

            case "clear_model_cache":
                if self.history is not None:
                    self.history.clear()
                    self.history.flush()
                response.result = True
                return response

            case "get_download_status":
                response.result = self.model_manager.get_status_from_file()
                return response

            case "get_service_status":
                status = self.model_manager.get_status_from_file()
                service_status = self.service_is_ready()
                response.result = f'{{ running: {self.enable}, model_ready: {service_status}, download_status: {status} }}'
                return response

            case "toggle":
                self.enable = not self.enable
                response.result = self.enable
                return response

            case _:
                response.error = f"Unknown method: {request.method}"
                return response
