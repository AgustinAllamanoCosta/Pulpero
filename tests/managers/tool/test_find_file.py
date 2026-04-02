import pytest
from core.managers.tool.find_file import find_file


class TestFindFile:

    def test_returns_tool_with_correct_name(self, logger):
        tool = find_file(logger)
        assert tool.name == "find_file"

    def test_finds_existing_file_by_name(self, logger, tmp_dir):
        tool = find_file(logger)
        result = tool.callback({"name": "file_a.txt", "dir": tmp_dir})
        assert result.success is True
        assert "file_a.txt" in result.result

    def test_finds_nested_file(self, logger, tmp_dir):
        tool = find_file(logger)
        result = tool.callback({"name": "nested.txt", "dir": tmp_dir})
        assert result.success is True
        assert "nested.txt" in result.result

    def test_returns_empty_result_when_file_not_found(self, logger, tmp_dir):
        tool = find_file(logger)
        result = tool.callback({"name": "does_not_exist.xyz", "dir": tmp_dir})
        assert result.success is True
        assert result.result == str({})

    def test_fails_when_name_is_none(self, logger, tmp_dir):
        tool = find_file(logger)
        result = tool.callback({"name": None, "dir": tmp_dir})
        assert result.success is False

    def test_fails_when_dir_is_none(self, logger):
        tool = find_file(logger)
        result = tool.callback({"name": "file.txt", "dir": None})
        assert result.success is False

    def test_supports_wildcard_name(self, logger, tmp_dir):
        tool = find_file(logger)
        result = tool.callback({"name": "*.py", "dir": tmp_dir})
        assert result.success is True
        assert "file_b.py" in result.result

    def test_required_params(self, logger):
        tool = find_file(logger)
        assert "name" in tool.required
        assert "dir" in tool.required
