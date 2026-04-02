from dataclasses import dataclass, field
from core.managers.history.manager import HistoryManager

@dataclass
class Hint:
    key: str
    hint_type: str
    content: str
    summary: str | None = field(default=None)


PIPELINE_HINT_TYPES: dict[str, list[str]] = {
    "file_operations": ["file_tree", "directory_listing"],
    "code_analysis":   ["file", "file_tree", "directory_listing"],
    "research":        [],
    "general_chat":    ["search_result"],
}

TOOL_TYPE_MAP: dict[str, str] = {
    "get_file":       "file",
    "get_file_tree":  "file_tree",
    "find_file":      "directory_listing",
    "list_directory": "directory_listing",
    "web_search":     "search_result",
}

SUMMARIZATION_THRESHOLD = 100


class HintsManager:

    def __init__(self, chat_runner, logger) -> None:
        self._hints: dict[str, Hint] = {}
        self._chat_runner = chat_runner
        self._logger = logger

    def record(self, tool_name: str, arguments: dict, result: str) -> None:
        hint_type = TOOL_TYPE_MAP.get(tool_name, "generic")

        if tool_name == "get_file":
            key = f"get_file:{arguments.get('path', '')}"
        elif tool_name == "get_file_tree":
            key = f"get_file_tree:{arguments.get('path', '')}"
        elif tool_name == "list_directory":
            key = f"list_directory:{arguments.get('path', '')}"
        elif tool_name == "web_search":
            key = f"web_search:{arguments.get('query', '')}"
        else:
            key = f"{tool_name}:{str(arguments)}"

        self._hints[key] = Hint(key=key, hint_type=hint_type, content=result)
        self._logger.info(f"Hint recorded", key)

    def inject_into(self, ephemeral: HistoryManager, pipeline: str) -> None:
        allowed_types = PIPELINE_HINT_TYPES.get(pipeline, [])
        if not allowed_types:
            return

        selected = [h for h in self._hints.values() if h.hint_type in allowed_types]
        if not selected:
            return

        sections: list[str] = ["[Context from previous pipeline steps]"]

        for hint in selected:
            content_to_inject = self._resolve_content(hint)
            header = self._make_header(hint)
            sections.append(f"\n{header}\n{content_to_inject}")

        formatted = "\n".join(sections)
        ephemeral.update_chat_context_as_assistant(formatted)
        self._logger.info(f"Hints injected into pipeline", pipeline)

    def clear(self) -> None:
        self._hints.clear()

    def _resolve_content(self, hint: Hint) -> str:
        lines = hint.content.splitlines()
        if len(lines) <= SUMMARIZATION_THRESHOLD:
            return hint.content

        if hint.summary is None:
            hint.summary = self._summarize(hint)

        return hint.summary

    def _summarize(self, hint: Hint) -> str:
        from core.runner.model.prompts import hint_summarization
        try:
            summary_history = HistoryManager(None)
            summary_history.update_chat_context_as_system(hint_summarization)
            summary_history.update_chat_context_as_user(hint.content)
            response = self._chat_runner.talk_with_model(summary_history)
            self._logger.info("Hint summarized", hint.key)
            return response.message
        except Exception as e:
            self._logger.error(f"Hint summarization failed for {hint.key}: {e}")
            return "\n".join(hint.content.splitlines()[:SUMMARIZATION_THRESHOLD])

    def _make_header(self, hint: Hint) -> str:
        if hint.hint_type == "file":
            path = hint.key.removeprefix("get_file:")
            return f"--- File: {path} ---"
        elif hint.hint_type == "file_tree":
            path = hint.key.removeprefix("get_file_tree:")
            return f"--- File tree: {path} ---"
        elif hint.hint_type == "directory_listing":
            if hint.key.startswith("list_directory:"):
                path = hint.key.removeprefix("list_directory:")
                return f"--- Directory listing: {path} ---"
            else:
                return f"--- Directory search results ---"
        elif hint.hint_type == "search_result":
            query = hint.key.removeprefix("web_search:")
            return f"--- Search results: {query} ---"
        else:
            return f"--- {hint.key} ---"
