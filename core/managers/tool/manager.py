from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger
import re

class ToolManager:

    def __init__(self, log: Logger) -> None:
        self.tools: dict[str, Tool] = {}
        self.logger: Logger = log

    def register_tool(self, tool: Tool) -> None:
        self.tools[tool.name] = tool
        self.logger.debug(f"Registered tool: {tool.name} ")

    def get_tool_descriptions(self) -> dict:
        descriptions: dict = {}
        for name, tool in self.tools.items():
            descriptions[name] = {
                    "name": name,
                    "description": tool.description,
                    "parameters": tool.parameters,
                    "call_example": tool.example
                }
        return descriptions

    def execute_tool(self,tool_name: str, params: dict) -> ToolResult:
        tool: Tool | None = self.tools[tool_name]
        if tool == None:
            self.logger.error(f"Tool not found: {tool_name}")
            return { "success": False, "error": f"Tool not found: {tool_name}"}
        tool_response: ToolResult = tool.execute(params)
        return tool_response

    def generate_tools_description(self) -> str:
        tool_descriptions: str = ""
        tools: dict = self.get_tool_descriptions()
        if(len(tools.keys()) > 0):
            for tool_key in tools:
                tool = tools[tool_key]
                tool_descriptions = tool_descriptions + f"\n- Tool Name: \"{tool['name']}\"\nDescription: \"{tool['description']}\"\nCall Example: \"{tool['call_example']}\"\n"
        return tool_descriptions

    def parse_tool_calls(self, model_output: str) -> list[dict]:
        tool_calls = []
        pattern = r'<tool\s+name="([^"]*)"\s+params="([^"]*)"\s+/>'
        matches = re.findall(pattern, model_output)
        for tool_name, params_str in matches:
            params = {}
            param_pattern = r'([^=,]+)=([^,]+)'
            param_matches = re.findall(param_pattern, params_str)
            for param, value in param_matches:
                clean_param = param.strip().replace('\n', '')
                params[clean_param] = value
            tool_calls.append({
                'name': tool_name,
                'params': params
            })
        return tool_calls

    def process_tool_call(self, tool_call: dict) -> str:
        self.logger.debug(f"Executing tool call {tool_call['name']}")
        tool_result: ToolResult = self.execute_tool(tool_call["name"], tool_call["params"])
        result_str: str = ""
        if(tool_result.success):
            result_str = f"\nTool Result\nname: \"{tool_call['name']}\"\nsuccess:\"true\"\nresult:\n\"{tool_result.result}\""
        else:
            result_str = f"\nTool Result\nname: \"{tool_call['name']}\"\nsuccess: \"false\"\nerror:\"{tool_result.error}\""
        self.logger.debug(f"Tool executed {result_str}")
        return result_str

    def execute_tool_if_exist_call(self, model_response_with_tool_call: str) -> str:
        tool_calls: list[dict] = self.parse_tool_calls(model_response_with_tool_call)
        tool_response: str = ""
        if(len(tool_calls) > 0):
            tool_response = self.process_tool_call(tool_calls[0])
        else:
            tool_response = model_response_with_tool_call
        return tool_response
