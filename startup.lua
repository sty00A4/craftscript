local completion = require "cc.shell.completion"
shell.setPath(shell.path()..":/crs")
local crsComplete = completion.build(
    { completion.choice, { "run", "comp", "update" } },
    completion.file,
    completion.file
)
shell.setCompletionFunction("crs/crs.lua", crsComplete)