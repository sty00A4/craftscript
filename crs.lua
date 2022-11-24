local cs = require "src"
local args = {...}
if args[1] == "update" then
    if not http or not fs or not shell then return print "update only supported in CraftOS" end
    local file = http.get("https://raw.githubusercontent.com/sty00A4/craftscript/main/VERSION", nil, true)
    if not file then return print "failed to update (no response from server)" end
    local version = file.readAll()
    file.close()
    file = fs.open("crs/VERSION", "r")
    if not file then
        print "no version tracking"
        print("updating to "..version.."...")
        shell.run "pastebin get R5q42BEk install"
        shell.run "install yes"
        return
    end
    local currentVersion = file.readAll()
    file.close()
    if currentVersion == version then
        print(currentVersion.." "..version)
        return print "already on the newest version "..currentVersion
    else
        print("updating to "..version.."...")
        shell.run "pastebin get R5q42BEk install"
        shell.run "install yes"
        return
    end
end
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
    _, err = cs.type.get(ast, {}) if err then print(err) return end
    local target_path = args[3]
    if not target_path then
        local split = path:split(".")
        target_path = table.join(table.sub(split, 1, math.max(#split-1, 1)), ".")..".lua"
        file = io.open(target_path, "w")
        if not file then print("ERROR: couldn't open target file '"..target_path.."'") return end
        file:write(tostring(ast)) file:close()
    end
    if run then
        if shell then
            local res = { pcall(shell.run, target_path) } if not res[1] then print(res[2]) end
            return table.sub(res, 2)
        end
        local res = { pcall(dofile, target_path) } if not res[1] then print(res[2]) end
        return table.sub(res, 2)
    end
end