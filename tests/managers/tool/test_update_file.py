import pytest
from core.managers.tool.update_file import update_file


class TestUpdateFile:

    def test_returns_tool_with_correct_name(self, logger):
        tool = update_file(logger)
        assert tool.name == "update_file"

    def test_updates_existing_file(self, logger, tmp_file):
        tool = update_file(logger)
        result = tool.callback({"path": tmp_file, "content": "updated content"})
        assert result.success is True
        assert result.result == "file updated"
        assert open(tmp_file).read() == "updated content"

    def test_overwrites_full_content(self, logger, tmp_path):
        f = tmp_path / "overwrite.txt"
        f.write_text("original")
        tool = update_file(logger)
        tool.callback({"path": str(f), "content": "replacement"})
        assert f.read_text() == "replacement"

    def test_fails_when_file_does_not_exist(self, logger, tmp_path):
        tool = update_file(logger)
        result = tool.callback({"path": str(tmp_path / "missing.txt"), "content": "data"})
        assert result.success is False
        assert result.error is not None

    def test_fails_when_path_is_none(self, logger):
        tool = update_file(logger)
        result = tool.callback({"path": None, "content": "data"})
        assert result.success is False

    def test_fails_when_content_is_none(self, logger, tmp_file):
        tool = update_file(logger)
        result = tool.callback({"path": tmp_file, "content": None})
        assert result.success is False

    def test_fails_when_path_is_directory(self, logger, tmp_dir):
        tool = update_file(logger)
        result = tool.callback({"path": tmp_dir, "content": "data"})
        assert result.success is False

    def test_required_params(self, logger):
        tool = update_file(logger)
        assert "path" in tool.required
        assert "content" in tool.required
