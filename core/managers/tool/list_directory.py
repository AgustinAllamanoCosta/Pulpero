import os
from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger


def list_directory(logger: Logger) -> Tool:
    def execute(params) -> ToolResult:
        path = params.get("path")
        if path is None:
            return ToolResult(False, '', "Path is required")

        if not os.path.exists(path):
            return ToolResult(False, '', f"Path does not exist: {path}")

        if not os.path.isdir(path):
            return ToolResult(False, '', f"Path is not a directory: {path}")

        logger.debug(f"Listing directory: {path}")

        try:
            entries = sorted(os.listdir(path))
            lines = []
            for entry in entries:
                full = os.path.join(path, entry)
                if os.path.isdir(full):
                    lines.append(f"{entry}/")
                else:
                    lines.append(entry)
            return ToolResult(True, '\n'.join(lines), None)
        except Exception as e:
            return ToolResult(False, '', str(e))

    return Tool(
        "list_directory",
        "List files and subdirectories at a given path (one level deep)",
        {
            "path": {
                "type": "string",
                "title": "path",
                "description": "The directory path to list"
            }
        },
        ["path"],
        execute
    )
