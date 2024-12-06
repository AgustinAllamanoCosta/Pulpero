#!/bin/bash
# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed"
fi

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Install Lua and LuaRocks
echo "Installing Lua and LuaRocks..."
brew install lua luarocks

# Verify installations
echo "Verifying installations..."
lua -v
luarocks --version

# Create Lua directory structure
echo "Creating Lua directories..."
mkdir -p ~/.luarocks

# Add Lua paths to shell config
SHELL_CONFIG="$HOME/.zshrc"
if [ ! -f "$SHELL_CONFIG" ]; then
    SHELL_CONFIG="$HOME/.bash_profile"
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

luarocks install milua
