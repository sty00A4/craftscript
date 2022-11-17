local lexer = require("src.lexer")

local precedence = {
    { "or" },
    { "and" },
    { "==", "~=", "<", ">", "<=", ">=" },
    { ".." },
    { "+", "-" },
    { "*", "/" },
    { "-", "not" },
    { "^" },
    { "#" },
}
local function precedenceGT(type1, type2)
    local n1 = #precedence + 1
    for i, types in ipairs(precedence) do
        if table.contains(types, type1) then n1 = i break end
    end
    local n2 = #precedence + 1
    for i, types in ipairs(precedence) do
        if table.contains(types, type2) then n2 = i break end
    end
    return n1 > n2
end
local function precedenceEQ(type1, type2)
    local n1 = #precedence + 1
    for i, types in ipairs(precedence) do
        if table.contains(types, type1) then n1 = i break end
    end
    local n2 = #precedence + 1
    for i, types in ipairs(precedence) do
        if table.contains(types, type2) then n2 = i break end
    end
    return n1 == n2
end

---`node.chunk`
---@param nodes table
---@param pos table
---@return table
local function Chunk(nodes, pos)
    expect("nodes", nodes, "table")
    expect("pos", pos, "position")
    return setmetatable({ nodes = nodes, pos = pos, copy = table.copy }, {
        __name = "node.chunk", __tostring = function(self)
            return table.join(self.nodes, "\n")
        end
    })
end
---`node.body`
---@param nodes table
---@param pos table
---@return table
local function Body(nodes, pos)
    expect("nodes", nodes, "table")
    expect("pos", pos, "position")
    return setmetatable({ nodes = nodes, pos = pos, copy = table.copy }, {
        __name = "node.body", __tostring = function(self)
            return "\n"..table.join(self.nodes, "\n").."\n"
        end
    })
end
---`node.if`
---@param cond table
---@param body table
---@param else_body table|nil
---@param pos table
---@return table
local function If(cond, body, else_body, pos)
    expect("cond", cond, "node")
    expect("body", body, "node")
    expect("else_body", else_body, "node", "nil")
    expect("pos", pos, "position")
    return setmetatable({ cond = cond, body = body, else_body = else_body, pos = pos, copy = table.copy }, {
        __name = "node.if", __tostring = function(self)
            local str = ("if %s then"):format(self.cond)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. tostring(self.body)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            if self.else_body then
                str = str .. "else"
                if metatype(self.else_body) ~= "node.body" and metatype(self.else_body) ~= "node.if" then str = str .. " " end
                str = str .. tostring(self.else_body)
                if metatype(self.else_body) ~= "node.body" then str = str .. " " end
                if metatype(self.else_body) ~= "node.if" then str = str .. "end" end
            else
                str = str .. "end"
            end
            return str
        end
    })
end
---`node.while`
---@param cond table
---@param body table
---@param pos table
---@return table
local function While(cond, body, pos)
    expect("cond", cond, "node")
    expect("body", body, "node")
    expect("pos", pos, "position")
    return setmetatable({ cond = cond, body = body, pos = pos, copy = table.copy }, {
        __name = "node.while", __tostring = function(self)
            local str = ("while %s do"):format(self.cond)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. tostring(self.body)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. "end"
            return str
        end
    })
end
---`node.repeat`
---@param expr table
---@param body table
---@param pos table
---@return table
local function Repeat(expr, body, pos)
    expect("cond", expr, "node")
    expect("body", body, "node")
    expect("pos", pos, "position")
    return setmetatable({ expr = expr, body = body, pos = pos, copy = table.copy }, {
        __name = "node.repeat", __tostring = function(self)
            local str = ("for _ = 1, %s do"):format(self.expr)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. tostring(self.body)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. "end"
            return str
        end
    })
