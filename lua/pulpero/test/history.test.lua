local History = require('history.manager')
local luaunit = require('luaunit')

function test_should_create_a_new_history()
  local history = History.new(nil)
  luaunit.assertNotNil(history.chat_context)
end

function test_should_update_a_chat_context_as_assistant()
  local history = History.new(nil)

  history:update_chat_context('assistant', "some assistant response")

  luaunit.assertNotNil(history.chat_context)
  luaunit.assertTrue(history.chat_context.messages[1].role == 'assistant')
  luaunit.assertTrue(history.chat_context.messages[1].content == 'some assistant response')
end

function test_should_update_a_chat_context_as_user()
  local history = History.new(nil)

  history:update_chat_context('user', "some user response")

  luaunit.assertNotNil(history.chat_context)
  luaunit.assertTrue(history.chat_context.messages[1].role == 'user')
  luaunit.assertTrue(history.chat_context.messages[1].content == 'some user response')
end

function test_should_generate_the_chat_history()
  local history = History.new(nil)

  history:update_chat_context_as_user("some user response")
  history:update_chat_context_as_assistant("some assistant response")

  local chat_history = history:generate_chat_history()
  local expected_chat_history =
  "Chat History:\nUser:some user response\nAssistant: some assistant response\n\nEnd History"
  luaunit.assertTrue(chat_history == expected_chat_history)
end

function test_should_clear_a_existent_chat_history()
  local history = History.new(nil)

  history:update_chat_context_as_user("some user response")
  history:update_chat_context_as_assistant("some assistant response")

  history:clear()
  local cleaned_chat_history = history:generate_chat_history()

  luaunit.assertTrue(cleaned_chat_history == "")
end

function test_should_remove_the_overflow_messages()
  local history = History.new(
    {
      messages = {},
      max_messages = 8,
      current_tokens = 0
    }
  )

  history:update_chat_context_as_user("some user response 1")
  history:update_chat_context_as_assistant("some assistant response 1")

  history:update_chat_context_as_user("some user response 2")
  history:update_chat_context_as_assistant("some assistant response 2")

  history:update_chat_context_as_user("some user response 3")
  history:update_chat_context_as_assistant("some assistant response 3")

  history:update_chat_context_as_user("some user response 4")
  history:update_chat_context_as_assistant("some assistant response 4")

  history:update_chat_context_as_user("some user response 5")
  history:update_chat_context_as_assistant("some assistant response 5")

  local truked_history = history:generate_chat_history()
  local expected_trunkated_history =
  "Chat History:\nUser:some user response 2\nAssistant: some assistant response 2\nUser:some user response 3\nAssistant: some assistant response 3\nUser:some user response 4\nAssistant: some assistant response 4\nUser:some user response 5\nAssistant: some assistant response 5\n\nEnd History"
  luaunit.assertTrue(truked_history == expected_trunkated_history)
end

local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
