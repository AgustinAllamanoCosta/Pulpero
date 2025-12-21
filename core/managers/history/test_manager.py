from core.managers.history.manager import HistoryManager, ChatContext

def test_history_manager_without_context():
    history = HistoryManager(None)

    current_chat = history.generate_chat_history()
    assert current_chat == ''

def test_history_manager_with_context():
    history = HistoryManager(None)

    history.update_chat_context_as_assistant('Hola en que te puedo ayudar')
    history.update_chat_context_as_user('Tienes fotos de pies?')

    expected_history = "Chat History:\nAssistant: Hola en que te puedo ayudar\nUser: Tienes fotos de pies?\nEnd History"

    current_chat = history.generate_chat_history()
    assert current_chat == expected_history

def test_history_manager_clean_current_context():
    history = HistoryManager(None)

    history.update_chat_context_as_assistant('Hola en que te puedo ayudar')
    history.update_chat_context_as_user('Tienes fotos de pies?')

    history.clear()

    current_chat = history.generate_chat_history()
    assert current_chat == ''

def test_history_manager_delete_old_message_on_update():
    context = ChatContext(messages=[], max_messages=2, current_tokens=0)
    history = HistoryManager(context)

    history.update_chat_context_as_assistant('Hola en que te puedo ayudar')
    history.update_chat_context_as_user('Tienes fotos de pies?')
    history.update_chat_context_as_user('Tienes fotos de pies?')

    expected_history = "Chat History:\nUser: Tienes fotos de pies?\nUser: Tienes fotos de pies?\nEnd History"

    current_chat = history.generate_chat_history()
    assert current_chat == expected_history
