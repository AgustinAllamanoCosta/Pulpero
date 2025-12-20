from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger
import subprocess

def find_file(logger: Logger) -> Tool:
    def execute(params) -> ToolResult:
        if params["name"] == None:
            return ToolResult(False, {},"File name is require")

        if params["dir"] == None:
            return ToolResult(False, {},"Working dir is require")

        result: dict = {}
        paths = subprocess.run(["find", params['dir'],"-name", params['name']], capture_output=True, text=True)
        index = 1
        for path in paths.stdout.splitlines():
            result[index] = path
            index = index + 1

        return ToolResult(True, result, None)

    return Tool(
            "find_file",
            "Find a file recursive in the working dir",
            {
            'name': {
                'type': "string",
                'description': "Name of the file to find"
                },
            'dir': {
                'type': "string",
                'description': "Directory where to search for the file"
                }
            },
            "<tool name=\"find_file\" params=\"name=NAME_OF_THE_FILE dir=PATH_OF_FOLDER_TO_SEARCH\" />",
            execute
            )
