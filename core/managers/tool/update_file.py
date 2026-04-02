import os
from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger

def update_file(logger: Logger) -> Tool:
    def execute(params) -> ToolResult:
        if params.get("path") is None:
            return ToolResult(False, '', Exception("Path is required"))

        if params.get("content") is None:
            return ToolResult(False, '', Exception("Content is required"))

        path = params["path"]
        content = params["content"]

        if not os.path.exists(path):
            return ToolResult(False, '', Exception(f"Cannot update a file that does not exist: {path}"))

        if not os.path.isfile(path):
            return ToolResult(False, '', Exception(f"Path is not a file: {path}"))

        logger.debug(f"Updating file at path: {path}")

        try:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            return ToolResult(True, 'file updated', None)
        except Exception as e:
            return ToolResult(False, '', e)

    return Tool(
        "update_file",
        "Overwrite the content of an existing file on disk. Use this for files that are NOT currently open in the editor. Fails if the file does not exist.",
        {
            "path": {
                "type": "string",
                "title": "path",
                "description": "The absolute file path to the existing file to update"
            },
            "content": {
                "type": "string",
                "title": "content",
                "description": "The complete new content to write to the file"
            }
        },
        ['path', 'content'],
        execute
    )