end
---`node.for`
---@param var table
---@param startNode table
---@param stopNode table
---@param stepNode table|nil
---@param body table
---@param pos table
---@return table
local function For(var, startNode, stopNode, stepNode, body, pos)
    expect("var", var, "node.id")
    expect("startNode", startNode, "node")
    expect("stopNode", stopNode, "node")
    expect("stepNode", stepNode, "node", "nil")
    expect("body", body, "node")
    expect("pos", pos, "position")
    return setmetatable({
        var = var, startNode = startNode, stopNode = stopNode, stepNode = stepNode,
        body = body, pos = pos, copy = table.copy
    }, {
        __name = "node.for", __tostring = function(self)
            local str = ("for %s = %s, %s"):format(self.var, self.startNode, self.stopNode)
            if self.stepNode then str = str .. ", " .. tostring(self.stepNode) end
            str = str .. " do"
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. tostring(self.body)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            return str .. "end"
        end
    })
end
---`node.forIn`
---@param vars table
---@param iter table
---@param body table
---@param pos table
---@return table
local function ForIn(vars, iter, body, pos)
    expect("vars", vars, "node.id", "node.args")
    expect("iter", iter, "node")
    expect("body", body, "node")
    expect("pos", pos, "position")
    return setmetatable({ vars = vars, iter = iter, body = body, pos = pos, copy = table.copy }, {
        __name = "node.forIn", __tostring = function(self)
            local str = ("for %s in %s do"):format(self.vars, self.iter)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. tostring(self.body)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            return str .. "end"
        end
    })
end
---`node.proc`
---@param name table
---@param args table|nil
---@param body table
---@param pos table
---@return table
local function Proc(name, args, body, pos)
    expect("name", name, "node.field")
    expect("args", args, "node.args", "node.id", "nil")
    expect("body", body, "node")
    expect("pos", pos, "position")
    return setmetatable({ name = name, args = args, body = body, pos = pos, copy = table.copy }, {
        __name = "node.proc", __tostring = function(self)
            local str = ("function %s (%s)"):format(self.name, self.args or "")
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. tostring(self.body)
            if metatype(self.body) ~= "node.body" then str = str .. " " end
            str = str .. "end"
            return str
        end
    })
end
---`node.assign`
---@param name table
---@param expr table
---@param scoping string|nil
---@param pos table
---@return table
local function Assign(name, expr, scoping, pos)
    expect("name", name, "node")
    expect("expr", expr, "node")
    expect("scoping", scoping, "string", "nil")
    expect("pos", pos, "position")
    return setmetatable({ name = name, expr = expr, scoping = scoping, pos = pos, copy = table.copy }, {
        __name = "node.assign", __tostring = function(self)
            return ("%s%s = %s"):format(((self.scoping ~= "" and (self.scoping.." ")) or ""), self.name, self.expr)
        end
    })
end
---`node.call`
---@param name table
---@param args table|nil
---@param pos table
---@return table
local function Call(name, args, pos)
    expect("name", name, "node")
    expect("args", args, "node", "nil")
    expect("pos", pos, "position")
    return setmetatable({ name = name, args = args, pos = pos, copy = table.copy }, {
        __name = "node.call", __tostring = function(self)
            return ("%s(%s)"):format(self.name, self.args or "")
        end
    })
end
---`node.args`
---@param nodes table
---@param pos table
---@return table
local function Args(nodes, pos)
    expect("nodes", nodes, "table")
    expect("pos", pos, "position")
    return setmetatable({ nodes = nodes, pos = pos, copy = table.copy }, {
        __name = "node.args", __tostring = function(self)
            return table.join(self.nodes, ", ")
        end
    })
end
---`node.field`
---@param nodes table
---@param pos table
---@return table
local function Field(nodes, pos)
    expect("nodes", nodes, "table")
    expect("pos", pos, "position")
    return setmetatable({ nodes = nodes, pos = pos, copy = table.copy }, {
        __name = "node.field", __tostring = function(self)
            local str = tostring(self.nodes[1]) or ""
            if #self.nodes > 1 then
                for i = 2, #self.nodes do
                    if metatype(self.nodes[i]) == "node.id" then
                        str = str .. "." .. tostring(self.nodes[i])
                    else
                        str = str .. "[" .. tostring(self.nodes[i]) .. "]"
                    end
                end
            end
            return str
        end
    })
