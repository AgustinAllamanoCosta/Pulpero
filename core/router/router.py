from core.managers.history.manager import HistoryManager
from core.managers.tool.manager import ToolManager
from core.runner.model.model_runner import Runner
from core.util.logger import Logger
from core.runner.model.prompts import generate_prompt_file, intent_prompt, file_operation, chat, code_suggestion, generate_final_response, code

# TODO: refactor the model runner to not use the generate prompt file
# TODO: refactor tools to generate the OPEN AI format 
# TODO: refactor router to send the correct promp in the new format and the tools if it is necesarie

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

    def __init__(self, logger: Logger | None, model_runner:Runner | None, tool_manager: ToolManager | None, history: HistoryManager | None) -> None:

        if (logger is None ):
            raise ValueError("Router logger is nil")

        if (model_runner is None):
            raise ValueError("Router model runner is nil")

        if (tool_manager is None):
            raise ValueError("Router tool manager is nil")

        if (history is None):
            raise ValueError("Router history manager is nil")

        self.history = history
        self.tool_manager = tool_manager
        self.model_runner = model_runner
        self.logger = logger
        self.file_context_data = None

    def route(self, user_message: str, file_context_data: FileContextData) -> str:
        self.file_context_data = file_context_data

        # detect when a topic change and switch context or clean the cache
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
        chat_history = self.history.generate_chat_history()
        complete_prompt = intent_prompt % (chat_history, user_message)
        prompt_file = generate_prompt_file(complete_prompt)
        model_response = self.model_runner.talk_with_model(prompt_file)
        return model_response.strip()

    def file_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        chat_history = self.history.generate_chat_history()
        tool_description = self.tool_manager.generate_tools_description()
        full_prompt = file_operation % (file_context_data_str, tool_description, chat_history, user_message)
        prompt_file = generate_prompt_file(full_prompt)
        model_response_with_tool_call = self.model_runner.talk_with_model(prompt_file)

        tool_response = self.tool_manager.execute_tool_if_exist_call(model_response_with_tool_call)
        self.history.update_chat_context_as_user(user_message)

        final_response = self.generate_final_response(user_message, tool_response)
        return final_response

    def code_analysis_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        chat_history = self.history.generate_chat_history()
        tool_description = self.tool_manager.generate_tools_description()
        full_prompt = code % (file_context_data_str, tool_description, chat_history, user_message )
        prompt_file = generate_prompt_file(full_prompt)
        model_response_with_tool_call = self.model_runner.talk_with_model(prompt_file)

        tool_response = self.tool_manager.execute_tool_if_exist_call(model_response_with_tool_call)

        self.history.update_chat_context_as_user(user_message)

        final_response = self.generate_final_response(user_message, tool_response)
        return final_response

    def general_chat_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        chat_history = self.history.generate_chat_history()
        full_prompt = chat % (file_context_data_str, chat_history, user_message)
        prompt_file = generate_prompt_file(full_prompt)

        self.history.update_chat_context_as_user(user_message)

        final_response = self.model_runner.talk_with_model(prompt_file)
        self.history.update_chat_context_as_assistant(final_response)

        return final_response

    def code_suggestion_pipeline(self, content: str, user_cursor: str) -> str:
        full_prompt = code_suggestion % (content, user_cursor)
        prompt_file = generate_prompt_file(full_prompt)
        model_response = self.model_runner.talk_with_model(prompt_file)
        return model_response

    def generate_final_response(self, user_message: str, tool_response: str) -> str:
        final_response_prompt = generate_final_response % (user_message, tool_response)
        final_prompts_file = generate_prompt_file(final_response_prompt)
        final_response = self.model_runner.talk_with_model(final_prompts_file)
        self.history.update_chat_context_as_assistant(final_response)
        return final_response
