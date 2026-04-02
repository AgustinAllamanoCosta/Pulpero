import pytest
from core.managers.tool.manager import ToolManager
from core.managers.tool.tool import Tool, ToolResult, TooCall
from core.managers.tool.get_file import get_file
from core.managers.tool.create_file import create_file


def make_dummy_tool(name="dummy_tool"):
    def execute(params) -> ToolResult:
        return ToolResult(True, f"executed:{params.get('value', '')}", None)

    return Tool(
        name=name,
        description="A dummy tool for testing",
        properties={"value": {"type": "string", "title": "value", "description": "A value"}},
        required=["value"],
        callback=execute,
    )


def make_tool_call(name, arguments):
    tc = TooCall()
    tc.name = name
    tc.arguments = arguments
    return tc


class TestToolManager:

    def test_register_and_execute_tool(self, logger):
        manager = ToolManager(logger)
        manager.register_tool(make_dummy_tool())
        tc = make_tool_call("dummy_tool", {"value": "hello"})
        result = manager.execute_tool(tc)
        assert result.success is True
        assert "executed:hello" in result.result

    def test_execute_unregistered_tool_returns_failure(self, logger):
        manager = ToolManager(logger)
        tc = make_tool_call("nonexistent", {})
        result = manager.execute_tool(tc)
        assert result.success is False

    def test_multiple_tools_can_be_registered(self, logger):
        manager = ToolManager(logger)
        manager.register_tool(make_dummy_tool("tool_a"))
        manager.register_tool(make_dummy_tool("tool_b"))
        assert manager.execute_tool(make_tool_call("tool_a", {"value": "x"})).success is True
        assert manager.execute_tool(make_tool_call("tool_b", {"value": "y"})).success is True

    def test_registering_same_name_overwrites(self, logger):
        manager = ToolManager(logger)
        first = make_dummy_tool("same_name")
        manager.register_tool(first)

        def execute_v2(params):
            return ToolResult(True, "v2", None)

        second = Tool("same_name", "v2", {}, [], execute_v2)
        manager.register_tool(second)
        result = manager.execute_tool(make_tool_call("same_name", {}))
        assert result.result == "v2"

    def test_get_tool_descriptions_returns_list(self, logger):
        manager = ToolManager(logger)
        manager.register_tool(make_dummy_tool())
        descriptions = manager.get_tool_descriptions()
        assert isinstance(descriptions, list)
        assert len(descriptions) == 1

    def test_get_tool_descriptions_schema_structure(self, logger):
        manager = ToolManager(logger)
        manager.register_tool(make_dummy_tool("my_tool"))
        descriptions = manager.get_tool_descriptions()
        entry = descriptions[0]
        assert entry["type"] == "function"
        assert "function" in entry
        assert entry["function"]["name"] == "my_tool"

    def test_tool_callback_exception_returns_failure(self, logger):
        def bad_callback(params):
            raise RuntimeError("something broke")

        bad_tool = Tool("bad_tool", "breaks", {}, [], bad_callback)
        manager = ToolManager(logger)
        manager.register_tool(bad_tool)
        result = manager.execute_tool(make_tool_call("bad_tool", {}))
        assert result.success is False

    def test_execute_real_get_file_tool(self, logger, tmp_file):
        manager = ToolManager(logger)
        manager.register_tool(get_file(logger))
        tc = make_tool_call("get_file", {"path": tmp_file})
        result = manager.execute_tool(tc)
        assert result.success is True
        assert "hello world" in result.result

    def test_execute_real_create_file_tool(self, logger, tmp_path):
        manager = ToolManager(logger)
        manager.register_tool(create_file(logger))
        target = str(tmp_path / "created.txt")
        tc = make_tool_call("create_file", {"path": target, "content": "test"})
        result = manager.execute_tool(tc)
        assert result.success is True
        assert open(target).read() == "test"
