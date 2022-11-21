if fs.exists("crs") then
    print("the directory 'crs' already exists, should it be deleted? (y/n) ")
    local answer = read()
    if answer ~= "y" or answer ~= "Y" then return end
end
fs.makeDir("crs")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/crs.lua crs/crs.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/LICENSE crs/LICENSE")
fs.makeDir("crs/src")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/global.lua crs/src/global.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/init.lua crs/src/init.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/lexer.lua crs/src/lexer.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/parser.lua crs/src/parser.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/position.lua crs/src/position.lua")
fs.delete("crs/.gitignore")
fs.delete("crs/installs")
fs.delete("crs/tests")
local completion = require "cc.shell.completion"
shell.setPath(shell.path()..":/crs")
local crsComplete = completion.build(
    { completion.choice, { "run", "comp" } },
    completion.file,
    completion.file
)
shell.setCompletionFunction("crs/crs.lua", crsComplete)