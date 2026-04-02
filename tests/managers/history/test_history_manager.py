import pytest
import json
from core.managers.history.manager import (
    HistoryManager,
    ChatEntry,
    FunctionResponseEntry,
    ChatContext,
)


class TestChatEntry:

    def test_valid_user_entry(self):
        entry = ChatEntry("user", "hello")
        assert entry.key == "user"
        assert entry.content == "hello"

    def test_valid_assistant_entry(self):
        entry = ChatEntry("assistant", "response")
        assert entry.dict() == {"role": "assistant", "content": "response"}

    def test_valid_system_entry(self):
        entry = ChatEntry("system", "you are an assistant")
        assert entry.dict()["role"] == "system"

    def test_dict_format(self):
        entry = ChatEntry("user", "test")
        d = entry.dict()
        assert "role" in d
        assert "content" in d


class TestFunctionResponseEntry:

    def test_creates_entry_with_name_and_content(self):
        entry = FunctionResponseEntry("get_file", "file content here")
        assert entry.name == "get_file"
        assert entry.content == "file content here"

    def test_id_equals_name(self):
        entry = FunctionResponseEntry("my_tool", "result")
        assert entry.id == "my_tool"

    def test_role_is_always_user(self):
        entry = FunctionResponseEntry("any_tool", "result")
        assert entry.key == "user"

    def test_dict_format(self):
        entry = FunctionResponseEntry("get_file", "content")
        d = entry.dict()
        assert d["tool_call_id"] == "get_file"
        assert d["role"] == "user"
        assert d["content"] == "content"


class TestHistoryManager:

    def test_creates_empty_context_when_none_passed(self):
        hm = HistoryManager(None)
        assert hm.chat_context is not None
        assert hm.chat_context.messages == []

    def test_add_user_message(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_user("hello")
        assert len(hm.chat_context.messages) == 1
        assert hm.chat_context.messages[0].key == "user"

    def test_add_assistant_message(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_assistant("response")
        assert hm.chat_context.messages[0].key == "assistant"

    def test_add_system_message_sets_system_message(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_system("you are helpful")
        assert hm.system_message is not None
        assert hm.system_message.content == "you are helpful"

    def test_system_message_replaced_not_appended(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_system("first")
        hm.update_chat_context_as_system("second")
        assert hm.system_message.content == "second"
        assert len(hm.chat_context.messages) == 0

    def test_add_tool_call_message(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_tool_call("get_file", "file content")
        assert len(hm.chat_context.messages) == 1
        assert isinstance(hm.chat_context.messages[0], FunctionResponseEntry)

    def test_empty_content_not_added(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_user("")
        assert len(hm.chat_context.messages) == 0

    def test_empty_tool_call_content_not_added(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_tool_call("get_file", "")
        assert len(hm.chat_context.messages) == 0

    def test_rolling_window_enforced(self):
        hm = HistoryManager(None)
        # Default max_messages is 50
        for i in range(55):
            hm.update_chat_context_as_user(f"message {i}")
        assert len(hm.chat_context.messages) <= 50

    def test_generate_chat_history_includes_system(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_system("system prompt")
        hm.update_chat_context_as_user("hello")
        history = hm.generate_chat_history()
        assert history[0]["role"] == "system"
        assert history[1]["role"] == "user"

    def test_generate_chat_history_without_system(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_user("hello")
        history = hm.generate_chat_history()
        assert history[0]["role"] == "user"

    def test_create_ephemeral_inherits_user_and_assistant(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_user("user msg")
        hm.update_chat_context_as_assistant("assistant msg")
        hm.update_chat_context_as_tool_call("get_file", "tool result")
        ephemeral = hm.create_ephemeral("new system prompt")
        roles = [m.key for m in ephemeral.chat_context.messages]
        assert "user" in roles
        assert "assistant" in roles

    def test_create_ephemeral_excludes_tool_call_entries(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_tool_call("get_file", "tool result")
        ephemeral = hm.create_ephemeral("prompt")
        assert len(ephemeral.chat_context.messages) == 0

    def test_create_ephemeral_has_new_system_prompt(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_system("old prompt")
        ephemeral = hm.create_ephemeral("new prompt")
        assert ephemeral.system_message.content == "new prompt"

    def test_clear_resets_messages(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_user("hello")
        hm.clear()
        assert hm.chat_context.messages == []

    def test_needs_compression_false_below_threshold(self):
        hm = HistoryManager(None)
        for _ in range(5):
            hm.update_chat_context_as_user("msg")
        assert hm.needs_compression(threshold=30) is False

    def test_needs_compression_true_at_threshold(self):
        hm = HistoryManager(None)
        for _ in range(30):
            hm.update_chat_context_as_user("msg")
        assert hm.needs_compression(threshold=30) is True

    def test_flush_and_load_roundtrip(self, tmp_path):
        path = str(tmp_path / "history.json")
        hm = HistoryManager(None, file_path=path)
        hm.update_chat_context_as_user("persisted message")
        hm.update_chat_context_as_assistant("persisted response")
        hm.flush()

        hm2 = HistoryManager(None, file_path=path)
        hm2.load()
        roles = [m.key for m in hm2.chat_context.messages]
        assert "user" in roles
        assert "assistant" in roles

    def test_flush_only_persists_user_and_assistant(self, tmp_path):
        path = str(tmp_path / "history.json")
        hm = HistoryManager(None, file_path=path)
        hm.update_chat_context_as_user("user msg")
        hm.update_chat_context_as_system("system prompt")
        hm.update_chat_context_as_tool_call("get_file", "tool result")
        hm.flush()

        with open(path) as f:
            data = json.load(f)
        roles = [entry["role"] for entry in data]
        assert "system" not in roles
        assert "user" in roles

    def test_load_silently_handles_missing_file(self, tmp_path):
        hm = HistoryManager(None, file_path=str(tmp_path / "missing.json"))
        hm.load()  # should not raise
        assert hm.chat_context.messages == []

    def test_compress_reduces_history(self):
        hm = HistoryManager(None)
        for i in range(20):
            hm.update_chat_context_as_user(f"user {i}")
            hm.update_chat_context_as_assistant(f"assistant {i}")

        def summarize(turns):
            return "Summary of previous conversation."

        hm.compress(keep_recent=4, compress_fn=summarize)
        user_count = sum(1 for m in hm.chat_context.messages if m.key == "user")
        assert user_count <= 5  # 4 recent + 1 summary entry

    def test_str_returns_json_string(self):
        hm = HistoryManager(None)
        hm.update_chat_context_as_user("hello")
        s = str(hm)
        parsed = json.loads(s)
        assert isinstance(parsed, list)
