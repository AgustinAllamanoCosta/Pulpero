from typing import Callable, List

class ToolResult:

    success: bool = False
    result: str
    error: str | None = None

    def __init__(self, success: bool, result: str, error: str | None):
        self.success = success
        self.result = result
        self.error = error

class Tool:

    name: str
    description: str
    properties: dict
    example: str
    required: List[str]
    callback: Callable[[dict], ToolResult]

    def __init__(self, name: str, description: str, properties: dict, required: List[str], callback: Callable[[dict], ToolResult]) -> None:
        self.name = name
        self.description = description
        self.properties = properties
        self.required = required
        self.callback = callback

class TooCall:
    name: str
    arguments: dict
