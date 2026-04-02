import pytest
from core.managers.tool.create_file import create_file


class TestCreateFile:

    def test_returns_tool_with_correct_name(self, logger):
        tool = create_file(logger)
        assert tool.name == "create_file"

    def test_creates_new_file(self, logger, tmp_path):
        tool = create_file(logger)
        target = str(tmp_path / "new_file.txt")
        result = tool.callback({"path": target, "content": "hello"})
        assert result.success is True
        assert result.result == "file created"
        assert open(target).read() == "hello"

    def test_writes_correct_content(self, logger, tmp_path):
        tool = create_file(logger)
        target = str(tmp_path / "content.txt")
        content = "line one\nline two\nline three"
        tool.callback({"path": target, "content": content})
        assert open(target).read() == content

    def test_fails_when_file_already_exists(self, logger, tmp_file):
        tool = create_file(logger)
        result = tool.callback({"path": tmp_file, "content": "new content"})
        assert result.success is False
        assert result.error is not None

    def test_fails_when_path_is_none(self, logger):
        tool = create_file(logger)
        result = tool.callback({"path": None, "content": "data"})
        assert result.success is False

    def test_fails_when_content_is_none(self, logger, tmp_path):
        tool = create_file(logger)
        result = tool.callback({"path": str(tmp_path / "x.txt"), "content": None})
        assert result.success is False

    def test_required_params(self, logger):
        tool = create_file(logger)
        assert "path" in tool.required
        assert "content" in tool.required
