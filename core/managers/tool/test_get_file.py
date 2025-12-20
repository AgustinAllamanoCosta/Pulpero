from core.managers.tool.get_file import get_file
from core.managers.tool.create_file import create_file
from core.util.logger import Logger
import pathlib
import os

def test_get_file_tool():
    test_file_path = pathlib.Path(__file__).parent.absolute()
    file_name = 'test_file.txt'
    content = "this is a test file from a automated test"

    logger = Logger("Get file tool test", True)

    create_tool = create_file(logger)
    create_tool.execute({ "path": f"{test_file_path}/{file_name}", "content": content})

    tool = get_file(logger)

    tool_result = tool.execute({ 'path': f"{test_file_path}/{file_name}" })

    assert tool_result.success == True
    os.remove(f"{test_file_path}/{file_name}")
