from core.managers.tool.tool import Tool, ToolResult
from core.util.logger import Logger
import subprocess

def find_file(logger: Logger) -> Tool:
    def execute(params) -> ToolResult:
        if params["name"] == None:
            return ToolResult(False, {}, Exception("File name is require"))

        if params["dir"] == None:
            return ToolResult(False, {}, Exception("Working dir is require"))

        result: dict = {}
        paths = subprocess.run(["find", params['dir'],"-name", params['name']], capture_output=True, text=True)
        index = 1

        try:
            for path in paths.stdout.splitlines():
                result[index] = path
                index = index + 1

            return ToolResult(True, str(result), None)
        except Exception as e:
            return ToolResult(False, '', e)

    return Tool(
        "find_file",
        "Find a file recursive in the working dir",
        {
        'name': {
            'type': "string",
            "title": "name",
            'description': "Name of the file to find"
            },
        'dir': {
            'type': "string",
            "title": "dir",
            'description': "Directory where to search for the file"
            }
        },
        ['name','dir'],
        execute
    )
