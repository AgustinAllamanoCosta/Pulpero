import pytest
from core.managers.tool.list_directory import list_directory


class TestListDirectory:

    def test_returns_tool_with_correct_name(self, logger):
        tool = list_directory(logger)
        assert tool.name == "list_directory"

    def test_lists_files_in_directory(self, logger, tmp_dir):
        tool = list_directory(logger)
        result = tool.callback({"path": tmp_dir})
        assert result.success is True
        assert "file_a.txt" in result.result
        assert "file_b.py" in result.result

    def test_marks_subdirectories_with_slash(self, logger, tmp_dir):
        tool = list_directory(logger)
        result = tool.callback({"path": tmp_dir})
        assert "subdir/" in result.result

    def test_does_not_recurse_into_subdirectories(self, logger, tmp_dir):
        tool = list_directory(logger)
        result = tool.callback({"path": tmp_dir})
        assert "nested.txt" not in result.result

    def test_entries_are_newline_separated(self, logger, tmp_dir):
        tool = list_directory(logger)
        result = tool.callback({"path": tmp_dir})
        lines = result.result.strip().splitlines()
        assert len(lines) >= 3

    def test_fails_when_path_is_none(self, logger):
        tool = list_directory(logger)
        result = tool.callback({"path": None})
        assert result.success is False

    def test_fails_when_path_does_not_exist(self, logger, tmp_path):
        tool = list_directory(logger)
        result = tool.callback({"path": str(tmp_path / "nonexistent")})
        assert result.success is False

    def test_fails_when_path_is_a_file(self, logger, tmp_file):
        tool = list_directory(logger)
        result = tool.callback({"path": tmp_file})
        assert result.success is False

    def test_required_params(self, logger):
        tool = list_directory(logger)
        assert "path" in tool.required
