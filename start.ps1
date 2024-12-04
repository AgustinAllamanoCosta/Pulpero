# Requires PowerShell to be run as Administrator

# Define versions and URLs
$LUA_VERSION = "5.4.6"
$LUAROCKS_VERSION = "3.9.2"
$LUA_URL = "https://sourceforge.net/projects/luabinaries/files/$LUA_VERSION/Tools%20Executables/lua-${LUA_VERSION}_Win64_bin.zip"
$LUAROCKS_URL = "https://luarocks.github.io/luarocks/releases/luarocks-$LUAROCKS_VERSION-windows-64.zip"

# Create installation directory
$INSTALL_DIR = "C:\Lua"
New-Item -ItemType Directory -Force -Path $INSTALL_DIR

Write-Host "Installing Lua and LuaRocks to $INSTALL_DIR..."

# Download and extract Lua
Write-Host "Downloading Lua..."
Invoke-WebRequest -Uri $LUA_URL -OutFile "$INSTALL_DIR\lua.zip"
Expand-Archive -Path "$INSTALL_DIR\lua.zip" -DestinationPath $INSTALL_DIR -Force
Remove-Item "$INSTALL_DIR\lua.zip"

# Download and extract LuaRocks
Write-Host "Downloading LuaRocks..."
Invoke-WebRequest -Uri $LUAROCKS_URL -OutFile "$INSTALL_DIR\luarocks.zip"
Expand-Archive -Path "$INSTALL_DIR\luarocks.zip" -DestinationPath $INSTALL_DIR -Force
Remove-Item "$INSTALL_DIR\luarocks.zip"

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if (-not $currentPath.Contains($INSTALL_DIR)) {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$currentPath;$INSTALL_DIR",
        "Machine"
    )
}

Write-Host "Installation completed!"
Write-Host "Please restart your terminal to use Lua and LuaRocks"

# Test installation
Write-Host "Testing Lua installation..."
lua -v
Write-Host "Testing LuaRocks installation..."
luarocks --version

luarocks install milua
lua init.lua
