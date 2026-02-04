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

    def execute_tool(self, tool_call: TooCall) -> ToolResult:
        tool = self.tools.get(tool_call.name)
        self.logger.info("tool found ", tool)
        if tool != None:
            return tool.callback(tool_call.arguments)
        else:
            return ToolResult(False, {}, "Tool not found")

