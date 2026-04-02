import pytest
from unittest.mock import MagicMock
from core.managers.hints.manager import HintsManager, Hint, PIPELINE_HINT_TYPES, SUMMARIZATION_THRESHOLD
from core.managers.history.manager import HistoryManager


def make_mock_runner(response_message="summary of content"):
    runner = MagicMock()
    response = MagicMock()
    response.message = response_message
    runner.talk_with_model.return_value = response
    return runner


class TestHint:

    def test_hint_stores_fields(self):
        h = Hint(key="get_file:/foo.py", hint_type="file", content="some code")
        assert h.key == "get_file:/foo.py"
        assert h.hint_type == "file"
        assert h.content == "some code"
        assert h.summary is None

    def test_hint_summary_defaults_to_none(self):
        h = Hint(key="k", hint_type="file", content="x")
        assert h.summary is None


class TestHintsManagerRecord:

    def test_records_get_file_hint(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/foo.py"}, "content here")
        assert "get_file:/foo.py" in hm._hints
        assert hm._hints["get_file:/foo.py"].hint_type == "file"

    def test_records_get_file_tree_hint(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file_tree", {"path": "/project"}, "tree output")
        assert "get_file_tree:/project" in hm._hints
        assert hm._hints["get_file_tree:/project"].hint_type == "file_tree"

    def test_records_list_directory_hint(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("list_directory", {"path": "/src"}, "dir listing")
        assert "list_directory:/src" in hm._hints
        assert hm._hints["list_directory:/src"].hint_type == "directory_listing"

    def test_records_find_file_hint(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("find_file", {"name": "router.py", "dir": "/"}, "result")
        hint = list(hm._hints.values())[0]
        assert hint.hint_type == "directory_listing"

    def test_records_web_search_hint(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("web_search", {"query": "pytest tutorial"}, "search results")
        assert "web_search:pytest tutorial" in hm._hints
        assert hm._hints["web_search:pytest tutorial"].hint_type == "search_result"

    def test_records_unknown_tool_as_generic(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("some_other_tool", {"arg": "val"}, "output")
        hint = list(hm._hints.values())[0]
        assert hint.hint_type == "generic"

    def test_overwrites_same_key(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/foo.py"}, "version one")
        hm.record("get_file", {"path": "/foo.py"}, "version two")
        assert hm._hints["get_file:/foo.py"].content == "version two"


class TestHintsManagerClear:

    def test_clear_removes_all_hints(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/a.py"}, "content")
        hm.record("web_search", {"query": "q"}, "results")
        hm.clear()
        assert hm._hints == {}


class TestHintsManagerInjectInto:

    def test_inject_file_hint_into_code_analysis(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/foo.py"}, "def hello(): pass")
        ephemeral = HistoryManager(None)
        ephemeral.update_chat_context_as_system("code analysis prompt")
        hm.inject_into(ephemeral, "code_analysis")
        msgs = [m.content for m in ephemeral.chat_context.messages]
        combined = "\n".join(msgs)
        assert "foo.py" in combined

    def test_inject_tree_hint_into_file_operations(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file_tree", {"path": "/project"}, "tree here")
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "file_operations")
        msgs = [m.content for m in ephemeral.chat_context.messages]
        assert any("tree here" in m or "project" in m for m in msgs)

    def test_research_pipeline_gets_no_injection(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/foo.py"}, "content")
        hm.record("web_search", {"query": "q"}, "results")
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "research")
        assert len(ephemeral.chat_context.messages) == 0

    def test_general_chat_only_gets_search_results(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/foo.py"}, "file content")
        hm.record("web_search", {"query": "python tips"}, "search results here")
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "general_chat")
        msgs = [m.content for m in ephemeral.chat_context.messages]
        combined = "\n".join(msgs)
        assert "search results here" in combined
        assert "file content" not in combined

    def test_no_hints_means_no_injection(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "code_analysis")
        assert len(ephemeral.chat_context.messages) == 0

    def test_unknown_pipeline_injects_nothing(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/foo.py"}, "content")
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "nonexistent_pipeline")
        assert len(ephemeral.chat_context.messages) == 0


class TestHintsManagerSummarization:

    def test_short_content_is_not_summarized(self, logger):
        runner = make_mock_runner("summarized version")
        hm = HintsManager(runner, logger)
        short_content = "line\n" * 10  # 10 lines — well below threshold
        hm.record("get_file", {"path": "/short.py"}, short_content)
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "code_analysis")
        runner.talk_with_model.assert_not_called()

    def test_long_content_is_summarized_on_inject(self, logger):
        runner = make_mock_runner("summarized version")
        hm = HintsManager(runner, logger)
        long_content = "line\n" * (SUMMARIZATION_THRESHOLD + 10)
        hm.record("get_file", {"path": "/long.py"}, long_content)
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "code_analysis")
        runner.talk_with_model.assert_called_once()

    def test_summary_cached_on_second_inject(self, logger):
        runner = make_mock_runner("the summary")
        hm = HintsManager(runner, logger)
        long_content = "line\n" * (SUMMARIZATION_THRESHOLD + 10)
        hm.record("get_file", {"path": "/long.py"}, long_content)

        ephemeral1 = HistoryManager(None)
        hm.inject_into(ephemeral1, "code_analysis")

        ephemeral2 = HistoryManager(None)
        hm.inject_into(ephemeral2, "code_analysis")

        # Runner called only once — second inject reuses cached summary
        runner.talk_with_model.assert_called_once()

    def test_summarization_failure_falls_back_to_truncation(self, logger):
        runner = MagicMock()
        runner.talk_with_model.side_effect = Exception("model error")
        hm = HintsManager(runner, logger)
        long_content = "line\n" * (SUMMARIZATION_THRESHOLD + 20)
        hm.record("get_file", {"path": "/long.py"}, long_content)
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "code_analysis")
        # Should not raise and should still inject something
        msgs = [m.content for m in ephemeral.chat_context.messages]
        assert len(msgs) > 0


class TestHintsManagerHeaders:

    def test_file_header_contains_path(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("get_file", {"path": "/core/router.py"}, "content")
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "code_analysis")
        combined = "\n".join(m.content for m in ephemeral.chat_context.messages)
        assert "router.py" in combined

    def test_search_result_header_contains_query(self, logger):
        hm = HintsManager(make_mock_runner(), logger)
        hm.record("web_search", {"query": "pytest best practices"}, "results here")
        ephemeral = HistoryManager(None)
        hm.inject_into(ephemeral, "general_chat")
        combined = "\n".join(m.content for m in ephemeral.chat_context.messages)
        assert "pytest best practices" in combined
