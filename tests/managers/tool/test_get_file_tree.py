import pytest
from core.managers.tool.get_file_tree import get_file_tree


class TestGetFileTree:

    def test_returns_tool_with_correct_name(self, logger):
        tool = get_file_tree(logger)
        assert tool.name == "get_file_tree"

    def test_builds_tree_for_directory(self, logger, tmp_dir):
        tool = get_file_tree(logger)
        result = tool.callback({"path": tmp_dir})
        assert result.success is True
        assert "file_a.txt" in result.result
        assert "file_b.py" in result.result
        assert "subdir" in result.result

    def test_recurses_into_subdirectories(self, logger, tmp_dir):
        tool = get_file_tree(logger)
        result = tool.callback({"path": tmp_dir})
        assert "nested.txt" in result.result

    def test_respects_max_depth(self, logger, tmp_path):
        deep = tmp_path / "a" / "b" / "c"
        deep.mkdir(parents=True)
        (deep / "deep_file.txt").write_text("deep")
        tool = get_file_tree(logger)
        result = tool.callback({"path": str(tmp_path), "max_depth": 1})
        assert "deep_file.txt" not in result.result

    def test_excludes_git_directory(self, logger, tmp_path):
        git_dir = tmp_path / ".git"
        git_dir.mkdir()
        (git_dir / "config").write_text("git config")
        tool = get_file_tree(logger)
        result = tool.callback({"path": str(tmp_path)})
        assert ".git" not in result.result

    def test_excludes_pycache(self, logger, tmp_path):
        cache = tmp_path / "__pycache__"
        cache.mkdir()
        (cache / "module.pyc").write_text("bytecode")
        tool = get_file_tree(logger)
        result = tool.callback({"path": str(tmp_path)})
        assert "__pycache__" not in result.result

    def test_defaults_max_depth_to_3(self, logger, tmp_path):
        # _build_tree starts at current_depth=1 for root's children.
        # a/ is depth 1, b/ is depth 2, file is inside b/ so listed at depth 2.
        a = tmp_path / "a"
        b = a / "b"
        b.mkdir(parents=True)
        (b / "level2.txt").write_text("two")
        tool = get_file_tree(logger)
        result = tool.callback({"path": str(tmp_path)})
        assert "level2.txt" in result.result

    def test_invalid_max_depth_falls_back_to_default(self, logger, tmp_dir):
        tool = get_file_tree(logger)
        result = tool.callback({"path": tmp_dir, "max_depth": "bad_value"})
        assert result.success is True

    def test_fails_when_path_is_none(self, logger):
        tool = get_file_tree(logger)
        result = tool.callback({"path": None})
        assert result.success is False

    def test_fails_when_path_does_not_exist(self, logger, tmp_path):
        tool = get_file_tree(logger)
        result = tool.callback({"path": str(tmp_path / "nonexistent")})
        assert result.success is False

    def test_fails_when_path_is_a_file(self, logger, tmp_file):
        tool = get_file_tree(logger)
        result = tool.callback({"path": tmp_file})
        assert result.success is False

    def test_required_params(self, logger):
        tool = get_file_tree(logger)
        assert "path" in tool.required
