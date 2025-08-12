local current_file = debug.getinfo(1, "S").source:sub(2)
local plugin_root = current_file:match("(.*/)"):sub(1, -2):match("(.*/)"):sub(1, -2)

local paths = {
    plugin_root .. "/?.lua",
    plugin_root .. "/?/init.lua",
    plugin_root .. "/pulpero/?.lua",
    plugin_root .. "/pulpero/?/init.lua",
    plugin_root .. "/pulpero/test/?.lua",
    plugin_root .. "/pulpero/test/?/init.lua",
    plugin_root .. "/pulpero/core/?.lua",
    plugin_root .. "/pulpero/core/?/init.lua",
    plugin_root .. "/pulpero/core/util/?.lua",
    plugin_root .. "/pulpero/core/util/?/init.lua",
    plugin_root .. "/pulpero/core/socket/?.lua",
    plugin_root .. "/pulpero/core/socket/?/init.lua",
    plugin_root .. "/pulpero/core/managers/?.lua",
    plugin_root .. "/pulpero/core/managers/?/init.lua",
    plugin_root .. "/pulpero/core/managers/tool/?.lua",
    plugin_root .. "/pulpero/core/managers/tool/?/init.lua",
    plugin_root .. "/pulpero/core/runner/model/?.lua",
    plugin_root .. "/pulpero/core/runner/model/?/init.lua",
    plugin_root .. "/pulpero/core/managers/model/?.lua",
    plugin_root .. "/pulpero/core/managers/model/?/init.lua",
    plugin_root .. "/pulpero/core/managers/audio/?.lua",
    plugin_root .. "/pulpero/core/managers/audio/?/init.lua",
}

for _, path in ipairs(paths) do
    if not package.path:match(path:gsub("[%.%/]", "%%%1")) then
        package.path = path .. ";" .. package.path
    end
end
