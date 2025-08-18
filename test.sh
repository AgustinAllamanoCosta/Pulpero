#!/bin/bash
echo "Parser Test"
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/parser.test.lua
echo "Logger Test"
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/logger.test.lua
echo "History Test"
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/history.test.lua
echo "Tool Manager Test"
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/tool_manager.test.lua
echo "Get File Tool Test"
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/get_file_tool.test.lua
echo "Create File Tool Test"
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/create_file_tool.test.lua
echo "Find File Tool Test"
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/find_file_tool.test.lua
