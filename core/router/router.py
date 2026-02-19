from core.managers.history.manager import HistoryManager
from core.managers.tool.manager import ToolManager
from core.runner.model.model_runner import Runner
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
        tool_model_runner:Runner | None,
        clasi_model_runner:Runner | None,
        chat_model_runner:Runner | None,
        re_act_model_runner:Runner | None,
        tool_manager: ToolManager | None,
        history: HistoryManager | None,
        intention_history: HistoryManager | None
    ) -> None:

        if (logger is None ):
            raise ValueError("Router logger is nil")

        if (code_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (tool_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (clasi_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (tool_manager is None):
            raise ValueError("Router tool manager is nil")

        if (chat_model_runner is None):
            raise ValueError("Router model runner is nil")

        if (re_act_model_runner is None):
            raise ValueError("Router re act model runner is nil")

        if (history is None):
            raise ValueError("Router history manager is nil")

        if (intention_history is None):
            raise ValueError("Router history manager is nil")

        self.history = history
        self.intention_history = intention_history

        self.tool_manager = tool_manager
        self.chat_runner = chat_model_runner
        self.re_act_runner = re_act_model_runner
        self.clasi_runner = clasi_model_runner
        self.tool_runner = tool_model_runner
        self.code_runner = code_model_runner
        self.logger = logger
        self.file_context_data = None
        self.amount_of_thinks_cicles = 4

    def route(self, user_message: str, file_context_data: FileContextData) -> str:
        self.file_context_data = file_context_data

        # Add some basic security check of prompt leaking
        intentions = self.detect_intention(user_message)

        file_context_data_str = str(self.file_context_data)
        self.logger.debug("File contexst data", file_context_data_str)
        response = user_message

        for intention in intentions:

            self.logger.debug("raw intention", intention)
            match intention['pipeline']:
                case "file_operations":
                    response = self.file_pipeline(response,file_context_data_str)
                case "code_analysis":
                    response = self.code_analysis_pipeline(response, file_context_data_str)
                case "general_chat":
                    response = self.general_chat_pipeline(response, file_context_data_str)
                case _:
                    response = self.general_chat_pipeline(response, file_context_data_str)

        return response

    def file_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        self.history.update_chat_context_as_system(file_operation)

        model_response = self.re_act_loop(self.history, user_message, file_context_data_str, self.re_act_runner, self.tool_runner, self.tool_manager)
        return model_response

    def code_analysis_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        self.history.update_chat_context_as_system(code_analysis)
        model_response = self.re_act_loop(self.history, user_message, file_context_data_str, self.code_runner, self.tool_runner, self.tool_manager)
        return model_response

    def general_chat_pipeline(self, user_message: str, file_context_data_str: str) -> str:
        self.history.update_chat_context_as_system(chat)
        self.history.update_chat_context_as_user(user_message)
        model_response = self.chat_runner.talk_with_model(self.history)
        self.history.update_chat_context_as_assistant(model_response.message)
        return model_response.message

    def code_suggestion_pipeline(self, content: str, file_context_data: str) -> str:
        self.history.update_chat_context_as_system(code_suggestion)
        model_response = self.re_act_loop(self.history, content, file_context_data, self.code_runner, self.tool_runner, self.tool_manager)
        return model_response

    def re_act_loop(
            self,
            history: HistoryManager,
            user_message: str,
            file_context_data: str,
            re_act_model_runner: Runner,
            tool_model_runner: Runner,
            tool_manager: ToolManager
        ):
        max_iteration = 5
        previous_thoughts = []

        history.update_chat_context_as_user(user_message)
        final_response = "Upps looks like the model its trap in his own thoughts"
        finish = False

        for i in range(max_iteration):
            self.logger.info("Chat History", history.generate_chat_history())

            response = re_act_model_runner.think(history)
            self.logger.info("Model response ", response)

            if response.thought in previous_thoughts[-2:]:
                self.logger.info(f"Thought loop detected: {response.thought}")
                final_response = self.re_act_safe_guard(history, re_act_model_runner)
                finish = True
                break;

            previous_thoughts.append(response.thought)

            if response.is_final_response == True:
                final_response = response.message
                history.update_chat_context_as_assistant(response.message)
                finish = True
                break;

            elif response.keep_thinking == True:
                history.update_chat_context_as_assistant(response.message)

            else:
                history.update_chat_context_as_assistant(response.thought)

                response = tool_model_runner.ask_for_tool_call(history, tool_manager)
                for tool_call in response.tool_calls:

                    history.update_chat_context_as_tool_call(tool_call.name, f"{tool_call.name}({tool_call.arguments})")
                    tool_response = self.tool_manager.execute_tool(tool_call)

                    if tool_response.success:
                        history.update_chat_context_as_tool_call(tool_call.name, str(tool_response.result))
                    else:
                        history.update_chat_context_as_tool_call(tool_call.name, str(tool_response.error))

        if not finish:
            final_response = self.re_act_safe_guard(history, re_act_model_runner)

        return final_response

    def re_act_safe_guard(self, history: HistoryManager, model: Runner):
        history.update_chat_context_as_user("Provide your complete answer to the user based on the information in our conversation:")
        model_response = model.talk_with_model(history)
        return model_response.message

    def detect_intention(self, user_message: str) -> str:

        self.intention_history.update_chat_context_as_system(intent_prompt)
        self.intention_history.update_chat_context_as_user(user_message)

        model_response = self.clasi_runner.generate_todo_lits(self.intention_history)

        if model_response is None:
            raise Exception("Model respons is None when we try to generate the todo list")

        self.intention_history.clear()
        return model_response