end
---`node.nil`
---@param pos table
---@return table
local function Nil(pos)
    expect("pos", pos, "position")
    return setmetatable({ pos = pos, copy = table.copy }, {
        __name = "node.nil", __tostring = function(self)
            return "nil"
        end
    })
end
---`node.int`
---@param value number
---@param pos table
---@return table
local function Int(value, pos)
    expect("value", value, "number")
    expect("pos", pos, "position")
    return setmetatable({ value = value, pos = pos, copy = table.copy }, {
        __name = "node.int", __tostring = function(self)
            return tostring(self.value)
        end
    })
end
---`node.float`
---@param value number
---@param pos table
---@return table
local function Float(value, pos)
    expect("value", value, "number")
    expect("pos", pos, "position")
    return setmetatable({ value = value, pos = pos, copy = table.copy }, {
        __name = "node.float", __tostring = function(self)
            return tostring(self.value)
        end
    })
end
---`node.bool`
---@param value boolean
---@param pos table
---@return table
local function Bool(value, pos)
    expect("value", value, "boolean")
    expect("pos", pos, "position")
    return setmetatable({ value = value, pos = pos, copy = table.copy }, {
        __name = "node.bool", __tostring = function(self)
            return tostring(self.value)
        end
    })
end
---`node.str`
---@param value string
---@param pos table
---@return table
local function String(value, pos)
    expect("value", value, "string")
    expect("pos", pos, "position")
    return setmetatable({ value = value, pos = pos, copy = table.copy }, {
        __name = "node.str", __tostring = function(self)
            return repr(self.value)
        end
    })
end
---`node.id`
---@param id string
---@param pos table
---@return table
local function ID(id, pos)
    expect("id", id, "string")
    expect("pos", pos, "position")
    return setmetatable({ id = id, pos = pos, copy = table.copy }, {
        __name = "node.id", __tostring = function(self)
            return self.id
        end
    })
end
---`node.expr`
---@param node node
---@param pos table
---@return table
local function Expr(node, pos)
    expect("node", node, "node")
    expect("pos", pos, "position")
    return setmetatable({ node = node, pos = pos, copy = table.copy }, {
        __name = "node.expr", __tostring = function(self)
            if metatype(self.node) == "node.call" then return tostring(self.node) end
            return "("..tostring(self.node)..")"
        end
    })
end
---`node.break`
---@param pos table
---@return table
local function Break(pos)
    expect("pos", pos, "position")
    return setmetatable({ pos = pos, copy = table.copy }, {
        __name = "node.break", __tostring = function(self)
            return "break"
        end
    })
end
---`node.return`
---@param node table|nil
---@param pos table
---@return table
local function Return(node, pos)
    expect("node", node, "node", "nil")
    expect("pos", pos, "position")
    return setmetatable({ node = node, pos = pos, copy = table.copy }, {
        __name = "node.return", __tostring = function(self)
            return "return" .. (self.node and " "..tostring(self.node) or "")
        end
    })
end
---`node.binary`
---@param op table
---@param left table
---@param right table
---@param pos table
---@return table
local function Binary(op, left, right, pos)
    expect("op", op, "token")
    expect("left", left, "node")
    expect("right", right, "node")
    expect("pos", pos, "position")
    return setmetatable({ op = op, left = left, right = right, pos = pos, copy = table.copy }, {
        __name = "node.binary", __tostring = function(self)
            local str = ""
            if metatype(self.left) == "node.binary" then
                if precedenceGT(self.left.op.type, self.op.type) or precedenceEQ(self.left.op.type, self.op.type) then
                    str = "(" .. tostring(self.left) .. ")"
                else str = tostring(self.left) end
            elseif metatype(self.left) == "node.unary" then
                if precedenceEQ(self.left.op.type, self.op.type) then
                    str = "(" .. tostring(self.left) .. ")"
                else
                    str = tostring(self.left)
                end
            else
                str = tostring(self.left)
            end
            str = str .. " " .. self.op.type .. " "
            if metatype(self.right) == "node.binary" then
                if not precedenceGT(self.right.op.type, self.op.type) or precedenceEQ(self.right.op.type, self.op.type) then
                    str = str .. "(" .. tostring(self.right) .. ")"
                else str = str .. tostring(self.right) end
            elseif metatype(self.right) == "node.unary" then
                if precedenceEQ(self.right.op.type, self.op.type) then
                    str = str .. "(" .. tostring(self.right) .. ")"
                else
                    str = str .. tostring(self.right)
                end
            else
                str = str .. tostring(self.right)
            end
            return str
        end
    })
