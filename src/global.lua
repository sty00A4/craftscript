---@param s string
---@param sep string
string.split = function(s, sep)
    local t = {}
    local temp = ""
    for i = 1, #s do
        if s:sub(i,i) == sep then
            table.insert(t, temp)
            temp = ""
        else temp = temp .. s:sub(i,i) end
    end
    if #temp > 0 then table.insert(t, temp) end
    return t
end
---@return string
function repr(o)
    local str = string.format("%q", o):gsub("\\\n", "\\n")
    str = str:gsub("\\\t", "\\t")
    str = str:gsub("\\\r", "\\r")
    str = str:gsub("\\\f", "\\f")
    return str
end
---@param t table
table.contains = function(t, e)
    for _, v in pairs(t) do if v == e then return true end end
    return false
end
---@param t table
---@param e string
table.containsStart = function(t, e)
    for _, v in pairs(t) do if v:sub(1,#e) == e then return true end end
    return false
end
---@param t table
---@param sep string
table.join = function(t, sep, keys)
    local s = ""
    local f = ipairs
    if keys then f = pairs end
    for k, v in f(t) do
        if keys then s = s..tostring(k).." = " end
        if metatype(v) == "table" then
            s = s..table.tostring(v)..sep
        else 
            s = s..tostring(v)..sep
        end
    end
    if #s > 0 then s = s:sub(1,#s-#sep) end
    return s
end
---@param t table
---@param i number|nil
---@param j number|nil
table.sub = function(t, i, j)
    if not i then i = 1 end
    if not j then j = #t end
    local newT = {}
    for idx = i, j do
        table.insert(newT, t[idx])
    end
    return newT
end
---@param t table
table.copy = function(t)
    if metatype(t) ~= "table" then return t end
    local newT = {}
    for k, v in pairs(t) do newT[k] = table.copy(v) end
    local meta = getmetatable(t)
    if meta then
        local newMetaT = {}
        for k, v in pairs(meta) do newMetaT[k] = table.copy(v) end
        return setmetatable(newT, newMetaT)
    end
    return newT
end
---@param t table
table.tostring = function(t) return "{ "..table.join(t, ", ").." }" end
---@return string
function metatype(object)
    if type(object) == "table" then
        local meta = getmetatable(object)
        if meta then if type(meta.__name) == "string" then return meta.__name end end
    end
    return type(object)
end
---checks for metatype paths with `.` if any of the `...` metatypes are headers of the `value` object's metatype:
---`a.b.c` would match with `a.b.c`, `a.b` and also just `a`, but not `a.e.c`
---@param type1 string
---@param type2 string
---@return boolean
function metaequal(type1, type2)
    local match = true
    local type1_path = type1:split(".")
    local type2_path = type2:split(".")
    for i = 1, math.min(#type1_path, #type2_path) do
        if type2_path[i] ~= type1_path[i] then match = false break end
    end
    return match
end
---throws an error if the `value` object's metatype doesn't match any in `...`.
---Also checks for metatype paths with `.` if any of the `...` metatypes are headers of the `value` object's metatype:
---`a.b.c` would match with `a.b.c`, `a.b` and also just `a`, but not `a.e.c`
---@param label string
---@param ... string
function expect(label, value, ...)
    local types = {...}
    local typ = metatype(value)
    for _, t in pairs(types) do
        if metaequal(typ, t) then return end
    end
    error("expected "..label.." to be of type "..table.join(types, "|")..", not "..typ, 2)
end
string.letters = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N",
    "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "_"
}
string.digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }