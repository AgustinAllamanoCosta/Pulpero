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

class HistoryManager:

    chat_context: ChatContext | None
    system_message: ChatEntry | None
    def __init__(self, context: ChatContext | None) -> None:
        self.chat_context = None

        if( context is None):
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

        if(self.chat_context is None):
            raise ValueError('Chat context is None when we try to update the chat history')

        self.chat_context.messages.append(FunctionResponseEntry(name, content))

        while len(self.chat_context.messages) > self.chat_context.max_messages:
            self.chat_context.messages.pop(0)

    def update_chat_context(self, role: str, content: str) -> None:

        if(self.chat_context is None):
            raise ValueError('Chat context is None when we try to update the chat history')

        self.chat_context.messages.append(ChatEntry(role, content))

        while len(self.chat_context.messages) > self.chat_context.max_messages:
            self.chat_context.messages.pop(0)

    def generate_chat_history(self) -> list[dict]:
        history: list[dict] = []

        if(self.chat_context is None or self.system_message is None):
            raise ValueError('Chat context is None when we try to update the chat history')

        for msg in self.chat_context.messages:
            history.append(msg.dict())

        history.insert(0, self.system_message.dict())
        return history

    def clear(self) -> None:
        self.chat_context = self.create_new_chat_context()
