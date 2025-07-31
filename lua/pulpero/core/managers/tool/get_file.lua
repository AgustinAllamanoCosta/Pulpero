local Tool = require("tool")
local OSCommands = require('OSCommands')

local function get_file(logger)
    local function execute(params)
        if not params.path then
            return { error = "Path is required" }
        end

        logger:debug("Looking for file content " .. params.path)
        local content = OSCommands:get_file_content(params.path)

        return { content = content }
    end

    return Tool.new(
        "get_file",
        "Get the content of a file by path",
        {
            path = {
                type = "string",
                description = "The file path"
            }
        },
        execute
    )
end

return {
    create_get_file_tool = get_file,
}
