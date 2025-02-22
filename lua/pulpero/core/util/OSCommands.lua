local OSCommands = {}
local WINDOWS = "windows"
local LINUX = "linux"
local DARWIN = "darwin"

function OSCommands.isWindows(self)
    return OSCommands:getPlatform() == WINDOWS
end

function OSCommands.isLinux(self)
    return OSCommands:getPlatform() == LINUX
end

function OSCommands.isDarwin(self)
    return OSCommands:getPlatform() == DARWIN
end

function OSCommands.executeCommand(self, cmd)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

function OSCommands.isDirectory(self, path)
    local file = io.open(path)
    if file then
        local ok, err, code = file:read(1)
        file:close()
        return code == 21
    end
    return false
end

function OSCommands.fileExists(self, path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

function OSCommands.deleteFile(self, path)
    if self:fileExists(path) then
        self:executeCommand('rm "' .. path .. '"')
    end
end

function OSCommands.deleteFolder(self, path)
    if self:isDirectory(path) then
        self:executeCommand('yes | rm -r "' .. path .. '"')
    end
end

function OSCommands.createFile(self, path)
    if not self:fileExists(path) then
        self:executeCommand('touch "' .. path .. '"')
    end
end

function OSCommands.createDirectory(self, path)
    if OSCommands:isWindows() then
        self:executeCommand('mkdir "' .. path .. '"')
    else
        self:executeCommand('mkdir -p "' .. path .. '"')
    end
end

function OSCommands.ensureDir(self, path)
    if not self:isDirectory(path) then
        self:createDirectory(path)
    end
end

function OSCommands.getTempDir(self)
    if OSCommands:isLinux() then
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
    elseif OSCommands:isDarwin() then
        return "/tmp"
    elseif OSCommands:isWindows() then
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

function OSCommands.getDataPath(self)
    local sep = package.config:sub(1,1)
    if os.getenv("HOME") then
        return os.getenv("HOME") .. sep .. ".local" .. sep .. "share" .. sep .. "pulpero"
    else
        return os.getenv("APPDATA") .. sep .. "pulpero"
    end
end

function OSCommands.getModelDir(self)
    local source_path = OSCommands:getDataPath()
    local final_path = self:createPathByOS(source_path, "model")
    OSCommands:ensureDir(final_path)
    return final_path
end

function OSCommands.getPlatform(self)
    local os_name = "undefine"
    if package.config:sub(1,1) == '\\' then
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

function OSCommands.createPathByOS(self, path_or_folder, file_name_or_folder )
    local final_path = ""
    if OSCommands:isWindows() then
         final_path = path_or_folder .. "\\" .. file_name_or_folder
    else
        final_path = path_or_folder .. "/" .. file_name_or_folder
    end
    return final_path
end

function OSCommands.getFileContent(self, file_path)
  if self:fileExists(file_path) then
    local file = io.open(file_path, "r")
    local content = file:read("*a")
    file:close()
    return content
  end
  return nil
end

return OSCommands
