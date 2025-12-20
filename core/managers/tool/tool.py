from typing import Callable

class ToolResult:

    success: bool = False
    result: dict = {}
    error: str | None = None

    def __init__(self, success: bool, result: dict, error: str | None):
        self.success = success
        self.result = result
        self.error = error

class Tool:

    def __init__(self, name: str, description: str, parameters: dict, example: str, callback: Callable[[dict], ToolResult]) -> None:
        self.name = name
        self.description = description
        self.parameters = parameters
        self.example = example
        self.execute = callback
