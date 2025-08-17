#!/bin/bash
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/parser.test.lua
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/logger.test.lua
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/history.test.lua
lua -e "require('./lua/pulpero/load_dep')" ./lua/pulpero/test/tool_manager.test.lua
