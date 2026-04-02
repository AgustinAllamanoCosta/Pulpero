import pytest
from core.managers.tool.apply_buffer_edit import apply_buffer_edit


class TestApplyBufferEdit:

    def test_returns_tool_with_correct_name(self, logger):
        store = {}
        tool = apply_buffer_edit(logger, store)
        assert tool.name == "apply_buffer_edit"

    def test_queues_edit_in_store(self, logger):
        store = {}
        tool = apply_buffer_edit(logger, store)
        result = tool.callback({"path": "/some/file.py", "content": "new content"})
        assert result.success is True
        assert result.result == "Edit queued for buffer"
        assert store["path"] == "/some/file.py"
        assert store["content"] == "new content"

    def test_does_not_write_to_disk(self, logger, tmp_path):
        target = tmp_path / "buffer.py"
        target.write_text("original")
        store = {}
        tool = apply_buffer_edit(logger, store)
        tool.callback({"path": str(target), "content": "changed"})
        assert target.read_text() == "original"

    def test_overwrites_previous_store_entry(self, logger):
        store = {}
        tool = apply_buffer_edit(logger, store)
        tool.callback({"path": "/first.py", "content": "first"})
        tool.callback({"path": "/second.py", "content": "second"})
        assert store["path"] == "/second.py"
        assert store["content"] == "second"

    def test_fails_when_path_is_none(self, logger):
        store = {}
        tool = apply_buffer_edit(logger, store)
        result = tool.callback({"path": None, "content": "data"})
        assert result.success is False
        assert store == {}

    def test_fails_when_path_is_empty_string(self, logger):
        store = {}
        tool = apply_buffer_edit(logger, store)
        result = tool.callback({"path": "", "content": "data"})
        assert result.success is False
        assert store == {}

    def test_fails_when_content_is_none(self, logger):
        store = {}
        tool = apply_buffer_edit(logger, store)
        result = tool.callback({"path": "/file.py", "content": None})
        assert result.success is False
        assert store == {}

    def test_required_params(self, logger):
        store = {}
        tool = apply_buffer_edit(logger, store)
        assert "path" in tool.required
        assert "content" in tool.required
