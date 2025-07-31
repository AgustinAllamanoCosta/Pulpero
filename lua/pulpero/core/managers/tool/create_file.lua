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

        OSCommands:create_file(params.path)
        local file = io.open(params.path, "w")

        file:write(params.content)
        file:close()

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
        execute
    )
end

return {
    create_create_file_tool = create_file,
}