end
---`node.unary`
---@param op table
---@param node table
---@param pos table
---@return table
local function Unary(op, node, pos)
    expect("op", op, "token")
    expect("node", node, "node")
    expect("pos", pos, "position")
    return setmetatable({ op = op, node = node, pos = pos, copy = table.copy }, {
        __name = "node.unary", __tostring = function(self)
            if metatype(self.node) == "node.binary" then
                if precedenceGT(self.node.op.type, self.op.type) or precedenceEQ(self.node.op.type, self.op.type) then
                    return self.op.type .. " (" .. tostring(self.node) .. ")"
                end
            elseif metatype(self.node) == "node.unary" then
                if precedenceEQ(self.node.op.type, self.op.type) then
                    return self.op.type .. " (" .. tostring(self.node) .. ")"
                end
            end
            return self.op.type.. " " .. tostring(self.node)
        end
    })
end

local nodeNames = {
    ["node.chunk"] = "chunk",
    ["node.body"] = "body",
    ["node.if"] = "if statement",
    ["node.while"] = "while statement",
    ["node.repeat"] = "repeat statement",
    ["node.for"] = "for statement",
    ["node.forIn"] = "for-in statement",
    ["node.assign"] = "assignment",
    ["node.call"] = "call",
    ["node.args"] = "arguments",
    ["node.field"] = "field path",
    ["node.nil"] = "nil",
    ["node.int"] = "integer",
    ["node.float"] = "floating point number",
    ["node.bool"] = "boolean",
    ["node.str"] = "string",
    ["node.id"] = "identifier",
    ["node.expr"] = "expression",
    ["node.break"] = "break",
    ["node.return"] = "return",
}

---@param token table
---@return string
local function unexpeted(token)
    expect("token", token, "token")
    return "ERROR: unexpected "..(lexer.tokenNames[token.type] or ("'"..token.type.."'")) -- get the token name
end
---@param typ string
---@param token table
---@return string
local function expected(typ, token)
    expect("typ", typ, "string")
    expect("token", token, "token")
    return "ERROR: expected "..(lexer.tokenNames[typ] or ("'"..typ.."'"))
    ..", but got "..(lexer.tokenNames[token.type] or ("'"..token.type.."'"))
end
---@param typ string
---@param node table
---@return string
local function expectedNode(typ, node)
    expect("typ", typ, "string")
    expect("node", node, "node")
    return "ERROR: expected "..(lexer.tokenNames[typ] or ("'"..typ.."'"))
    ..", but got "..(lexer.tokenNames[metatype(node)] or ("'"..metatype(node).."'"))
end
---@param node table
---@return string
local function unexpetedNode(node)
    expect("node", node, "node")
    return "ERROR: unexpected "..(nodeNames[metatype(node)] or metatype(node)) -- get the token name
