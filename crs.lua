local cs = require "src"
local args = {...}
local run = args[1] == "run"
local path = args[2]
local file = io.open(path, "r")
if not file then print("ERROR: file '"..path.."' not found") return end
local text = file:read("*a") file:close()

local tokens, err = cs.lexer.lex(path, text) if err then print(err) return end
if tokens then
    -- for ln, line in ipairs(tokens) do print(tostring(ln).." "..table.join(line, " ")) end
    local ast ast, err = cs.parser.parse(path, tokens) if err then print(err) return end
    -- if ast then print(ast) end
    local target_path = args[3]
    if not target_path then
        local split = path:split(".")
        target_path = table.join(table.sub(split, 1, math.max(#split-1, 1)), ".")..".lua"
        file = io.open(target_path, "w")
        if not file then print("ERROR: couldn't open target file '"..target_path.."'") return end
        file:write(tostring(ast)) file:close()
    end
    if run then
        local res = { pcall(dofile, target_path) } if not res[1] then print(res[2]) end
        return table.sub(res, 2)
    end
end