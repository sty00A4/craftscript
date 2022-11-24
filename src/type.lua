require "src.global"
require "src.position"
local parser = require "src.parser"

local function Any()
    return setmetatable({
        copy = table.copy,
    }, {
        __name = "type.any", __tostring = function() return "any" end
    })
end
local function Nil()
    return setmetatable({
        copy = table.copy,
    }, {
        __name = "type.nil", __tostring = function() return "nil" end
    })
end
local function Number()
    return setmetatable({
        copy = table.copy,
    }, {
        __name = "type.number", __tostring = function() return "number" end
    })
end
local function Boolean()
    return setmetatable({
        copy = table.copy,
    }, {
        __name = "type.boolean", __tostring = function() return "boolean" end
    })
end
local function String()
    return setmetatable({
        copy = table.copy,
    }, {
        __name = "type.string", __tostring = function() return "string" end
    })
end
local function Table(typ, length, keys)
    expect("typ", typ, "type")
    expect("length", length, "number", "nil")
    expect("keys", keys, "table", "nil")
    for k, v in pairs(keys) do expect("keys."..tostring(k), v, "type") end
    return setmetatable({
        length = length, type = typ, keys = keys, copy = table.copy,
    }, {
        __name = "type.table", __tostring = function(self) return "table<"..tostring(self.type)..">" end
    })
end
local function Union(types)
    expect("types", types, "table")
    for k, v in pairs(types) do expect("types."..tostring(k), v, "type") end
    return setmetatable({
        types = types, copy = table.copy,
    }, {
        __name = "type.union", __tostring = function(self) return table.join(self.types, "|") end
    })
end

local function matchTypes(typ, ...)
    local types = {...}
    if metatype(typ) == "type.any" then return true end
    for _, t in ipairs(types) do
        if metatype(t) == "type.any" then return true end
        if metatype(typ) == metatype(t) then return true end
    end
    return false
end

local function createUnion(...)
    local _types = {...}
    local types = {}
    for _, t in ipairs(_types) do
        if not table.contains(types, t) then table.insert(types, t) end
    end
    return Union(types)
end

