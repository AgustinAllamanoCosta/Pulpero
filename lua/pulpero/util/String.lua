local String = {}

function String.toString(self, table)
    local result = "{\n"
    for k, v in pairs(table) do
        if type(k) == "string" then
            result = result.."\""..k.."\"".." = "
        end
        if type(v) == "table" then
            result = result .. self:toString(v)
        elseif type(v) == "boolean" then
            result = result .. tostring(v)
        else
            result = result .. "\"" .. v .. "\""
        end
        result = result .. ",\n"
    end
    if result ~= "{" then
        result = result:sub(1, result:len()-1)
    end
    return result .. "\n}"
end

return String
