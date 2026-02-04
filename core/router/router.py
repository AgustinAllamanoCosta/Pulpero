from core.managers.history.manager import HistoryManager
from core.managers.tool.manager import ToolManager
from core.runner.model.model_runner import ModelResponse, Runner
from core.util.logger import Logger
from core.runner.model.prompts import intent_prompt, file_operation, chat, code_suggestion, code_analysis

class FileContextData:
    current_working_dir: str
    current_file_name: str
    current_file_path: str

    def __init__(self, current_working_dir:str, current_file_name: str, current_file_path: str) -> None:
        self.current_file_name = current_file_name
        self.current_file_path = current_file_path
        self.current_working_dir = current_working_dir

    def __str__(self) -> str:
        return f"Current working dir: {self.current_working_dir}\nOpen file name: {self.current_file_name}\nOpen file dir path: {self.current_file_path}\n"

class RouterManager:

    def __init__(self,
        logger: Logger | None,
        code_model_runner:Runner | None,
        too_model_runner:Runner | None,
        clasi_model_runner:Runner | None,
        chat_model_runner:Runner | None,
        tool_manager: ToolManager | None,
        history: HistoryManager | None,
        intention_history: HistoryManager | None
    ) -> None:

        if (logger is None ):
            raise ValueError("Router logger is nil")

        if (code_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (too_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (clasi_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (tool_manager is None):
            raise ValueError("Router tool manager is nil")

        if (chat_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (history is None):
            raise ValueError("Router history manager is nil")

        if (intention_history is None):
            raise ValueError("Router history manager is nil")

        self.history = history
        self.intention_history = intention_history

        self.tool_manager = tool_manager
        self.model_runner = chat_model_runner
        self.clasi_runner = clasi_model_runner
        self.tool_runner = too_model_runner
        self.code_runner = code_model_runner
        self.logger = logger
        self.file_context_data = None
        self.amount_of_thinks_cicles = 4

    def route(self, user_message: str, file_context_data: FileContextData) -> str:
        self.file_context_data = file_context_data

        # Add some basic security check of prompt leaking
        intention = self.detect_intention(user_message)

        file_context_data_str = str(self.file_context_data)
        self.logger.debug("File contexst data", file_context_data_str)

        match intention:
            case "file_operations":
                response = self.file_pipeline(user_message, file_context_data_str)
            case "code_analysis":
                response = self.code_analysis_pipeline(user_message, file_context_data_str)
            case "general_chat":
                response = self.general_chat_pipeline(user_message, file_context_data_str)
            case _:
                response = "No pipeline category found"

        return response

    def detect_intention(self, user_message: str) -> str:

        self.intention_history.update_chat_context_as_system(intent_prompt)
        self.intention_history.update_chat_context_as_user(user_message)
        chat_history = self.intention_history.generate_chat_history()

        model_response = self.clasi_runner.talk_with_model(chat_history,[])

        self.intention_history.clear()
        return model_response.message.strip()

    def file_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        self.history.update_chat_context_as_system(file_operation)
        return self.process_pipeline(self.history, user_message, file_context_data_str, self.tool_runner)

    def code_analysis_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        self.history.update_chat_context_as_system(code_analysis)
        return self.process_pipeline(self.history, user_message, file_context_data_str, self.code_runner)

    def general_chat_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        self.history.update_chat_context_as_system(chat)
        return self.process_pipeline(self.history, user_message, file_context_data_str, self.model_runner)

    def code_suggestion_pipeline(self, content: str, file_context_data: str) -> str:
        self.history.update_chat_context_as_system(code_suggestion)
        return self.process_pipeline(self.history, content, file_context_data, self.code_runner)

    def process_pipeline(self, history: HistoryManager, user_message: str, file_context_data: str, model_runner: Runner):
        model_response: ModelResponse = ModelResponse("",[])

        history.update_chat_context_as_user(user_message)
        chat_history = history.generate_chat_history()

        self.logger.info("Chat history ", chat_history)

        for i in range(self.amount_of_thinks_cicles):
            tool_description = self.tool_manager.get_tool_descriptions()

            response = model_runner.talk_with_model(
                chat_history,
                tool_description
            )

            history.update_chat_context_as_assistant(response.message)

            if not response.tool_calls:
                model_response = response
                break;

            for tool_call in response.tool_calls:
                tool_response = self.tool_manager.execute_tool(tool_call)

                if tool_response.success:
                    history.update_chat_context_as_tool_call( tool_call.name, str(tool_response.result))
                else:
                    history.update_chat_context_as_tool_call("Unknown", "Tool execution faild")

            chat_history = history.generate_chat_history()

        return model_response.message
