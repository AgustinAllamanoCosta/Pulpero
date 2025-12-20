import os
import pathlib
from core.managers.tool.manager import ToolManager
from core.managers.tool.tools import tools
from core.util.logger import Logger

def test_tool_manager_should_register_a_tool():

    logger = Logger("Manager tool test", True)

    manager = ToolManager(logger)

    manager.register_tool(tools['create_create_file_tool'](logger))

    expected_description = {'create_file': {'name': 'create_file', 'description': 'Create a file in the given directory', 'parameters': {'path': {'type': 'string', 'description': 'The file path'}, 'content': {'type': 'string', 'description': 'The content of the file'}}, 'call_example': '<tool name="create_file" params="path=EXACT_PATH, content=CONTENT_OF_THE_FILE" />'}}
    tool_descriptions = manager.get_tool_descriptions()

    assert expected_description == tool_descriptions

def test_tool_manager_should_genereta_description_for_llm():

    logger = Logger("Manager tool test", True)

    manager = ToolManager(logger)

    manager.register_tool(tools['create_create_file_tool'](logger))

    tool_descriptions = manager.generate_tools_description()
    expected_tool_descriptions = '\n- Tool Name: "create_file"\nDescription: "Create a file in the given directory"\nCall Example: "<tool name="create_file" params="path=EXACT_PATH, content=CONTENT_OF_THE_FILE" />"\n'

    assert expected_tool_descriptions == tool_descriptions

def test_tool_manager_should_parse_tool_call():

    logger = Logger("Manager tool test", True)

    test_file_path = pathlib.Path(__file__).parent.absolute()
    file_name = 'test_file.txt'
    content = "this is a test file from a automated test"
    complete_path = f"{test_file_path}/{file_name}"

    manager = ToolManager(logger)

    manager.register_tool(tools['create_create_file_tool'](logger))

    model_output = f'<tool name="create_file" params="path={complete_path}, content={content}" />'
    tool_parsed = manager.parse_tool_calls(model_output)

    expected_tool_parse = [{'name': 'create_file', 'params': {'path': f'{complete_path}', 'content': f'{content}'}}]

    assert tool_parsed == expected_tool_parse

def test_tool_manager_should_execute_a_tool_if_exist():

    logger = Logger("Manager tool test", True)

    test_file_path = pathlib.Path(__file__).parent.absolute()
    file_name = 'test_file.txt'
    content = "this is a test file from a automated test"
    complete_path = f"{test_file_path}/{file_name}"

    manager = ToolManager(logger)

    manager.register_tool(tools['create_create_file_tool'](logger))

    model_output = f'<tool name="create_file" params="path={complete_path}, content={content}" />'
    tool_result = manager.execute_tool_if_exist_call(model_output)

    expected_tool_result = "\nTool Result\nname: \"create_file\"\nsuccess:\"true\"\nresult:\n\"{'result': 'file created'}\""

    assert tool_result == expected_tool_result
    os.remove(f"{test_file_path}/{file_name}")
