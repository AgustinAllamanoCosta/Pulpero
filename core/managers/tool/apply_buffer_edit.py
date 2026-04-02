from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger

def apply_buffer_edit(logger: Logger, pending_edit_store: dict) -> Tool:
    def execute(params) -> ToolResult:
        path = params.get("path")
        content = params.get("content")

        if path is None or path == "":
            return ToolResult(False, '', Exception("Path is required"))

        if content is None:
            return ToolResult(False, '', Exception("Content is required"))

        logger.debug(f"Queuing buffer edit for path: {path}")

        pending_edit_store["path"] = path
        pending_edit_store["content"] = content

        return ToolResult(True, "Edit queued for buffer", None)

    return Tool(
        "apply_buffer_edit",
        "Apply an edit directly to the currently open editor buffer. Use this ONLY when the file to edit is the currently open file in the editor — i.e. when the target path matches current_file_path from the conversation context. Does not write to disk.",
        {
            "path": {
                "type": "string",
                "title": "path",
                "description": "The absolute path of the currently open file to edit (must match current_file_path from context)"
            },
            "content": {
                "type": "string",
                "title": "content",
                "description": "The complete new content to replace the entire file buffer with"
            }
        },
        ['path', 'content'],
        execute
    )
