---@param ln number
---@param start number
---@param stop number
---@param path string
---@return table
function Position(ln, start, stop, path)
    expect("ln", ln, "number")
    expect("start", start, "number")
    expect("stop", stop, "number")
    expect("path", path, "string")
    return setmetatable({ ln = ln, start = start, stop = stop, path = path, copy = table.copy }, { __name = "position" })
end