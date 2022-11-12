---@param lnStart number
---@param lnStop number
---@param start number
---@param stop number
---@param path string
---@return table
function Position(lnStart, lnStop, start, stop, path)
    expect("lnStart", lnStart, "number")
    expect("lnStop", lnStop, "number")
    expect("start", start, "number")
    expect("stop", stop, "number")
    expect("path", path, "string")
    return setmetatable({
        lnStart = lnStart, lnStop = lnStop, start = start, stop = stop,
        path = path, copy = table.copy
    }, { __name = "position" })
end