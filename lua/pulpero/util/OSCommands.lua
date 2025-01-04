local OSCommands = {}

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
    if package.config:sub(1,1) == '\\' then
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

function OSCommands.getDataPath(self)
    local sep = package.config:sub(1,1)
    if os.getenv("HOME") then
        return os.getenv("HOME") .. sep .. ".local" .. sep .. "share" .. sep .. "pulpero"
    else
        return os.getenv("APPDATA") .. sep .. "pulpero"
    end
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

function OSCommands.getPlatform(self)
    local os_name = "undefine"
    if package.config:sub(1,1) == '\\' then
        os_name = "windows"
    else
        local handle = io.popen("uname")
        if handle then
            os_name = handle:read("*l"):lower()
            handle:close()
        end
    end
    return os_name
end

return OSCommands
