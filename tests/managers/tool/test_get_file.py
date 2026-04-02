import pytest
from core.managers.tool.get_file import get_file


class TestGetFile:

    def test_returns_tool_with_correct_name(self, logger):
        tool = get_file(logger)
        assert tool.name == "get_file"

    def test_reads_existing_file(self, logger, tmp_file):
        tool = get_file(logger)
        result = tool.callback({"path": tmp_file})
        assert result.success is True
        assert "hello world" in result.result
        assert result.error is None

    def test_reads_full_content(self, logger, tmp_path):
        f = tmp_path / "full.txt"
        content = "line one\nline two\nline three"
        f.write_text(content)
        tool = get_file(logger)
        result = tool.callback({"path": str(f)})
        assert result.result == content

    def test_fails_when_path_is_none(self, logger):
        tool = get_file(logger)
        result = tool.callback({"path": None})
        assert result.success is False
        assert result.result == ""

    def test_fails_when_path_missing_from_params(self, logger):
        # get_file uses params["path"] (not .get), so a missing key raises KeyError
        # which ToolManager.execute_tool catches — tested here at the tool level
        import pytest
        tool = get_file(logger)
        with pytest.raises(KeyError):
            tool.callback({})

    def test_fails_when_file_does_not_exist(self, logger, tmp_path):
        tool = get_file(logger)
        result = tool.callback({"path": str(tmp_path / "nonexistent.txt")})
        assert result.success is False
        assert result.error is not None

    def test_required_params_list(self, logger):
        tool = get_file(logger)
        assert "path" in tool.required
