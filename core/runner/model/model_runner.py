import os
from typing import cast
from llama_cpp import ChatCompletionRequestMessage, ChatCompletionTool, CreateChatCompletionResponse, Llama
from core.managers.tool.tool import TooCall
from core.util.logger import Logger

class ModelResponse:
    message: str
    tool_calls: list[TooCall]

    def __init__(self, message: str, tool_calls: list[TooCall]) -> None:
        self.message = message
        self.tool_calls = tool_calls

    def __str__(self) -> str:
        return self.message

class RunnerConfig:
    context_window: int
    temp: float
    num_threads: int
    top_p:float
    model_name: str
    model_path: str
    llama_repo: str
    os: str
    pulpero_ready: bool
    response_size: int

    def __init__(self, context_window: int, temp: float, num_threads: int, top_p:float, model_name: str, model_path: str, llama_repo: str, os: str, pulpero_ready: bool, response_size: int) -> None:

        self.context_window = context_window
        self.temp= temp
        self.num_threads= num_threads
        self.top_p = top_p
        self.model_name = model_name
        self.model_path = model_path
        self.llama_repo = llama_repo
        self.os = os
        self.pulpero_ready = pulpero_ready
        self.response_size = response_size

    def __str__(self) -> str:
        return f'''
    context_window: {self.context_window}
    temp: {self.temp}
    num_threads: {self.num_threads}
    top_p: {self.top_p}
    model_name: {self.model_name}
    model_path: {self.model_path}
    llama_repo: {self.llama_repo}
    os: {self.os}
    pulpero_ready: {self.pulpero_ready}
    response_size: {self.response_size}
    '''

class Runner:

    def __init__(self, config: RunnerConfig, logger: Logger) -> None:
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
                n_gpu_layers=14,  # Equivalent to -ngl 14
                n_batch=256,      # Equivalent to -b 256
                verbose=False,
                use_mmap=True,
                use_mlock=False,
                rope_scaling_type=None,
                rope_freq_base=10000.0,
                rope_freq_scale=1.0,
            )
            self.logger.debug("Llama ccp model initialized successfully")
        except Exception as e:
            self.logger.error(f"Failed to initialize Llama model: {e}")
            raise

    def run_local_model(self, history: list[ChatCompletionRequestMessage], config: RunnerConfig, tools: list[ChatCompletionTool]) -> CreateChatCompletionResponse:
        try:

            self.logger.debug("Generating response with Llama ccp")

            llama_completion = self.llm.create_chat_completion(
                messages=history,
                max_tokens=config.response_size,
                temperature=config.temp,
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

    def talk_with_model(self, history: list[dict], tools: list[dict]) -> ModelResponse:

        model_response = ModelResponse("", [])
        raw_responses = self.run_local_model(
            cast(list[ChatCompletionRequestMessage], history),
            self.config,
            cast(list[ChatCompletionTool], tools)
        )

        self.logger.info("raw model response ", raw_responses)
        if raw_responses.get('choices').__len__() > 0:
            completion = raw_responses.get('choices')[0]
            content = completion.get('message').get('content')
            if content != None:
                if content.startswith('{'):
                    model_response.tool_calls = self.parse_function_call(content)
                else:
                    model_response.message = content

        return model_response

    def parse_function_call(self, content: str):
        import json
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
