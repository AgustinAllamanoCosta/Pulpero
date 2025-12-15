from core.managers.tool.tool import Tool
from core.util.logger import Logger

class ToolResult:

    success: bool = False
    result: dict = {}
    error: str | None = None

    def __init__(self, success: bool, result: dict, error: str | None):
        self.success = success
        self.result = result
        self.error = error

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
            for tool in tools:
                tool_descriptions = tool_descriptions + f"\n- Tool Name: \"{tool['name']}\"\nDescription: \"{tool['description']}\"\nCall Example: \"{tool['call_example']}\"\n"
        return tool_descriptions

    def parse_tool_calls(self, model_output: str) -> dict:
        tool_calls: dict = {}

        #Buscar como hacer un match de las regex en python
        for tool_name, params_str in model_output:gmatch("<tool%s+name=\"(.*)\"%s+params=\"(.*)\"%s+/>") do
            local params = {}
            for param, value in params_str:gmatch("([^=,]+)=([^,]+)") do
                params[param:gsub("%s+", ""):gsub("\n", "")] = value

            table.insert(tool_calls, {
                name = tool_name,
                params = params
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
        tool_calls: dict = self.parse_tool_calls(model_response_with_tool_call)
        tool_response: str = ""
        if(len(tool_calls.keys()) > 0):
            tool_response = self.process_tool_call(tool_calls[1])
        else:
            tool_response = model_response_with_tool_call
        return tool_response
