local OSCommands = {}
local WINDOWS = "windows"
local LINUX = "linux"
local DARWIN = "darwin"
local sep = package.config:sub(1, 1)

function OSCommands.is_windows(self)
    return OSCommands:get_platform() == WINDOWS
end

function OSCommands.is_linux(self)
    return OSCommands:get_platform() == LINUX
end

function OSCommands.is_darwin(self)
    return OSCommands:get_platform() == DARWIN
end

function OSCommands.execute_command(self, cmd)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

function OSCommands.is_directory(self, path)
    local file = io.open(path)
    if file then
        local ok, err, code = file:read(1)
        file:close()
        return code == 21
    end
    return false
end

function OSCommands.file_exists(self, path)
    local handle, files, directory, filename

    directory = path:match("(.*".. sep ..")")
    filename = path:match("[%w+_-]*%w+[.]%w+$")

    if self:is_windows() then
        handle = io.popen('dir /b "' .. directory .. '"')
    else
        handle = io.popen('ls -1 "' .. directory .. '"')
    end

    if handle then
        files = handle:read("*a")
        handle:close()
    else
        return false
    end

    for file in files:gmatch("([^\n]+)") do
        if file == filename then
            return true
        end
    end

    return false
end

function OSCommands.delete_file(self, path)
    if self:file_exists(path) then
        self:execute_command('rm "' .. path .. '"')
    end
end

function OSCommands.delete_folder(self, path)
    if self:is_directory(path) then
        self:execute_command('yes | rm -r "' .. path .. '"')
    end
end

function OSCommands.create_file(self, path)
    if not self:file_exists(path) then
        self:execute_command('touch "' .. path .. '"')
    end
end

function OSCommands.create_directory(self, path)
    if OSCommands:is_windows() then
        self:execute_command('mkdir "' .. path .. '"')
    else
        self:execute_command('mkdir -p "' .. path .. '"')
    end
end

function OSCommands.ensure_dir(self, path)
    if not self:is_directory(path) then
        self:create_directory(path)
    end
end

function OSCommands.get_temp_dir(self)
    if OSCommands:is_linux() then
        local tmp = os.getenv("TMPDIR")
        if tmp then
            return tmp
        else
            local candidates = {
                "/tmp",
                "/var/tmp",
                "/usr/tmp"
            }
            for _, path in ipairs(candidates) do
                local file = io.open(path .. "/test_write", "w")
                if file then
                    file:close()
                    os.remove(path .. "/test_write")
                    return path
                end
            end
        end
    elseif OSCommands:is_darwin() then
        return "/tmp"
    elseif OSCommands:is_windows() then
        local temp = os.getenv("TEMP")
        if temp then
            return temp
        else
            local tmp = os.getenv("TMP")
            if tmp then
                return tmp
            else
                return "C:\\Windows\\Temp"
            end
        end
    end
end

function OSCommands.get_data_path(self)
    if os.getenv("HOME") then
        return os.getenv("HOME") .. sep .. ".local" .. sep .. "share" .. sep .. "pulpero"
    else
        return os.getenv("APPDATA") .. sep .. "pulpero"
    end
end

function OSCommands.get_source_path(self)
    local regex = sep .. "pulpero" .. sep .. "%S*.lua"
    local source_path = debug.getinfo(1).source:sub(2):gsub(regex, "")
    return source_path
end

function OSCommands.get_core_path(self)
    local source_path = OSCommands:get_source_path()
    local base_path = OSCommands:create_path_by_OS(source_path, "pulpero")
    return OSCommands:create_path_by_OS(base_path, "core")
end

function OSCommands.get_model_dir(self)
    local source_path = OSCommands:get_data_path()
    local final_path = self:create_path_by_OS(source_path, "model")
    OSCommands:ensure_dir(final_path)
    return final_path
end

function OSCommands.get_platform(self)
    local os_name = "undefine"
    if package.config:sub(1, 1) == '\\' then
        os_name = WINDOWS
    else
        local handle = io.popen("uname")
        if handle then
            os_name = handle:read("*l"):lower()
            handle:close()
        end
    end
    return os_name
end

function OSCommands.create_path_by_OS(self, path_or_folder, file_name_or_folder)
    local final_path = ""
    if OSCommands:is_windows() then
        final_path = path_or_folder .. "\\" .. file_name_or_folder
    else
        final_path = path_or_folder .. "/" .. file_name_or_folder
    end
    return final_path
end

function OSCommands.get_file_content(self, file_path)
    -- if self:file_exists(file_path) then
        local file = io.open(file_path, "r")
        local content = file:read("*a")
        file:close()
        return content
    -- else
        -- return "File not exits"
    -- end
end

return OSCommands
