local Tool = require("tool")
local http = require("request")

local function search_code(logger)
    local function execute(params)
        if not params.query then
            return { error = "Query is required" }
        end

        logger:debug("Looking for code on database by query ".. params.query)
    end

    return Tool.new(
        "search_code",
        "Search code in a RAG data base",
        {
            query = {
                type = "string",
                description = "The title, description or partial content of the code to search for"
            }
        },
        execute
    )
end

return {
    create_get_file_tool = search_code,
}
