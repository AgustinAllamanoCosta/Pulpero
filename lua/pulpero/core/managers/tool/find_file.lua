local Tool = require("tool")
local OSCommands = require('OSCommands')

local function find_file(logger)
    local function execute(params)
        if not params.name then
            return { error = "File name is require" }
        end

        if not params.dri then
            return { error = "File dir is require" }
        end

        local result = ""
        local src_filespec = OSCommands:create_path_by_OS(params.path, params.filename)
        logger:debug("Searching file recursivly " .. src_filespec)
        if OSCommands:file_exists(src_filespec) then
            return src_filespec
        end
        result = OSCommands:list_directory(src_filespec)

        -- for line in pipe:lines() do
        --     table.insert(subfolders, line)
        -- end
        -- pipe:close()
        --
        -- for _, subfolder_name in ipairs(subfolders) do
        --     src_filespec = search_recursively(path .. subfolder_name .. "\\")
        --     if src_filespec then
        --         return src_filespec
        --     end
        -- end
        --

        return { result = result }
    end

    return Tool.new(
        "get_file",
        "Find a file recursive in the working dir",
        {
            name = {
                type = "string",
                description = "Name of the file to find"
            }
        },
        "<tool name=\"find_file\" params=\"name=NAME_OF_THE_FILE\" />",
        execute
    )
end

return {
    create_find_file_tool = find_file,
}
