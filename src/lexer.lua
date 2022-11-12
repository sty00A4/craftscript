require "src.global"
require "src.position"

local keywords = { "var", "static", "set", "global", "export", "return", "break" }

local function Token(typ, value, pos)
    expect("typ", typ, "string")
    expect("pos", pos, "position")
    return setmetatable({ type = typ, value = value, pos = pos }, {
        __name = "token", __tostring = function(self)
            return "["..self.type..(type(value) ~= "nil" and ":"..repr(value) or "").."]"
        end
    })
end

---@param path string
---@param text string
local function lex(path, text)
    local col, char = 0, ""
    local lines = text:split("\n")
    local function update(line) char = line:sub(col,col) end
    local function advance(line) col = col + 1 update(line) end
    local function next(ln, line)
        if char == "" then return end
        while table.contains({" ","\t","\r"}, char) and char ~= "" do advance(line) end
        if char == "#" then return end
        -- words
        if table.contains(string.letters, char) then
            local start, stop = col, col
            local word = char
            advance(line)
            while (table.contains(string.letters, char) or table.contains(string.digits, char)) and char ~= "" do
                word = word .. char
                stop = col
                advance(line)
            end
            if table.contains(keywords, word) then
                return Token(word, nil, Position(ln, start, stop, path))
            end
            if word == "true" or word == "false" then
                return Token("bool", word == "true", Position(ln, start, stop, path))
            end
            if word == "nil" then
                return Token("nil", nil, Position(ln, start, stop, path))
            end
            return Token("id", word, Position(ln, start, stop, path))
        end
        -- numbers
        if table.contains(string.digits, char) then
            local start, stop = col, col
            local number = char
            advance(line)
            while table.contains(string.digits, char) and char ~= "" do
                number = number .. char
                stop = col
                advance(line)
            end
            if char == "." then
                number = number .. char
                stop = col
                advance(line)
                while table.contains(string.digits, char) and char ~= "" do
                    number = number .. char
                    stop = col
                    advance(line)
                end
                return Token("float", tonumber(number), Position(ln, start, stop, path))
            end
            return Token("int", tonumber(number), Position(ln, start, stop, path))
        end
        if char == "." then
            local start, stop = col, col
            local number = char
            advance(line)
            while table.contains(string.digits, char) and char ~= "" do
                number = number .. char
                stop = col
                advance(line)
            end
            return Token("float", tonumber(number), Position(ln, start, stop, path))
        end
        -- string
        if char == "\"" or char == "'" then
            local endChar = char
            local start, stop = col, col
            local str = ""
            advance(line)
            while char ~= endChar do
                if char == "\\" then
                    advance(line)
                    if char == "n" then
                        str = str .. "\n"
                    elseif char == "t" then
                        str = str .. "\t"
                    elseif char == "f" then
                        str = str .. "\f"
                    elseif char == "r" then
                        str = str .. "\r"
                    else
                        str = str .. char
                    end
                    stop = col
                    advance(line)
                else
                    str = str .. char
                    stop = col
                    advance(line)
                end
            end
            advance(line)
            return Token("str", str, Position(ln, start, stop, path))
        end
        return nil, "ERROR: illegal character '"..char.."'"
    end
    local tokens = {}
    for ln, line in ipairs(lines) do
        col, char = 0, ""
        advance(line)
        table.insert(tokens, {})
        while char ~= "" do
            local token, err = next(ln, line) if err then return nil, err end
            if token then table.insert(tokens[ln], token) end
        end
    end
    return tokens
end

return { lex=lex, keywords=keywords }