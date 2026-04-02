import sys
import pytest
from unittest.mock import MagicMock
from core.managers.tool.web_search import web_search


def make_ddgs_mock(results):
    """Inject a fake duckduckgo_search module into sys.modules."""
    mock_instance = MagicMock()
    mock_instance.text.return_value = results
    mock_instance.__enter__ = MagicMock(return_value=mock_instance)
    mock_instance.__exit__ = MagicMock(return_value=False)

    mock_ddgs_class = MagicMock(return_value=mock_instance)
    mock_module = MagicMock()
    mock_module.DDGS = mock_ddgs_class

    return mock_module, mock_instance


class TestWebSearch:

    def test_returns_tool_with_correct_name(self, logger):
        tool = web_search(logger)
        assert tool.name == "web_search"

    def test_fails_when_query_is_none(self, logger):
        tool = web_search(logger)
        result = tool.callback({"query": None})
        assert result.success is False

    def test_fails_when_query_missing(self, logger):
        tool = web_search(logger)
        result = tool.callback({})
        assert result.success is False

    def test_returns_not_installed_error_when_package_missing(self, logger):
        # Simulate duckduckgo_search not installed
        original = sys.modules.pop("duckduckgo_search", None)
        try:
            tool = web_search(logger)
            result = tool.callback({"query": "test"})
            assert result.success is False
            assert "duckduckgo" in result.error.lower() or "not installed" in result.error.lower()
        finally:
            if original is not None:
                sys.modules["duckduckgo_search"] = original

    def test_returns_formatted_results(self, logger):
        raw = [
            {"title": "Result One", "href": "https://example.com/1", "body": "First snippet"},
            {"title": "Result Two", "href": "https://example.com/2", "body": "Second snippet"},
        ]
        mock_module, _ = make_ddgs_mock(raw)
        sys.modules["duckduckgo_search"] = mock_module
        try:
            tool = web_search(logger)
            result = tool.callback({"query": "test query"})
        finally:
            sys.modules.pop("duckduckgo_search", None)

        assert result.success is True
        assert "Result One" in result.result
        assert "https://example.com/1" in result.result
        assert "First snippet" in result.result

    def test_returns_no_results_message_when_empty(self, logger):
        mock_module, _ = make_ddgs_mock([])
        sys.modules["duckduckgo_search"] = mock_module
        try:
            tool = web_search(logger)
            result = tool.callback({"query": "nothing here"})
        finally:
            sys.modules.pop("duckduckgo_search", None)

        assert result.success is True
        assert "No results" in result.result

    def test_respects_max_results_param(self, logger):
        raw = [{"title": f"R{i}", "href": f"https://x.com/{i}", "body": f"s{i}"} for i in range(3)]
        mock_module, mock_instance = make_ddgs_mock(raw)
        sys.modules["duckduckgo_search"] = mock_module
        try:
            tool = web_search(logger)
            result = tool.callback({"query": "test", "max_results": 3})
        finally:
            sys.modules.pop("duckduckgo_search", None)

        assert result.success is True
        mock_instance.text.assert_called_once()
        call_kwargs = mock_instance.text.call_args
        assert call_kwargs.kwargs.get("max_results") == 3 or (call_kwargs.args and call_kwargs.args[1] == 3)

    def test_handles_search_exception(self, logger):
        mock_module, mock_instance = make_ddgs_mock([])
        mock_instance.text.side_effect = Exception("Network error")
        sys.modules["duckduckgo_search"] = mock_module
        try:
            tool = web_search(logger)
            result = tool.callback({"query": "failing query"})
        finally:
            sys.modules.pop("duckduckgo_search", None)

        assert result.success is False

    def test_required_params(self, logger):
        tool = web_search(logger)
        assert "query" in tool.required
