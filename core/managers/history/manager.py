import json
import os

user_key = "user"
tool_call_key = "user"
assistant_key = "assistant"
system_key = "system"

class ChatEntry:
    key: str
    content: str

    def __init__(self, key: str, content: str) -> None:

        if(key is not tool_call_key and key is not user_key and key is not system_key and key is not assistant_key):
            raise Exception('chat entry key not valid')

        self.key = key
        self.content = content

    def dict(self) -> dict:
        return { 'role': self.key, 'content': self.content }

class FunctionResponseEntry:
    key: str = tool_call_key
    name: str
    id: str
    content: str

    def __init__(self, name: str, content: str) -> None:
        self.name = name
        self.content = content
        self.id = name

    def dict(self) -> dict:
        return { 'tool_call_id': self.id, 'role': self.key, 'content': self.content }

class ChatContext:

    messages: list[ChatEntry | FunctionResponseEntry]
    max_messages: int
    current_tokens: int

    def __init__(self, messages: list[ChatEntry | FunctionResponseEntry], max_messages: int, current_tokens: int) -> None:

        self.messages = messages
        self.max_messages = max_messages
        self.current_tokens = current_tokens

    def __str__(self) -> str:
        return str(self.messages)

class HistoryManager:

    chat_context: ChatContext | None
    system_message: ChatEntry | None
    file_path: str | None

    def __init__(self, context: ChatContext | None, file_path: str | None = None) -> None:
        self.chat_context = None
        self.system_message = None
        self.file_path = file_path

        if context is None:
            self.chat_context = self.create_new_chat_context()
        else:
            self.chat_context = context

    def create_new_chat_context(self) -> ChatContext:
        return ChatContext([], 50, 0)

    def update_chat_context_as_system(self, content: str) -> None:
        self.system_message = ChatEntry(system_key, content)

    def update_chat_context_as_assistant(self, content: str) -> None:
        self.update_chat_context(assistant_key, content)

    def update_chat_context_as_user(self, content: str) -> None:
        self.update_chat_context(user_key, content)

    def update_chat_context_as_tool_call(self, name: str, content: str) -> None:

        if(content.__len__() == 0):
            return

        if(self.chat_context is None):
            raise ValueError('Chat context is None when we try to update the chat history')

        self.chat_context.messages.append(FunctionResponseEntry(name, content))

        while len(self.chat_context.messages) > self.chat_context.max_messages:
            self.chat_context.messages.pop(0)

    def update_chat_context(self, role: str, content: str) -> None:

        if(content.__len__() == 0):
            return

        if(self.chat_context is None):
            raise ValueError('Chat context is None when we try to update the chat history')

        self.chat_context.messages.append(ChatEntry(role, content))

        while len(self.chat_context.messages) > self.chat_context.max_messages:
            self.chat_context.messages.pop(0)

    def load(self) -> None:
        if self.file_path is None or not os.path.exists(self.file_path):
            return

        try:
            with open(self.file_path, 'r', encoding='utf-8') as f:
                entries = json.load(f)
            for entry in entries:
                role = entry.get('role')
                content = entry.get('content', '')
                if role in (user_key, assistant_key) and content:
                    self.chat_context.messages.append(ChatEntry(role, content))
            while len(self.chat_context.messages) > self.chat_context.max_messages:
                self.chat_context.messages.pop(0)
        except Exception:
            pass

    def flush(self) -> None:
        if self.file_path is None:
            return

        entries = [
            msg.dict()
            for msg in self.chat_context.messages
            if isinstance(msg, ChatEntry) and msg.key in (user_key, assistant_key)
        ]

        try:
            os.makedirs(os.path.dirname(self.file_path), exist_ok=True)
            with open(self.file_path, 'w', encoding='utf-8') as f:
                json.dump(entries, f, indent=2)
        except Exception:
            pass

    def create_ephemeral(self, system_prompt: str) -> 'HistoryManager':
        ephemeral = HistoryManager(None)
        ephemeral.update_chat_context_as_system(system_prompt)
        for msg in self.chat_context.messages:
            if isinstance(msg, ChatEntry) and msg.key in (user_key, assistant_key):
                ephemeral.chat_context.messages.append(ChatEntry(msg.key, msg.content))
        return ephemeral

    def generate_chat_history(self) -> list[dict]:
        if self.chat_context is None:
            raise ValueError('Chat context is None when we try to generate the chat history')

        history: list[dict] = []

        if self.system_message is not None:
            history.append(self.system_message.dict())

        for msg in self.chat_context.messages:
            history.append(msg.dict())

        return history

    def __str__(self) -> str:
        try:
            return json.dumps(self.generate_chat_history(), indent=2, default=str)
        except Exception:
            return ""

    def clear(self) -> None:
        self.chat_context = self.create_new_chat_context()
