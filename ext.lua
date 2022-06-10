table.contains = function(t, val) for _, v in pairs(t) do if v == val then return true end end return false end
table.containsStart = function(t, val) for _, v in pairs(t) do if v:sub(1,#val) == val then return true end end return false end
table.containsKey = function(t, key) for k, _ in pairs(t) do if k == key then return true end end return false end
table.keyOfValue = function(t, val) for k, v in pairs(t) do if v == val then return k end end end
table.sub = function(t, i, j)
    if not j then j = #t end
    local nt = {}
    for idx,v in ipairs(t) do if idx >= i and idx <= j then table.insert(nt, v) end end
    return nt
end
string.split = function(s, sep)
    local t, temp = {}, ""
    for i = 1, #s do
        if s:sub(i,i) == sep then
            if #temp > 0 then table.insert(t, temp) end
            temp = ""
        else
            temp = temp .. s:sub(i,i)
        end
    end
    if #temp > 0 then table.insert(t, temp) end
    return t
end
string.splits = function(s, seps)
    local t, temp = {}, ""
    for i = 1, #s do
        if table.contains(seps, s:sub(i,i)) then
            if #temp > 0 then table.insert(t, temp) end
            temp = ""
        else
            temp = temp .. s:sub(i,i)
        end
    end
    if #temp > 0 then table.insert(t, temp) end
    return t
end
string.join = function(s, t)
    local str = ""
    for _, v in pairs(t) do
        str = str .. tostring(v) .. s
    end
    return str:sub(1, #str-#s)
end
string.letters = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" }
string.lowercase = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" }
string.uppercase = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z" }
string.digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }