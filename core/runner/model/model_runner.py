import os
from typing import Optional, cast
from llama_cpp import ChatCompletionRequestMessage, ChatCompletionRequestResponseFormat, ChatCompletionTool, CreateChatCompletionResponse, Llama
from core.managers.history.manager import HistoryManager
from core.managers.tool.manager import ToolManager
from core.managers.tool.tool import TooCall
from core.util.logger import Logger
import json

step_schema_raw = {
    "type": "object",
    "properties": {
        "steps": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "pipeline": {
                        "type": "string",
                        "enum": ["file_operations", "code_analysis", "general_chat"]
                    },
                },
                "required": ["pipeline", "input"],
                "minItems": 1,
                "maxItems": 5,
                "uniqueItems": True
            },
        }
    },
    "required": ["steps"]
}

re_act_schema_raw = {
    "type": "object",
    "properties": {
        "thought": {
            "type": "string",
            "description": "Your reasoning about the task"
        },
        "action": {
            "type": "string",
            "enum": ["need_tool", "finish", "continue_thinking"],
            "description": "What to do next"
        },
        "tool_request": {
            "type": "string",
            "description": "Natural language description of what tool is needed (only if action is need_tool)"
        },
    },
    "required": ["thought", "action"]
}

class ModelResponse:
    message: str
    thought: str
    tool_calls: list[TooCall]
    is_final_response: bool
    keep_thinking: bool

    def __init__(self, message: str, tool_calls: list[TooCall]) -> None:
        self.message = message
        self.tool_calls = tool_calls
        self.is_final_response = False
        self.keep_thinking = False

    def __str__(self) -> str:
        return f'''
    message: {self.message}
    thought: {self.thought}
    tool_calls: {self.tool_calls}
    is_final_response: {self.is_final_response}
    keep_thinking: {self.keep_thinking}
    '''
class RunnerConfig:
    context_window: int
    temp: float
    num_threads: int
    top_p:float
    model_name: str
    model_path: str
    os: str
    response_size: int

    def __init__(
            self,
            context_window: int,
            temp: float,
            num_threads: int,
            top_p:float,
            model_name: str,
            model_path: str,
            os: str,
            response_size: int
        ) -> None:

        self.context_window = context_window
        self.temp= temp
        self.num_threads= num_threads
        self.top_p = top_p
        self.model_name = model_name
        self.model_path = model_path
        self.os = os
        self.response_size = response_size

    def __str__(self) -> str:
        return f'''
    context_window: {self.context_window}
    temp: {self.temp}
    num_threads: {self.num_threads}
    top_p: {self.top_p}
    model_name: {self.model_name}
    model_path: {self.model_path}
    os: {self.os}
    response_size: {self.response_size}
    '''

class Runner:

    def __init__(
            self,
            config: RunnerConfig,
            logger: Logger,
        ) -> None:

        if config == None:
            raise ValueError("Model Runner config is nil")

        if logger == None:
            raise ValueError("Model Runner logger is nil")

        self.config = config
        self.logger = logger
        self._initialize_model()

    def _initialize_model(self):
        try:
            model_path = self.config.model_path
            if not os.path.exists(model_path):
                raise FileNotFoundError(f"Model file not found: {model_path}")

            self.logger.debug(f"Initializing Llama ccp model from: {model_path}")
            self.llm = Llama(
                model_path=model_path,
                n_ctx=self.config.context_window,
                n_threads=self.config.num_threads,
                n_batch=256,
                verbose=False,
                use_mmap=True,
                use_mlock=False,
                logits_all=False,
                chat_format="llama-3",
                n_gpu_layers=35,
                seed=-1
            )
            self.logger.debug("Llama ccp model initialized successfully")
        except Exception as e:
            self.logger.error(f"Failed to initialize Llama model: {e}")
            raise

    def run_local_model(
            self,
            history: list[ChatCompletionRequestMessage],
            config: RunnerConfig,
            tools: list[ChatCompletionTool], 
            schema: Optional[ChatCompletionRequestResponseFormat] = None
    ) -> CreateChatCompletionResponse:
        try:

            self.logger.debug("Generating response with Llama ccp")

            llama_completion = self.llm.create_chat_completion(
                messages=history,
                max_tokens=config.response_size,
                temperature=config.temp,
                response_format= schema,
                top_p=config.top_p,
                tools=tools,
                tool_choice='auto',
                repeat_penalty=1.15,
                frequency_penalty=0.2,
                presence_penalty=0.1,
            )

            responses = cast(CreateChatCompletionResponse, llama_completion)
            return responses

        except Exception as e:
            self.logger.error(f"Error during model inference: {e}")
            return cast(CreateChatCompletionResponse,{ 'choices': [{'message': { 'content': "An Error ocurred when we try to run infer the response"}}]})

    def generate_todo_lits(self, history: HistoryManager):
        model_response: dict | None = None
        raw_responses = self.run_local_model(
            cast(list[ChatCompletionRequestMessage], history.generate_chat_history()),
            self.config,
            [],
            {
                "type": "json_object",
                "schema": step_schema_raw
            }
        )

        if raw_responses.get('choices').__len__() > 0:
            completion = raw_responses.get('choices')[0]
            content = completion.get('message').get('content')
            if content != None:
                if content.startswith('{'):
                    model_response = json.loads(content)

        return model_response['steps']

    def think(self, history: HistoryManager) -> ModelResponse:
        model_response = ModelResponse("", [])
        raw_responses = self.run_local_model(
            cast(list[ChatCompletionRequestMessage], history.generate_chat_history()),
            self.config,
            [],
            {
                "type": "json_object",
                "schema": re_act_schema_raw
            }

        )

        if raw_responses.get('choices').__len__() > 0:
            completion = raw_responses.get('choices')[0]
            content = completion.get('message').get('content')
            if content != None:
                parse_content = json.loads(content)

                action = parse_content.get('action')

                if action == "finish":
                    model_response.is_final_response = True
                    final_answer = parse_content.get('thought')
                    model_response.thought = final_answer
                    model_response.message = final_answer
                if action == "need_tool":
                    tool_request = parse_content.get('tool_request')
                    thought = parse_content.get('thought')
                    model_response.thought = thought
                    model_response.message = tool_request
                elif action == "continue_thinking":
                    model_response.keep_thinking = True
                    thought = parse_content.get('thought')
                    model_response.thought = thought
                    model_response.message = thought

        return model_response

    def talk_with_model(self, history: HistoryManager):
        model_response = ModelResponse("", [])
        raw_responses = self.run_local_model(
            cast(list[ChatCompletionRequestMessage], history.generate_chat_history()),
            self.config,
            [],
            None
        )

        if raw_responses.get('choices').__len__() > 0:
            model_response.keep_thinking = True
            completion = raw_responses.get('choices')[0]
            content = completion.get('message').get('content')
            if content != None:
                model_response.message = content

        return model_response

    def ask_for_tool_call(self, history: HistoryManager, tool_manager: ToolManager) -> ModelResponse:
        model_response = ModelResponse("", [])
        raw_responses = self.run_local_model(
            cast(list[ChatCompletionRequestMessage], history.generate_chat_history()),
            self.config,
            cast(list[ChatCompletionTool], tool_manager.get_tool_descriptions()),
            {
                "type": "json_object",
                "schema": tool_manager.generate_schemas()
            }
        )

        if raw_responses.get('choices').__len__() > 0:
            model_response.keep_thinking = True
            completion = raw_responses.get('choices')[0]
            content = completion.get('message').get('content')
            if content != None:
                if content.startswith('{'):
                    model_response.tool_calls = self.parse_function_call(content)
                else:
                    model_response.message = content

        return model_response

    def parse_function_call(self, content: str):
        try:
            tool_call_json = json.loads(content.strip())
            function_name = tool_call_json.get('function')
            parameters = tool_call_json.get('parameters', {})
            if 'properties' in parameters:
                arguments = parameters['properties']
            else:
                arguments = parameters
            self.logger.info(f"Parsed Llama tool call: {function_name}({arguments})")
            tool_call = TooCall()
            tool_call.name = function_name
            tool_call.arguments = arguments
            return [tool_call]
        except json.JSONDecodeError as e:
            self.logger.error(f"Failed to parse Llama JSON: {e}")
            self.logger.error(f"Content was: {content}")
            return []

    def __del__(self):
        if hasattr(self, 'llm') and self.llm:
            del self.llm
