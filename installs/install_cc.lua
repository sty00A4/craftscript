local args = {...}
if fs.exists("crs") and not args[1] then
    print("the directory 'crs' already exists, should it be deleted? (y/n) ")
    local answer = read()
    if answer ~= "y" or answer ~= "Y" then return end
    fs.delete("crs")
end
fs.makeDir("crs")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/crs.lua crs/crs.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/LICENSE crs/LICENSE")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/VERSION crs/VERSION")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/VERSION crs/startup.lua")
fs.makeDir("crs/src")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/global.lua crs/src/global.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/init.lua crs/src/init.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/lexer.lua crs/src/lexer.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/parser.lua crs/src/parser.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/src/position.lua crs/src/position.lua")
shell.run("wget https://raw.githubusercontent.com/sty00A4/craftscript/main/installs/install_cc.lua crs/installs/install_cc.lua")
fs.move("crs/startup.lua", "startup.lua")
fs.delete(shell.getRunningProgram())