local create_file_tool = require("create_file")
local get_file_tool = require("get_file")
local web_search_tool = require("web_search")
local tools = {
    create_create_file_tool = create_file_tool.create_create_file_tool,
    create_get_file_tool = get_file_tool.create_get_file_tool,
    create_web_Search_tool = web_search_tool.create_web_search_tool,
}
return tools

