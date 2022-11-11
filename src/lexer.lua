require "src.global"
require "src.position"

local keywords = { "var", "static", "set", "global", "export", "return", "break" }

local function Token(typ, value, pos)
    expect("typ", typ, "string")
    expect("pos", pos, "position")
    return setmetatable({ type = typ, value = value, pos = pos }, {
        __name = "token", __tostring = function(self)
            return "["..self.type..(type(value) ~= "nil" and ":"..tostring(value) or "").."]"
        end
    })
end

---@param path string
---@param text string
---@return table
local function lex(path, text)
    local col, char = 0, ""
    local lines = text:split("\n")
    local function update(line) char = line:sub(col,col) end
    local function advance(line) col = col + 1 update(line) end
    local function next(ln, line)
        while table.contains({" ","\t","\r"}, char) and char do advance(line) end
        if char == "#" then return end
        if table.contains(string.letters, char) then
            local start, stop = col, col
            local word = char
            advance(line)
            while (table.contains(string.letters, char) or table.contains(string.digits, char)) and char do
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
        if table.contains(string.digits, char) then
            local start, stop = col, col
            local number = char
            advance(line)
            while table.contains(string.digits, char) and char do
                number = number .. char
                stop = col
                advance(line)
            end
            if char == "." then
                number = number .. char
                stop = col
                advance(line)
                while table.contains(string.digits, char) and char do
                    number = number .. char
                    stop = col
                    advance(line)
                end
                return Token("float", tonumber(number), Position(ln, start, stop, path))
            end
            return Token("int", tonumber(number), Position(ln, start, stop, path))
        end
        if char == "(" then
            
        end
    end
    local tokens = {}
    for ln, line in ipairs(lines) do
        table.insert(tokens, {})
        while char do
            local token = next(ln, line)
        end
    end
    return tokens
end

return { lex=lex, keywords=keywords }