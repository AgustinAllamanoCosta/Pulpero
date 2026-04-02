import pytest
from core.util.logger import Logger


@pytest.fixture
def logger():
    return Logger("test", test_env=True)


@pytest.fixture
def tmp_file(tmp_path):
    """A temporary file pre-populated with content."""
    f = tmp_path / "test_file.txt"
    f.write_text("hello world\nline two\nline three\n")
    return str(f)


@pytest.fixture
def tmp_dir(tmp_path):
    """A temporary directory with a few files and subdirectories."""
    (tmp_path / "file_a.txt").write_text("aaa")
    (tmp_path / "file_b.py").write_text("bbb")
    sub = tmp_path / "subdir"
    sub.mkdir()
    (sub / "nested.txt").write_text("nested")
    return str(tmp_path)
