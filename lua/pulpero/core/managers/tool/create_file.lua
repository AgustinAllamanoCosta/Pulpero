local Tool = require("tool")
local OSCommands = require('OSCommands')

local function create_file(logger)
    local function execute(params)
        if not params.path then
            return { error = "Path is required" }
        end

        if not params.content then
            return { error = "Content is required" }
        end

        if OSCommands:file_exists(params.path) then
            return { error = "Can not create a file if already exists" }
        end

        logger:debug("Creating file in", { path = params.path })

        local file = io.open(params.path, "w")

        if file ~= nil then
            file:write(params.content)
            file:close()
        else
            return { error = "Can not create the file" }
        end

        return { success = true }
    end

    return Tool.new(
        "create_file",
        "Create a file in the given directory",
        {
            path = {
                type = "string",
                description = "The file path"
            },
            content = {
                type = "string",
                description = "The content of the file"
            }
        },
        "<tool name=\"create_file\" params=\"path=EXACT_PATH, content=CONTENT_OF_THE_FILE\" />",
        execute
    )
end

return {
    create_create_file_tool = create_file,
}
