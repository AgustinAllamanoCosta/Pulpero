import re
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

class LightweightSimilarity:
    def __init__(self, threshold: float = 0.6):
        self.threshold = threshold

    def _shingle(self, text: str, k: int = 3) -> set[str]:
        words = re.findall(r'\w+', text.lower())
        if len(words) < k:
            return {' '.join(words)}
        return {' '.join(words[i:i+k]) for i in range(len(words) - k + 1)}

    def jaccard_similarity(self, text1: str, text2: str) -> float:
        s1 = self._shingle(text1)
        s2 = self._shingle(text2)

        if not s1 or not s2:
            return 0.0

        intersection = len(s1 & s2)
        union = len(s1 | s2)
        return intersection / union if union > 0 else 0.0

    def is_similar(self, text1: str, text2: str) -> bool:
        return self.jaccard_similarity(text1, text2) > self.threshold

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
        intention_history: HistoryManager | None,
        code_suggestion_history: HistoryManager | None,
        loop_history: HistoryManager | None
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

        if (code_suggestion_history is None):
            raise ValueError("Router code_suggestion_history manager is nil")

        if (loop_history is None):
            raise ValueError("Router loop_history manager is nil")


        self.history = history
        self.code_suggestion_history = code_suggestion_history
        self.intention_history = intention_history
        self.loop_history = loop_history

        self.tool_manager = tool_manager
        self.chat_runner = chat_model_runner
        self.re_act_runner = re_act_model_runner
        self.clasi_runner = clasi_model_runner
        self.tool_runner = tool_model_runner
        self.code_runner = code_model_runner
        self.logger = logger
        self.file_context_data = FileContextData(current_working_dir = '', current_file_name = '', current_file_path = '')
        self.amount_of_thinks_cicles = 4
        self.lightweightSimilarity = LightweightSimilarity()

    def route(self, user_message: str, file_context_data: FileContextData) -> str:

        self.history.update_chat_context_as_user(user_message)

        if( self.file_context_data.current_working_dir != file_context_data.current_working_dir):
            self.file_context_data = file_context_data
            self.history.update_chat_context_as_assistant(f"this is the information of the file I am working on {self.file_context_data}")

        self.intention_history.update_chat_context_as_system(intent_prompt)
        intentions = self.generate_plan(user_message)
        response = ""
        self.logger.info("Intention to process" ,intentions)

        validation_response = self.validate_plan(user_message, intentions)

        if(validation_response == True):
            for intention in intentions:
                step = intention['step']
                description = intention["description"]
                match step:
                    case "file_operations":
                        response = self.file_pipeline(description)
                    case "code_analysis":
                        response = self.code_analysis_pipeline(description)
                    case "general_chat":
                        response = self.general_chat_pipeline(description)
                    case _:
                        response = self.general_chat_pipeline(description)
                self.logger.info("Chat History", self.history)
        else:
            response = self.general_chat_pipeline("")

        return response

    def validate_plan(self, user_message: str, plan: list) -> bool:
        self.intention_history.clear()
        self.intention_history.update_chat_context_as_system(f"given the following user message and plan, validate if the plan will acomplish the user query, plan: {plan}")
        self.intention_history.update_chat_context_as_user(user_message)
        validation_response = self.chat_runner.validate(self.intention_history)
        return validation_response.message['is_valid']

    def file_pipeline(self, description: str) -> str:
        self.logger.info("Processing File Pipeline")
        self.history.update_chat_context_as_assistant(description)

        self.loop_history.clear()
        self.loop_history.update_chat_context_as_system(file_operation)
        self.loop_history.update_chat_context_as_assistant(description)
        self.loop_history.update_chat_context_as_assistant(f"this is the information of the file I am working on {self.file_context_data}")
        model_response = self.re_act_loop(self.loop_history, self.re_act_runner, self.tool_runner, self.tool_manager)
        self.history.update_chat_context_as_assistant(model_response)

        return model_response

    def code_analysis_pipeline(self, description: str) -> str:
        self.logger.info("Processing Code analysis")
        self.history.update_chat_context_as_assistant(description)

        self.loop_history.clear()
        self.loop_history.update_chat_context_as_system(code_analysis)
        self.loop_history.update_chat_context_as_assistant(description)
        model_response = self.re_act_loop(self.loop_history,self.code_runner, self.tool_runner, self.tool_manager)

        self.history.update_chat_context_as_assistant(model_response)
        return model_response

    def general_chat_pipeline(self, description: str) -> str:
        self.logger.info("Processing Chat")
        self.history.update_chat_context_as_system(chat)
        self.history.update_chat_context_as_assistant(description)
        model_response = self.chat_runner.talk_with_model(self.history)
        self.history.update_chat_context_as_assistant(model_response.message)

        return model_response.message

    def code_suggestion_pipeline(self, file_content: str) -> dict:
        self.logger.info("Processing Code suggestion")
        self.code_suggestion_history.update_chat_context_as_system(code_suggestion)
        self.code_suggestion_history.clear()
        model_response = self.code_runner.generate_code_suggestion(self.code_suggestion_history)
        self.code_suggestion_history.update_chat_context_as_assistant(str(model_response.message))

        return model_response.message

    def re_act_loop(
            self,
            history: HistoryManager,
            re_act_model_runner: Runner,
            tool_model_runner: Runner,
            tool_manager: ToolManager
        ):
        max_iteration = 5
        previous_thoughts = []
        consecutive_similar = 0

        final_response = "Upps looks like the model its trap in his own thoughts"
        finish = False

        for i in range(max_iteration):

            response = re_act_model_runner.think(history)
            self.logger.info("Model response ", response)

            for prev_thought in previous_thoughts[-3:]:
                similarity = self.lightweightSimilarity.is_similar(response.thought, prev_thought)
                if similarity:
                    consecutive_similar += 1
                    break

            if consecutive_similar >= 2:
                self.logger.info("Thought loop detected, attempting recovery")
                history.update_chat_context_as_system(
                    "Your previous thoughts were repetitive. Try a completely different approach. "
                    "If stuck, provide your best answer based on current information."
                )
                consecutive_similar = 0
                continue

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
        history.update_chat_context_as_system("Provide your complete answer to the user based on the information in our conversation:")
        model_response = model.talk_with_model(history)
        history.update_chat_context_as_assistant(model_response.message)
        self.logger.info("Model response ", model_response)
        return model_response.message

    def generate_plan(self, user_message: str) -> list:

        self.intention_history.update_chat_context_as_user(user_message)
        model_response = self.clasi_runner.generate_todo_lits(self.intention_history)

        if model_response is None:
            raise Exception("Model respons is None when we try to generate the todo list")

        self.intention_history.clear()
        return model_response
