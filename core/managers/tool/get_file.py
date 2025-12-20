from core.managers.tool.tool import ToolResult, Tool
from core.util.logger import Logger

def get_file(logger: Logger) -> Tool:
    def execute(params) -> ToolResult:
        if params["path"] == None:
            return ToolResult(False, {}, "Path is required")

        logger.debug(f"Looking for file content {params['path']}")
        response: str = ""
        with open(params["path"], 'r', encoding='utf-8') as f:
            response = f.read()
            f.close()
        return ToolResult(True, { 'response': response }, None)

    return Tool(
            "get_file",
            "Get the content of a file by path",
            {
                'path': {
                    'type': "string",
                    'description': "The file path"
                }
            },
            "<tool name=\"get_file\" params=\"path=EXACT_PATH\" />",
            execute
            )
