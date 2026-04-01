import os
from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger

EXCLUDED_DIRS = {
    ".git", "__pycache__", "node_modules", "venv", ".venv",
    ".idea", ".vscode", "dist", "build", ".mypy_cache", ".pytest_cache"
}


def get_file_tree(logger: Logger) -> Tool:
    def _build_tree(path: str, max_depth: int, current_depth: int, prefix: str) -> list[str]:
        if current_depth > max_depth:
            return []

        try:
            entries = sorted(os.listdir(path))
        except PermissionError:
            return []

        lines = []
        for i, entry in enumerate(entries):
            if entry in EXCLUDED_DIRS:
                continue

            full = os.path.join(path, entry)
            connector = "└── " if i == len(entries) - 1 else "├── "
            extension = "/" if os.path.isdir(full) else ""
            lines.append(f"{prefix}{connector}{entry}{extension}")

            if os.path.isdir(full):
                child_prefix = prefix + ("    " if i == len(entries) - 1 else "│   ")
                lines.extend(_build_tree(full, max_depth, current_depth + 1, child_prefix))

        return lines

    def execute(params) -> ToolResult:
        path = params.get("path")
        if path is None:
            return ToolResult(False, '', "Path is required")

        if not os.path.exists(path):
            return ToolResult(False, '', f"Path does not exist: {path}")

        if not os.path.isdir(path):
            return ToolResult(False, '', f"Path is not a directory: {path}")

        try:
            max_depth = int(params.get("max_depth", 3))
        except (ValueError, TypeError):
            max_depth = 3

        logger.debug(f"Building file tree for: {path} (max_depth={max_depth})")

        try:
            lines = [os.path.basename(path) + "/"]
            lines.extend(_build_tree(path, max_depth, 1, ""))
            return ToolResult(True, '\n'.join(lines), None)
        except Exception as e:
            return ToolResult(False, '', str(e))

    return Tool(
        "get_file_tree",
        "Get a recursive directory tree from a root path. Excludes common noise directories like .git, node_modules, __pycache__.",
        {
            "path": {
                "type": "string",
                "title": "path",
                "description": "The root directory path to build the tree from"
            },
            "max_depth": {
                "type": "integer",
                "title": "max_depth",
                "description": "Maximum depth to recurse into subdirectories (default: 3)"
            }
        },
        ["path"],
        execute
    )
