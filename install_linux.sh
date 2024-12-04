#!/bin/bash

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
else
    echo "Unsupported package manager"
    exit 1
fi

# Install build dependencies and Lua based on package manager
echo "Installing Lua and dependencies..."
case $PKG_MANAGER in
    "apt")
        sudo apt-get update
        sudo apt-get install -y build-essential libreadline-dev unzip curl
        sudo apt-get install -y lua5.4 liblua5.4-dev lua-rocks
        ;;
    "dnf"|"yum")
        sudo $PKG_MANAGER groupinstall -y "Development Tools"
        sudo $PKG_MANAGER install -y readline-devel
        sudo $PKG_MANAGER install -y lua lua-devel luarocks
        ;;
    "pacman")
        sudo pacman -Sy --noconfirm base-devel
        sudo pacman -S --noconfirm lua luarocks
        ;;
esac

# Verify installations
echo "Verifying installations..."
lua -v
luarocks --version

# Create Lua directory structure
echo "Creating Lua directories..."
mkdir -p ~/.luarocks

# Add Lua paths to shell config
SHELL_CONFIG="$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

echo "Adding Lua paths to $SHELL_CONFIG..."
cat >> "$SHELL_CONFIG" << EOL

# Lua and LuaRocks paths
export PATH=\$PATH:\$HOME/.luarocks/bin
export LUA_PATH='/usr/local/share/lua/5.4/?.lua;/usr/local/share/lua/5.4/?/init.lua;./?.lua;./?/init.lua'
export LUA_CPATH='/usr/local/lib/lua/5.4/?.so;./?.so'
EOL

echo "Installation completed!"
echo "Please restart your terminal or run 'source $SHELL_CONFIG' to use Lua and LuaRocks"

# Install some common Lua packages
echo "Installing common Lua packages..."
luarocks install luasocket
luarocks install luafilesystem
luarocks install milua