local function get(node, context)
    expect("node", node, "node")
    expect("context", context, "table")
    local match = {
        ["node.nil"] = function() return Nil() end,
        ["node.int"] = function() return Number() end,
        ["node.float"] = function() return Number() end,
        ["node.bool"] = function() return Boolean() end,
        ["node.str"] = function() return String() end,
        ["node.id"] = function() return Any() end, -- todo node.id typecheck
        ["node.expr"] = function() return get(node.node, context) end,
        ["node.call"] = function() return get(node.args, context) end,
        ["node.args"] = function()
            for _, n in ipairs(node.nodes) do
                local _, err = get(n, context) if err then return nil, err end
            end
            return Any()
        end,
        ["node.if"] = function()
            local _, err = get(node.cond, context) if err then return nil, err end
            _, err = get(node.body, context) if err then return nil, err end
            _, err = get(node.else_body, context) if err then return nil, err end
            return Any()
        end,
        ["node.while"] = function()
            local _, err = get(node.cond, context) if err then return nil, err end
            _, err = get(node.body, context) if err then return nil, err end
            return Any()
        end,
        ["node.repeat"] = function()
            local _, err = get(node.expr, context) if err then return nil, err end
            _, err = get(node.body, context) if err then return nil, err end
            return Any()
        end,
        ["node.for"] = function()
            local _, err = get(node.var, context) if err then return nil, err end
            local start start, err = get(node.startNode, context) if err then return nil, err end
            if not matchTypes(start, Number()) then
                return nil, ("ERROR: expected type %s, got %s"):format(Number(), start)
            end
            local stop stop, err = get(node.stopNode, context) if err then return nil, err end
            if not matchTypes(stop, Number()) then
                return nil, ("ERROR: expected type %s, got %s"):format(Number(), stop)
            end
            local step step, err = get(node.stepNode, context) if err then return nil, err end
            if not matchTypes(step, Number()) then
                return nil, ("ERROR: expected type %s, got %s"):format(Number(), step)
            end
            _, err = get(node.body, context) if err then return nil, err end
            return Any()
        end,
        ["node.forIn"] = function()
            local _, err = get(node.vars, context) if err then return nil, err end
            _, err = get(node.iter, context) if err then return nil, err end
            _, err = get(node.body, context) if err then return nil, err end
            return Any()
        end,
        ["node.proc"] = function()
            local _, err = get(node.name, context) if err then return nil, err end
            _, err = get(node.args, context) if err then return nil, err end
            _, err = get(node.body, context) if err then return nil, err end
            return Any()
        end,
        ["node.assign"] = function()
            local _, err = get(node.name, context) if err then return nil, err end
            _, err = get(node.expr, context) if err then return nil, err end
            return Any()
        end,
        ["node.field"] = function()
            return Any() -- todo node.field typecheck
        end,
        ["node.binary"] = function()
            local left, err = get(node.left, context) if err then return nil, err end
            local right right, err = get(node.right, context) if err then return nil, err end
            if table.contains({"+", "-", "*", "/", "%", "^", ">", "<", ">=", "<="}, node.op.type) then
                if not matchTypes(left, Number()) or not matchTypes(right, Number()) then
                    return nil, ("ERROR: attempt to perform '%s' on %s and %s"):format(node.op.type, left, right)
                end
                return Number()
            end
            if node.op.type == ".." then
                if not matchTypes(left, String()) or not matchTypes(right, String()) then
                    return nil, ("ERROR: attempt to perform '%s' on %s and %s"):format(node.op.type, left, right)
                end
                return String()
            end
            if table.contains({"==", "~="}, node.op.type) then
                return Boolean()
            end
            if node.op.type == "and" then
                return createUnion(Boolean(), right:copy())
            end
            if node.op.type == "or" then
                return createUnion(left:copy(), right:copy())
            end
            return Any()
        end,
        ["node.unary"] = function()
            local value, err = get(node.node, context) if err then return nil, err end
            if node.op.type == "-" then
                if not matchTypes(value, Number()) then
                    return nil, ("ERROR: attempt to perform '%s' on %s"):format(node.op.type, value)
                end
                return Number()
            end
            if node.op.type == "not" then
                return Boolean()
            end
            if node.op.type == "#" then
                if not matchTypes(value, String(), Table()) then
                    return nil, ("ERROR: attempt to perform '%s' on %s"):format(node.op.type, value)
                end
                return Number()
            end
            return Any()
        end,
        ["node.return"] = function() if node.node then return get(node.node, context) else return Nil() end end,
        ["node.chunk"] = function()
            local types = {}
            for _, n in ipairs(node.nodes) do
                if metatype(n) == "node.return" then
                    local typ, err = get(n, context) if err then return nil, err end
                    if typ then
                        if metatype(typ) == "type.union" then
                            for _, t in ipairs(typ.types) do table.insert(types, t) end
                        else
                            table.insert(types, typ)
                        end
                    end
                    return Union(types)
                end
                local typ, err = get(n, context) if err then return nil, err end
                if typ then
                    if metatype(typ) == "type.union" then
                        for _, t in ipairs(typ.types) do table.insert(types, t) end
                    else
                        table.insert(types, typ)
                    end
                end
            end
            table.insert(types, Nil())
            return Union(types)
        end,
        ["node.body"] = function()
            local types = {}
            for _, n in ipairs(node.nodes) do
                if metatype(n) == "node.return" then
                    local typ, err = get(n, context) if err then return nil, err end
                    if typ then
                        if metatype(typ) == "type.union" then
                            for _, t in ipairs(typ.types) do table.insert(types, t) end
                        else
                            table.insert(types, typ)
                        end
                    end
                    return Union(types)
                end
                if metatype(n) == "node.break" then break end
                local typ, err = get(n, context) if err then return nil, err end
                if typ then
                    if metatype(typ) == "type.union" then
                        for _, t in ipairs(typ.types) do table.insert(types, t) end
                    else
                        table.insert(types, typ)
                    end
                end
            end
            table.insert(types, Nil())
            return Union(types)
        end,
    }
    return match[metatype(node)]()
end

return {
    get=get,
    Any=Any, Nil=Nil, Number=Number, Boolean=Boolean,
    String=String, Table=Table, Union=Union
}