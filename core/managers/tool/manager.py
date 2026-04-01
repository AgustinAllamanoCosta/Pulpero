from core.managers.tool.tool import TooCall, Tool, ToolResult
from core.util.logger import Logger

class ToolManager:

    def __init__(self, log: Logger) -> None:
        self.tools: dict[str, Tool] = {}
        self.logger: Logger = log

    def register_tool(self, tool: Tool) -> None:
        self.tools[tool.name] = tool
        self.logger.debug(f"Registered tool: {tool.name} ")

    def get_tool_descriptions(self) -> list[dict]:
        descriptions: list[dict] = []
        for name, tool in self.tools.items():
            descriptions.append({
                    "type": "function",
                    "function": {
                        "name": name,
                        "description": tool.description,
                        "parameters": {
                            "type": "object",
                            "properties": tool.properties,
                            "required": tool.required
                        },
                    }
                })
        return descriptions

    def generate_schemas(self):
        schema = []
        for name, tool in self.tools.items():
            schema.append({
                        "properties": {
                            "function": {"const": name},
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "properties": {
                                        "type": "object",
                                        "properties": tool.properties,
                                        "required": tool.required
                                    }
                                }
                            }
                        }
                    })
        return {
            "type": "object",
            "oneOf": schema,
            "required": ["function", "parameters"]
        }

    def execute_tool(self, tool_call: TooCall) -> ToolResult:
        tool = self.tools.get(tool_call.name)
        if tool is None:
            self.logger.error(f"Tool not found: {tool_call.name}")
            return ToolResult(False, '', f"Tool '{tool_call.name}' is not registered")

        try:
            tool_result = tool.callback(tool_call.arguments)
        except Exception as e:
            self.logger.error(f"Tool '{tool_call.name}' raised an unexpected exception: {e}")
            return ToolResult(False, '', str(e))

        self.logger.info("Raw tool execution result ", tool_result.result)
        return tool_result
