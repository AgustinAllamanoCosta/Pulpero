local Tool = require("tool")
local json = require("JSON")
local OSCommands = require('OSCommands')

--TODO: use a lite model to make a summary of the first page of the saerch sites and order the link in order for the most relevant to the last one.
local function web_search(logger)
    local function execute(params)
        if not params.query then
            return { error = "Search query is required" }
        end

        local query = params.query
        local encoded_query = query:gsub(" ", "+")

        local command
        if OSCommands:is_windows() then

            command = string.format('curl -s "https://ddg-api.herokuapp.com/search?q=%s"', encoded_query)
        else
            command = string.format('curl -s "https://ddg-api.herokuapp.com/search?q=%s"', encoded_query)
        end

        logger:debug("Executing web search", { query = query, command = command })

        local result = OSCommands:execute_command(command)

        local search_results = json.decode(result)

        if not search_results then
            return { error = "Failed to parse search results" }
        end

        return { results = search_results }
    end

    return Tool.new(
        "web_search",
        "Search the web for information",
        {
            query = { type = "string", description = "The search query" }
        },
        execute
    )
end

return {
    create_web_search_tool = web_search,
}
