local cs = require "src"
local args = {...}
if args[1] == "-comp" then
    print("compiler comming soon...") return
elseif args[1] then
    local file = io.open(args[1], "r")
    if not file then print("ERROR: file '"..args[1].."' not found") return end
    local text = file:read("*a")
    local lines, err = cs.lexer.lex(args[1], text) if err then print(err) return end
    if lines then print(table.tostring(lines)) end
end