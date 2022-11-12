require "src.global"
require "src.position"

local keywords = {
    "local", "export",
    "if", "else", "while", "repeat", "for", "return", "break",
    "then", "do", "end", "in",
    "and", "or", "not"
}
local symbols = { "=", "!", "@", ",", ":", "+", "-", "*", "/", "^", "?", "==", "!=", "<", ">", "(", ")", "[", "]", "{", "}" }

local function Token(typ, value, pos)
    expect("typ", typ, "string")
    expect("pos", pos, "position")
    return setmetatable({ type = typ, value = value, pos = pos, copy = table.copy }, {
        __name = "token", __tostring = function(self)
            return "["..self.type..(type(value) ~= "nil" and ":"..repr(value) or "").."]"
        end
    })
end

local tokenNames = {
    eof = "end of file",
    eol = "end of line"
}

---@param path string
---@param text string
local function lex(path, text)
    expect("path", path, "string")
    expect("text", text, "string")
    local col, char = 0, ""
    local lines = text:split("\n")
    local function update(line) char = line:sub(col,col) end
    local function advance(line) col = col + 1 update(line) end
    local function next(ln, line)
        if char == "" then return end
        while table.contains({" ","\t","\r"}, char) and char ~= "" do advance(line) end
        if char == "#" then return end
        if table.containsStart(symbols, char) then
            local start, stop = col, col
            local symbol = char
            advance(line)
            while table.containsStart(symbols, symbol .. char) and char ~= "" do
                symbol = symbol .. char
                stop = col
                advance(line)
            end
            if table.contains(symbols, symbol) then
                return Token(symbol, nil, Position(ln, ln, start, stop, path))
            end
            return nil, "ERROR: illegal symbol '"..symbol.."'"
        end
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
                return Token(word, nil, Position(ln, ln, start, stop, path))
            end
            if word == "true" or word == "false" then
                return Token("bool", word == "true", Position(ln, ln, start, stop, path))
            end
            if word == "nil" then
                return Token("nil", nil, Position(ln, ln, start, stop, path))
            end
            return Token("id", word, Position(ln, ln, start, stop, path))
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
                return Token("float", tonumber(number), Position(ln, ln, start, stop, path))
            end
            return Token("int", tonumber(number), Position(ln, ln, start, stop, path))
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
            return Token("float", tonumber(number), Position(ln, ln, start, stop, path))
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
                    if char == "n" then str = str .. "\n"
                    elseif char == "t" then str = str .. "\t"
                    elseif char == "f" then str = str .. "\f"
                    elseif char == "r" then str = str .. "\r"
                    else str = str .. char end
                    stop = col
                    advance(line)
                else
                    str = str .. char
                    stop = col
                    advance(line)
                end
            end
            advance(line)
            return Token("str", str, Position(ln, ln, start, stop, path))
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
        table.insert(tokens[ln], Token("eol", nil, Position(ln, ln, col, col, path)))
    end
    table.insert(tokens, {}) table.insert(tokens[#tokens], Token("eof", nil, Position(#lines+1, #lines+1, 1, 1, path)))
    return tokens
end

return { lex=lex, keywords=keywords, symbols=symbols, tokenNames=tokenNames }