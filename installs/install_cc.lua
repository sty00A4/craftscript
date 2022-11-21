shell.run("wget https://github.com/sty00A4/craftscript.git crs")
fs.delete("crs/.gitignore")
fs.delete("crs/installs")
fs.delete("crs/tests")
local completion = require "cc.shell.completion"
shell.setPath(shell.path()..":/crs")
local crsComplete = completion.build(
    { completion.choice, { "run", "comp" } },
    { completion.file, many = true },
    { completion.file, many = true }
)
shell.setCompletionFunction("crs/crs.lua", crsComplete)