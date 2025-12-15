local json = {}

local function encode_value(value, stack)
    local val_type = type(value)

    if value == nil then
        return "null"
    elseif val_type == "number" then
        return tostring(value)
    elseif val_type == "boolean" then
        return tostring(value)
    elseif val_type == "string" then
        return string.format("%q", value:gsub('\n', '\\n')):gsub('[%c]*', ''):gsub('[\\ ]$', ''):gsub('[\\]$', '')
    elseif val_type == "table" then
        if stack[value] then
            error("circular reference detected")
        end
        stack[value] = true

        local is_array = true
        local max_index = 0
        for k, _ in pairs(value) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
                break
            end
            max_index = math.max(max_index, k)
        end

        local parts
        if is_array then
            parts = {}
            for i = 1, max_index do
                parts[#parts + 1] = encode_value(value[i], stack)
            end
            stack[value] = nil
            return "[" .. table.concat(parts, ",") .. "]"
        else
            parts = {}
            for k, v in pairs(value) do
                if type(k) == "string" then
                    parts[#parts + 1] = string.format('"%s"', k) .. ":" .. encode_value(v, stack)
                end
            end
            stack[value] = nil
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    error("invalid type: " .. val_type)
end

function json.encode(value)
    return encode_value(value, {})
end

local function skip_whitespace(str, pos)
    while pos <= #str and str:sub(pos, pos):match("%s") do
        pos = pos + 1
    end
    return pos
end

local function decode_value(str, pos)
    pos = skip_whitespace(str, pos)

    local first = str:sub(pos, pos)
    if first == "{" then
        local obj = {}
        pos = pos + 1

        while true do
            pos = skip_whitespace(str, pos)
            if str:sub(pos, pos) == "}" then
                pos = pos + 1
                break
            end


            if str:sub(pos, pos) ~= '"' then
                error("expected string key")
            end
            local key
            key, pos = decode_value(str, pos)


            pos = skip_whitespace(str, pos)
            if str:sub(pos, pos) ~= ":" then
                error("expected colon")
            end
            pos = pos + 1


            local val
            val, pos = decode_value(str, pos)
            obj[key] = val


            pos = skip_whitespace(str, pos)
            local next_char = str:sub(pos, pos)
            if next_char == "}" then
                pos = pos + 1
                break
            elseif next_char == "," then
                pos = pos + 1
            else
                error("expected comma or }")
            end
        end
        return obj, pos

    elseif first == "[" then
        local arr = {}
        pos = pos + 1
        local index = 1

        while true do
            pos = skip_whitespace(str, pos)
            if str:sub(pos, pos) == "]" then
                pos = pos + 1
                break
            end

            local val
            val, pos = decode_value(str, pos)
            arr[index] = val
            index = index + 1

            pos = skip_whitespace(str, pos)
            local next_char = str:sub(pos, pos)
            if next_char == "]" then
                pos = pos + 1
                break
            elseif next_char == "," then
                pos = pos + 1
            else
                error("expected comma or ]")
            end
        end
        return arr, pos

    elseif first == '"' then
        pos = pos + 1
        local value = ""
        while pos <= #str do
            local char = str:sub(pos, pos)
            if char == '"' then
                pos = pos + 1
                break
            elseif char == "\\" then
                pos = pos + 1
                local escape = str:sub(pos, pos)
                if escape == "n" then value = value .. " \n"
                elseif escape == "r" then value = value .. "\r"
                elseif escape == "t" then value = value .. "\t"
                else value = value .. escape
                end
            else
                value = value .. char
            end
            pos = pos + 1
        end
        return value, pos

    elseif str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    elseif str:sub(pos, pos):match("[%d%-]") then
        local num = ""
        while pos <= #str and str:sub(pos, pos):match("[%d%.%-eE%+]") do
            num = num .. str:sub(pos, pos)
            pos = pos + 1
        end
        return tonumber(num), pos
    end

    error("unexpected character: " .. str:sub(pos, pos))
end

function json.decode(str)
    local result, pos = decode_value(str, 1)
    pos = skip_whitespace(str, pos)
    if pos <= #str then
        error("trailing characters")
    end
    return result
end

return json
