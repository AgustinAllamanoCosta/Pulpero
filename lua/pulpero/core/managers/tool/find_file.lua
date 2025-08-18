local Tool = require("tool")
local OSCommands = require('OSCommands')

local function find_file(logger)
    local function execute(params)
        if not params.name then
            return { error = "File name is require" }
        end

        if not params.dir then
            return { error = "Working dir is require" }
        end


        local result = {}
        local command = "find " .. params.dir .. " -name " .. params.name
        local paths = OSCommands:execute_command(command)

        local index = 1
        for path in paths:gmatch("[^\r\n]+") do
            result[index] = path
            index = index + 1
        end

        return result
    end

    return Tool.new(
        "find_file",
        "Find a file recursive in the working dir",
        {
            name = {
                type = "string",
                description = "Name of the file to find"
            },
            dir = {
                type = "string",
                description = "Directory where to search for the file"
            }

        },
        "<tool name=\"find_file\" params=\"name=NAME_OF_THE_FILE dir=PATH_OF_FOLDER_TO_SEARCH\" />",
        execute
    )
end

return {
    create_find_file_tool = find_file,
}
