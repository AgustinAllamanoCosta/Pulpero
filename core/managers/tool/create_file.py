from core.managers.tool.tool import Tool
from core.managers.tool.manager import ToolResult
import os

def create_file(logger) -> Tool:
    def execute(params) -> ToolResult:
        if params["path"] == None:
            return ToolResult(False, {},"Path is required")

        if params["content"] == None:
            return ToolResult(False, {},"Content is required")

        if os.path.exists(params["path"]) == True:
            return ToolResult(False, {},"Can not create a file if already exists")

        logger.debug(f"Creating file in path: {params['path']}")

        with open(params["path"], 'w', encoding='utf-8') as f:
            f.write(params["content"])
            f.close()

        return ToolResult(True, { 'result': 'file created' }, None)

    return Tool(
        "create_file",
        "Create a file in the given directory",
        {
            "path": {
                "type": "string",
                "description": "The file path"
            },
            "content": {
                "type": "string",
                "description": "The content of the file"
            }
        },
        "<tool name=\"create_file\" params=\"path=EXACT_PATH, content=CONTENT_OF_THE_FILE\" />",
        execute
    )