end
---@param path string
---@param tokens table
local function parse(path, tokens)
    local ln, idx, token, pos = 0, 0, nil, nil
    local function update()
        token = tokens[ln][idx]
        pos = token.pos
    end
    local function advance() idx = idx + 1 update() end
    local function advance_line() ln = ln + 1 idx = 1 update() end
    advance_line()
    local function binary(ops, f)
        local left, err = f() if err then return nil, err end
        while table.contains(ops, token.type) do
            local op = token:copy()
            advance()
            local right right, err = f() if err then return nil, err end
            left = Binary(op, left, right, Position(left.pos.lnStart, right.pos.lnStop, left.pos.start, right.pos.stop, path))
        end
        return left
    end
    local chunk, body, stat, _if, _while, _repeat, _for, proc, args, expr, _or, _and, comp, concat, arith, term, factor, pow, len, atom
    -- todo procedure
    -- todo binary operation
    -- todo unary operation
    chunk = function()
        local lnStart, lnStop = pos.lnStart, pos.lnStop
        local start, stop = pos.start, pos.stop
        local nodes = {}
        while token.type ~= "eof" do
            local node, err = stat() if err then return nil, err end
            if node then stop = node.pos.stop lnStop = node.pos.lnStop table.insert(nodes, node) end
            advance_line()
        end
        return Chunk(nodes, Position(lnStart, lnStop, start, stop, path))
    end
    body = function(endTokens)
        local lnStart, lnStop = pos.lnStart, pos.lnStop
        local start, stop = pos.start, pos.stop
        local nodes = {}
        while not table.contains(endTokens, token.type) do
            local node, err = stat() if err then return nil, err end
            if node then stop = node.pos.stop lnStop = node.pos.lnStop table.insert(nodes, node) end
            advance_line()
        end
        return Body(nodes, Position(lnStart, lnStop, start, stop, path))
    end
    ---@param scoping string|nil
    ---@param endToken string|nil
    stat = function(scoping, endToken)
        if not endToken then endToken = "eol" end expect("endToken", endToken, "string")
        if not scoping then scoping = "" end expect("scoping", scoping, "string") -- check scoping
        local start, stop = pos.start, pos.stop
        local node = nil
        if token.type == "local" then -- local prefix
            if scoping ~= "" then return nil, unexpeted(token) end -- prefix already exists
            scoping = token.type
            advance()
            node, err = stat(scoping) if err then return nil, err end
            node.start = start -- reset position
            return node
        end
        if token.type == "if" then return _if() end
        if token.type == "while" then return _while() end
        if token.type == "repeat" then return _repeat() end
        if token.type == "for" then return _for() end
        if token.type == "proc" then return proc() end
        if token.type == "break" then
            node = Break(Position(token.pos.lnStart, token.pos.lnStop, token.pos.start, token.pos.stop, path))
            advance()
            if token.type ~= "eol" then return nil, unexpeted(token) end
            return node
        end
        if token.type == "return" then
            advance()
            if token.type == "eol" then
                stop = token.pos.stop
                return Return(nil, Position(ln, ln, start, stop, path))
            end
            local _node, err = expr() if err then return nil, err end
            stop = _node.pos.stop
            if token.type ~= "eol" then return nil, unexpeted(token) end
            node = Return(_node, Position(ln, ln, start, stop, path))
        end
        while token.type ~= endToken do
            local fieldPath = {}
            while token.type ~= endToken and token.type ~= "=" and token.type ~= "!" do
                local _node, err = expr() if err then return nil, err end
                table.insert(fieldPath, _node)
                stop = pos.stop
            end -- field path until end of line, '=' or '!'
            node = #fieldPath > 1
                and Field(fieldPath, Position(ln, ln, start, stop, path))
                or (
                    #fieldPath == 1
                    and fieldPath[#fieldPath]
                    or nil
                )
            if token.type == "=" then -- assign
                stop = pos.stop
                if not node then return nil, unexpeted(token) end
                advance()
                local _expr, err = expr() if err then return nil, err end
                node = Assign(node, _expr or {}, scoping, Position(ln, ln, start, stop, path))
            elseif token.type == "!" then -- call
                stop = pos.stop
                if not node then return nil, unexpeted(token) end
                advance()
                if token.type ~= endToken then
                    local _args, err = args() if err then return nil, err end
                    stop = _args.pos.stop
                    node = Call(node, _args, Position(ln, ln, start, stop, path))
                else
                    node = Call(node, nil, Position(ln, ln, start, stop, path))
                end
                if scoping ~= "" then return nil, unexpetedNode(node) end
            else break end
        end
        return node
    end
    _if = function()
        local lnStart, lnStop = pos.lnStart, pos.lnStop
        local start, stop = pos.start, pos.stop
        if token.type ~= "if" then return nil, expected("if", token) end
        advance()
        local cond, err = expr() if err then return nil, err end
        local _body
        if token.type ~= "eol" then
            _body, err = stat() if err then return nil, err end
            advance_line()
        else
            advance_line()
            _body, err = body({"else", "end"}) if err then return nil, err end
        end
        if token.type == "else" then
            local else_body
            advance()
            if token.type ~= "eol" then
                else_body, err = stat() if err then return nil, err end
            else
                advance_line()
                else_body, err = body({"end"}) if err then return nil, err end
                stop = pos.stop lnStop = pos.lnStop
                if token.type ~= "end" then return nil, expected("end", token) end
                advance()
                if token.type ~= "eol" then return nil, expected("eol", token) end
            end
            return If(cond, _body, else_body, Position(lnStart, lnStop, start, stop, path))
        end
        if token.type ~= "end" then return nil, expected("end", token) end
        lnStop = pos.lnStop
        advance()
        if token.type ~= "eol" then return nil, expected("eol", token) end
        return If(cond, _body, nil, Position(lnStart, lnStop, start, stop, path))
    end
    _while = function()
        local lnStart, lnStop = pos.lnStart, pos.lnStop
        local start, stop = pos.start, pos.stop
        if token.type ~= "while" then return nil, expected("while", token) end
        advance()
        local cond, err = expr() if err then return nil, err end
        local _body
        if token.type ~= "eol" then
            _body, err = stat() if err then return nil, err end
            advance_line()
        else
            advance_line()
            _body, err = body({"end"}) if err then return nil, err end
            lnStop = pos.lnStop
            if token.type ~= "end" then return nil, expected("end", token) end
            advance()
            if token.type ~= "eol" then return nil, expected("eol", token) end
        end
        return While(cond, _body, Position(lnStart, lnStop, start, stop, path))
    end
    _repeat = function()
        local lnStart, lnStop = pos.lnStart, pos.lnStop
        local start, stop = pos.start, pos.stop
        if token.type ~= "repeat" then return nil, expected("repeat", token) end
        advance()
        local _expr, err = expr() if err then return nil, err end
        local _body
        if token.type ~= "eol" then
            _body, err = stat() if err then return nil, err end
        else
            advance_line()
            _body, err = body({"end"}) if err then return nil, err end
            lnStop = pos.lnStop
            if token.type ~= "end" then return nil, expected("end", token) end
            advance()
            if token.type ~= "eol" then return nil, expected("eol", token) end
        end
        return Repeat(_expr, _body, Position(lnStart, lnStop, start, stop, path))
    end
    _for = function()
        local lnStart, lnStop = pos.lnStart, pos.lnStop
        local start, stop = pos.start, pos.stop
        if token.type ~= "for" then return nil, expected("for", token) end
        advance()
        local vars, err = args() if err then return nil, err end
        local _body
        if token.type == "=" then
            advance()
            if metatype(vars) ~= "node.id" then return nil, expectedNode("node.id", vars) end
            local startNode startNode, err = expr() if err then return nil, err end
            if token.type ~= "," then return nil, expected(",", token) end
            advance()
            local stopNode stopNode, err = expr() if err then return nil, err end
            local stepNode
            if token.type == "," then advance() stepNode, err = expr() if err then return nil, err end end
            if token.type ~= "eol" then
                _body, err = stat() if err then return nil, err end
            else
                advance_line()
                _body, err = body({"end"}) if err then return nil, err end
                lnStop = pos.lnStop
                if token.type ~= "end" then return nil, expected("end", token) end
                advance()
                if token.type ~= "eol" then return nil, expected("eol", token) end
            end
            return For(vars, startNode, stopNode, stepNode, _body, Position(lnStart, lnStop, start, stop, path))
        elseif token.type == "in" then
            advance()
            local iter iter, err = expr() if err then return nil, err end
            if token.type ~= "eol" then
                _body, err = stat() if err then return nil, err end
            else
                advance_line()
                _body, err = body({"end"}) if err then return nil, err end
                lnStop = pos.lnStop
                if token.type ~= "end" then return nil, expected("end", token) end
                advance()
                if token.type ~= "eol" then return nil, expected("eol", token) end
            end
            return ForIn(vars, iter, _body, Position(lnStart, lnStop, start, stop, path))
        end
        return nil, unexpeted(token)
    end
    proc = function()
        local lnStart, lnStop = pos.lnStart, pos.lnStop
        local start, stop = pos.start, pos.stop
        if token.type ~= "proc" then return nil, expected("proc", token) end
        advance()
        local fieldPath = {}
        while token.type == "id" do
            table.insert(fieldPath, ID(token.value, token.pos))
            stop = pos.stop
            advance()
        end
        local name = Field(fieldPath, Position(ln, ln, start, stop, path))
        local _args, err
        if token.type == ":" then
            advance()
            _args, err = args() if err then return nil, err end
        end
        local _body
        if token.type ~= "eol" then
            _body, err = stat() if err then return nil, err end
            advance_line()
        else
            advance_line()
            _body, err = body({"end"}) if err then return nil, err end
            lnStop = pos.lnStop
            if token.type ~= "end" then return nil, expected("end", token) end
            advance()
            if token.type ~= "eol" then return nil, expected("eol", token) end
        end
        return Proc(name, _args, _body, Position(lnStart, lnStop, start, stop, path))
    end
    expr = function()
        local node, err = _or() if err then return nil, err end
        return node
    end
    _or = function()
        return binary({"or"}, _and)
    end
    _and = function()
        return binary({"and"}, comp)
    end
    comp = function()
        return binary({"==", "~=", "<", ">", "<=", ">="}, concat)
    end
    concat = function()
        return binary({".."}, arith)
    end
    arith = function()
        return binary({"+", "-"}, term)
    end
    term = function()
        return binary({"*", "/"}, factor)
    end
    factor = function()
        if token.type == "-" or token.type == "not" then
            local op = token:copy()
            advance()
            local node, err = factor() if err then return nil, err end
            return Unary(op, node, Position(token.pos.lnStart, node.pos.lnStop, token.pos.start, node.pos.stop, path))
        end
        return pow()
    end
    pow = function()
        return binary({"^"}, len)
    end
    len = function()
        if token.type == "#" then
            local op = token:copy()
            advance()
            local node, err = len() if err then return nil, err end
            return Unary(op, node, Position(token.pos.lnStart, node.pos.lnStop, token.pos.start, node.pos.stop, path))
        end
        return atom()
    end
    args = function()
        local start, stop = pos.start, pos.stop
        local nodes = {}
        local node, err = expr() if err then return nil, err end
        table.insert(nodes, node)
        while token.type == "," do
            advance()
            node, err = expr() if err then return nil, err end
            if node then stop = node.pos.stop end
            table.insert(nodes, node)
        end
        if #nodes == 1 then return nodes[1] end
        return Args(nodes, Position(ln, ln, start, stop, path))
    end
    atom = function()
        local _token = token:copy()
        if token.type == "nil" then advance() return Nil(_token.pos) end
        if token.type == "int" then advance() return Int(_token.value, _token.pos) end
        if token.type == "float" then advance() return Float(_token.value, _token.pos) end
        if token.type == "bool" then advance() return Bool(_token.value, _token.pos) end
        if token.type == "str" then advance() return String(_token.value, token.pos) end
        if token.type == "id" then advance() return ID(_token.value, token.pos) end
        if token.type == "(" then
            local start = pos.start
            advance()
            local node, err = stat("", ")") if err then return nil, err end
            if metatype(node) == "node.assign" then return nil, unexpetedNode(node) end
            local stop = pos.stop
            advance()
            return Expr(node, Position(ln, ln, start, stop, path))
        end
        return nil, unexpeted(token)
    end
    return chunk()
end

return {
    parse=parse,
    Chunk=Chunk, Assign=Assign, Call=Call, Args=Args,
    Field=Field, Nil=Nil, Int=Int, Float=Float, Bool=Bool, String= String, ID=ID
}