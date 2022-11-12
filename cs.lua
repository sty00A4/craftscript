local cs = require "src"
local args = {...}
local idx = 1
local run = false
while true do
    if args[idx] == "-r" then run = true idx = idx + 1
    else break end
end
local path = args[idx] idx = idx + 1
local file = io.open(path, "r")
if not file then print("ERROR: file '"..path.."' not found") return end
local text = file:read("*a")
file:close()

local tokens, err = cs.lexer.lex(path, text) if err then print(err) return end
if tokens then for ln, line in ipairs(tokens) do print(tostring(ln).." "..table.join(line, " ")) end end

local ast, err = cs.parser.parse(tokens) if err then print(err) return end
if ast then print(ast) end