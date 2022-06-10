local ms = require "crs"
local value, context, returning, err
while true do
    io.write("> ")
    local input = io.read()
    value, context, returning, err = ms.execute(input, context)
    if err then print(err)
    else if value then print(value) end end
end