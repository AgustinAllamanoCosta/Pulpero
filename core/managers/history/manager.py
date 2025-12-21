user_key = "User"
assistant_key = "Assistant"

class ChatEntry:
    key: str
    content: str

    def __init__(self, key: str, content: str) -> None:

        if(key is not user_key and key is not assistant_key):
            raise Exception('chat entry key not valid')

        self.key = key
        self.content = content

class ChatContext:

    messages: list[ChatEntry]
    max_messages: int
    current_tokens: int

    def __init__(self, messages: list[ChatEntry], max_messages: int, current_tokens: int) -> None:

        self.messages = messages
        self.max_messages = max_messages
        self.current_tokens = current_tokens

class HistoryManager:

    chat_context: ChatContext | None
    def __init__(self, context: ChatContext | None) -> None:
        self.chat_context = None

        if( context is None):
            self.chat_context = self.create_new_chat_context()
        else:
            self.chat_context = context

    def create_new_chat_context(self) -> ChatContext:
        return ChatContext([], 16, 0)

    def update_chat_context_as_assistant(self, content: str) -> None:
        self.update_chat_context(assistant_key, content)

    def update_chat_context_as_user(self, content: str) -> None:
        self.update_chat_context(user_key, content)

    def update_chat_context(self, role: str, content: str) -> None:

        if(self.chat_context is None):
            raise ValueError('Chat context is None when we try to update the chat history')

        self.chat_context.messages.append(ChatEntry(role, content))

        while len(self.chat_context.messages) > self.chat_context.max_messages:
            self.chat_context.messages.pop(0)

    def build_chat_history(self) -> str:
        history: str = ""

        if(self.chat_context is None):
            raise ValueError('Chat context is None when we try to update the chat history')

        for msg in self.chat_context.messages:
            if msg.key == user_key:
                history = history + f"User: {msg.content}\n"
            else:
                history = history + f"Assistant: {msg.content}\n"

        return history

    def generate_chat_history(self):
        current_chat_history: str = self.build_chat_history()
        chat_history: str = ""

        if(current_chat_history != ""):
            chat_history = f"Chat History:\n{current_chat_history}End History"

        return chat_history

    def clear(self) -> None:
        self.chat_context = self.create_new_chat_context()
