require "ext"
local function todo(text) if text then error(text, 2) else error("TODO", 2) end end
local function tree(obj, prefix, subprefix)
    if not prefix then prefix = "" end
    if not subprefix then subprefix = "  " end
    if getmetatable(obj) then
        local objMeta = getmetatable(obj)
        if objMeta.__name then
            if objMeta.__name:sub(#objMeta.__name-3, #objMeta.__name) == "Node" then
                local str = objMeta.__name.."\n"
                for k, v in pairs(obj) do
                    if type(v) ~= "function" and tree(v, prefix..subprefix, subprefix) then
                        str=str..prefix..tostring(k)..": "..tree(v, prefix..subprefix, subprefix).."\n"
                    end
                end
                return str:sub(1, #str-1)
            end
        end
        return tostring(obj)
    end
    if type(obj) == "table" then
        local str = "\n"
        for k, v in pairs(obj) do
            if tree(v) then str=str..prefix..tostring(k)..": "..tree(v, prefix..subprefix, subprefix).."\n" end
        end
        return str:sub(1, #str-1)
    else return tostring(obj) end
end
local function Position(idx, col, ln, fn, ftext)
    return setmetatable(
            { idx = idx, col = col, ln = ln, fn = fn, ftext = ftext,
              copy = function(s) return Position(s.idx, s.col, s.ln, s.fn, s.ftext) end },
            { __name = "Position" }
    )
end
local function PositionRange(start, stop)
    return setmetatable(
            { start = start, stop = stop, copy = function(s) return PositionRange(s.start:copy(), s.stop:copy()) end },
            { __name = "PositionRange" }
    )
end
local function Error(type_, details, pr)
    return setmetatable(
            { type = type_, details = details, pr = pr,
              code = ("\n"):join(table.sub((pr.start.ftext):split("\n"), pr.start.ln, pr.stop.ln))
            },
            { __name = "Error",
              __tostring = function(s)
                  return "\n"..s.type..": "..s.details
                          .."\nin "..s.pr.start.fn..", ln "..tostring(s.pr.start.ln).."-"..tostring(s.pr.stop.ln)
                          .."\n"..s.code.."\n"
              end }
    )
end
local function Token(type_, value, pr)
    return setmetatable(
            { type = type_, value = value, pr = pr, copy = function(s) return Token(s.type, s.value, s.pr:copy()) end },
            { __name = "Token",
              __tostring = function(s) if s.value ~= nil then return "["..s.type..":"..tostring(s.value).."]" else return "["..s.type.."]" end end,
              __eq = function(s, o) if o.value ~= nil and s.value ~= nil then return s.value == o.value and s.type == o.type else return s.type == o.type end end
            }
    )
end
local T = {
    eof = "eof", nl = "new line", kw = "keyword", null = "null", name = "name", smbl = "symbol", type = "type", num = "number", str = "string", bool = "boolean"
}
local KW = {
    if_ = "if", else_ = "else", elif_ = "elif", while_ = "while", repeat_ = "repeat", for_ = "for", end_ = "end",
    macro = "macro", assign = "is", and_ = "and", or_ = "or", not_ = "not", len = "len", contains = "cont", typeDef = "as",
    with = "with", in_ = "in", return_ = "return"
}
local TKW = { null = "Null", num = "Number", str = "String", bool = "Boolean", array = "Array", object = "Object", type = "Type",
              macro = "Macro", func = "Function" }
local STRDEF = '"'
local NULL = "null"
local BOOLS = { "true", "false" }
local SMBLS = {
    eq = "=", ne = "~=", lt = "<", gt = ">", le = "<=", ge = ">=",
    add = "+", sub = "-", mul = "*", div = "/", idiv = "//", mod = "%", index = ":",
    pow = "^", do_ = "!", evalIn = "(", evalOut = ")", arrayIn = "[", arrayOut = "]", sep = ",",
    range = ".."
}

local function lex(fn, raw)
    if not raw then return {} end
    local tokens, pos, char = {}, Position(0, 0, 1, fn, raw)
    local function update()
        if pos.idx <= #raw then char = raw:sub(pos.idx,pos.idx) else char = nil end
    end
    local function advance()
        pos.idx = pos.idx + 1
        pos.col = pos.col + 1
        update()
        if char == "\n" then
            pos.ln = pos.ln + 1
            pos.col = 1
        end
    end
    advance()
    while char do
        if char == " " or char == "\t" then advance()
        elseif char == "\n" or char == ";" then table.insert(tokens, Token(T.nl, nil, PositionRange(pos:copy(),pos:copy()))) advance()
        elseif table.containsStart(SMBLS, char) then
            local smbl = char
            local start, stop = pos:copy(), pos:copy()
            advance()
            while char and table.containsStart(SMBLS, smbl..char) do
                smbl = smbl .. char
                stop = pos:copy()
                advance()
            end
            table.insert(tokens, Token(T.smbl, smbl, PositionRange(start, stop)))
        elseif table.contains(string.letters, char) then
            local name = char
            local start, stop = pos:copy(), pos:copy()
            advance()
            while char and table.contains(string.letters, char) do
                name = name .. char
                stop = pos:copy()
                advance()
            end
            if table.contains(KW, name) then table.insert(tokens, Token(T.kw, name, PositionRange(start, stop)))
            elseif name == NULL then table.insert(tokens, Token(T.null, nil, PositionRange(start, stop)))
            elseif table.contains(BOOLS, name) then table.insert(tokens, Token(T.bool, name, PositionRange(start, stop)))
            elseif table.contains(TKW, name) then table.insert(tokens, Token(T.type, name, PositionRange(start, stop)))
            else table.insert(tokens, Token(T.name, name, PositionRange(start, stop))) end
        elseif table.contains(string.digits, char) or char == "." then
            local num = char
            local start, stop = pos:copy(), pos:copy()
            local dots = 0
            advance()
            while char and table.contains(string.digits, char) or char == "." do
                if char == "." then dots = dots + 1 end
                num = num .. char
                stop = pos:copy()
                advance()
            end
            if dots > 1 then return nil, Error("syntax error", "number can only have one dot", PositionRange(start, stop)) end
            table.insert(tokens, Token(T.num, tonumber(num), PositionRange(start, stop)))
        elseif char == STRDEF then
            local start, stop = pos:copy(), pos:copy()
            advance()
            local str = ""
            while char and char ~= STRDEF do
                if char == "\\" then
                    advance()
                    if char == "n" then str = str .. "\n"
                    elseif char == "t" then str = str .. "\t"
                    elseif char == "r" then str = str .. "\r"
                    else str = str .. char end
                else str = str .. char end
                advance()
            end
            stop = pos:copy()
            table.insert(tokens, Token(T.str, str, PositionRange(start, stop)))
            advance()
        else
            return nil, Error("char error", "unrecognized character '"..char.."'", PositionRange(pos:copy(),pos:copy()))
        end
    end
    table.insert(tokens, Token(T.eof, nil, PositionRange(pos:copy(), pos:copy())))
    return tokens
end

local function BinaryOpNode(opTok, leftNode, rightNode, pr)
    return setmetatable(
            { type = "binaryOp", opTok = opTok, leftNode = leftNode, rightNode = rightNode, pr = pr },
            { __name = "BinaryOpNode", __tostring = function(s)
                return "("..tostring(s.leftNode).." "..tostring(s.opTok.value).." "..tostring(s.rightNode)..")"
            end }
    )
end
local function UnaryOpNode(opTok, node, pr)
    return setmetatable(
            { type = "unaryOp", opTok = opTok, node = node, pr = pr },
            { __name = "UnaryOpNode", __tostring = function(s)
                return "("..tostring(s.opTok.value).." "..tostring(s.node)..")"
            end }
    )
end
local function NullNode(tok)
    return setmetatable(
            { type = "null", tok = tok, pr = tok.pr:copy() },
            { __name = "NullNode", __tostring = function(s)
                return "(null)"
            end }
    )
end
local function NumberNode(tok)
    return setmetatable(
            { type = "number", tok = tok, pr = tok.pr:copy() },
            { __name = "NumberNode", __tostring = function(s)
                return "("..tostring(s.tok.value)..")"
            end }
    )
end
local function StringNode(tok)
    return setmetatable(
            { type = "string", tok = tok, pr = tok.pr:copy() },
            { __name = "StringNode", __tostring = function(s)
                return '("'..tostring(s.tok.value)..'")'
            end }
    )
end
local function BoolNode(tok)
    return setmetatable(
            { type = "bool", tok = tok, pr = tok.pr:copy() },
            { __name = "BoolNode", __tostring = function(s)
                return "("..tostring(s.tok.value)..")"
            end }
    )
end
local function NameNode(tok)
    return setmetatable(
            { type = "name", tok = tok, pr = tok.pr:copy() },
            { __name = "NameNode", __tostring = function(s)
                return "("..tostring(s.tok.value)..")"
            end }
    )
end
local function TypeNode(tok)
    return setmetatable(
            { type = "type", tok = tok, pr = tok.pr:copy() },
            { __name = "TypeNode", __tostring = function(s)
                return "("..tostring(s.tok.value)..")"
            end }
    )
end
local function ArrayNode(nodes, pr)
    return setmetatable(
            { type = "array", nodes = nodes, pr = pr },
            { __name = "ArrayNode", __tostring = function(s)
                local str = "(["
                for _, n in pairs(s.nodes) do str = str..tostring(n)..", " end
                return str:sub(1,#str-2).."])"
            end }
    )
end
local function BodyNode(nodes)
    if #nodes == 0 then error("body nodes with length 0", 2) end
    return setmetatable(
            { type = "body", nodes = nodes, pr = PositionRange(nodes[1].pr.start:copy(),nodes[#nodes].pr.stop:copy()) },
            { __name = "BodyNode", __tostring = function(s)
                local str = "("
                for _, n in pairs(s.nodes) do str = str..tostring(n).."; " end
                return str..")"
            end }
    )
end
local function DoNode(node, pr)
    return setmetatable(
            { type = "do", node = node, pr = pr },
            { __name = "DoNode", __tostring = function(s)
                return "("..tostring(s.node).." !)"
            end }
    )
end
local function ReturnNode(node, pr)
    return setmetatable(
            { type = "return", node = node, pr = pr },
            { __name = "ReturnNode", __tostring = function(s)
                return "(return "..tostring(s.node)..")"
            end }
    )
end
local function MacroNode(nameNode, bodyNode, pr)
    return setmetatable(
            { type = "macro", nameNode = nameNode, bodyNode = bodyNode, pr = pr },
            { __name = "MacroNode", __tostring = function(s)
                return "(macro "..tostring(s.nameNode).." "..tostring(s.bodyNode)..")"
            end }
    )
end
local function WithNode(nameNode, bodyNode, pr)
    return setmetatable(
            { type = "with", nameNode = nameNode, bodyNode = bodyNode, pr = pr },
            { __name = "WithNode", __tostring = function(s)
                return "(with "..tostring(s.nameNode).." "..tostring(s.bodyNode)..")"
            end }
    )
end
local function IfNode(condNodes, bodyNodes, elseBodyNode, pr)
    return setmetatable(
            { type = "if", condNodes = condNodes, bodyNodes = bodyNodes, elseBodyNode = elseBodyNode, pr = pr },
            { __name = "IfNode", __tostring = function(s)
                return "(if "..tostring(#s.condNodes).." "..tostring(#s.bodyNodes).." "..tostring(s.elseBodyNode)..")"
            end }
    )
end
local function WhileNode(condNode, bodyNode, pr)
    return setmetatable(
            { type = "while", condNode = condNode, bodyNode = bodyNode, pr = pr },
            { __name = "WhileNode", __tostring = function(s)
                return "(while "..tostring(s.condNode).." "..tostring(s.bodyNode)..")"
            end }
    )
end
local function RepeatNode(countNode, bodyNode, pr)
    return setmetatable(
            { type = "repeat", countNode = countNode, bodyNode = bodyNode, pr = pr },
            { __name = "RepeatNode", __tostring = function(s)
                return "(repeat "..tostring(s.countNode).." "..tostring(s.bodyNode)..")"
            end }
    )
end
local function TupleNode(nodes, pr)
    return setmetatable(
            { type = "tuple", nodes = nodes, pr = pr },
            { __name = "TupleNode", __tostring = function(s)
                local str = "("
                for _, n in pairs(s.nodes) do str = str..tostring(n)..", " end
                return str:sub(1,#str-2)..")"
            end }
    )
end
local function parse(tokens)
    local idx, err, tok = 0
    local function update() tok = tokens[idx] end
    local function advance() idx = idx + 1 update() end
    advance()
    local function binOp(f1, ops, f2)
        if not f2 then f2 = f1 end
        local left, right
        local start = tok.pr.start:copy()
        left, err = f1() if err then return nil, err end
        while table.contains(ops, tok) do
            local opTok = tok:copy()
            advance()
            right, err = f2() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            left = BinaryOpNode(opTok, left, right, PositionRange(start, stop))
        end
        return left
    end
    local statements, statement, expr, assign, typeDef, tuple, logic, contains, comp, arith, term, factor, power,
    length, range, index, atom
    atom = function()
        local tok_ = tok:copy()
        if tok_.type == T.null then advance() return NullNode(tok_:copy()) end
        if tok_.type == T.name then advance() return NameNode(tok_:copy()) end
        if tok_.type == T.num then advance() return NumberNode(tok_:copy()) end
        if tok_.type == T.str then advance() return StringNode(tok_:copy()) end
        if tok_.type == T.bool then advance() return BoolNode(tok_:copy()) end
        if tok_.type == T.type then advance() return TypeNode(tok_:copy()) end
        if tok_ == Token(T.smbl, SMBLS.arrayIn) then
            local start = tok.pr.start:copy()
            advance()
            local tupleNode
            tupleNode, err = tuple() if err then return nil, err end
            if tok ~= Token(T.smbl, SMBLS.arrayOut) then return nil, Error("syntax error", "expected '"..SMBLS.arrayOut.."'", tok.pr:copy()) end
            local stop = tok.pr.stop:copy()
            advance()
            return ArrayNode(tupleNode.nodes, PositionRange(start, stop))
        end
        if tok_ == Token(T.smbl, SMBLS.evalIn) then
            advance()
            local eval
            eval, err = expr() if err then return nil, err end
            if tok ~= Token(T.smbl, SMBLS.evalOut) then return nil, Error("syntax error", "missing '"..SMBLS.evalOut.."'", tok.pos:copy()) end
            advance()
            return eval
        end
        local value = tok_.value or ""
        return nil, Error("value error", tok_.type.." ('"..tostring(value).."') not allowed to be atom", tok_.pr:copy())
    end
    index = function() return binOp(atom, { Token(T.smbl, SMBLS.index) }) end
    range = function() return binOp(index, { Token(T.smbl, SMBLS.range) }) end
    length = function()
        if tok == Token(T.kw, KW.len) then
            local start = tok.pr.start:copy()
            local opTok = tok:copy()
            advance()
            local node
            node, err = range() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            return UnaryOpNode(opTok, node, PositionRange(start, stop))
        else return range() end
    end
    power = function() return binOp(length, { Token(T.smbl, SMBLS.pow) }) end
    factor = function()
        if tok == Token(T.smbl, SMBLS.sub) then
            local start = tok.pr.start:copy()
            local opTok = tok:copy()
            advance()
            local node
            node, err = factor() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            return UnaryOpNode(opTok, node, PositionRange(start, stop))
        else return power() end
    end
    term = function() return binOp(factor, { Token(T.smbl, SMBLS.mul), Token(T.smbl, SMBLS.div),
                                                 Token(T.smbl, SMBLS.idiv), Token(T.smbl, SMBLS.mod) }) end
    arith = function() return binOp(term, { Token(T.smbl, SMBLS.add), Token(T.smbl, SMBLS.sub) }) end
    comp = function()
        if tok == Token(T.kw, KW.not_) then
            local start = tok.pr.start:copy()
            local opTok = tok:copy()
            advance()
            local node
            node, err = comp() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            return UnaryOpNode(opTok, node, PositionRange(start, stop))
        end
        return binOp(arith, { Token(T.smbl, SMBLS.eq), Token(T.smbl, SMBLS.ne),
                                                Token(T.smbl, SMBLS.lt), Token(T.smbl, SMBLS.gt),
                                                Token(T.smbl, SMBLS.le), Token(T.smbl, SMBLS.ge) }) end
    contains = function() return binOp(comp, { Token(T.kw, KW.contains) }) end
    logic = function() return binOp(contains, { Token(T.kw, KW.and_), Token(T.kw, KW.or_) }) end
    tuple = function()
        local node
        local start, stop = tok.pr.start:copy(), tok.pr.stop:copy()
        node, err = logic() if err then return nil, err end
        stop = node.pr.stop:copy()
        if tok == Token(T.smbl, SMBLS.sep) then
            local nodes = { node }
            while tok == Token(T.smbl, SMBLS.sep) do
                advance()
                node, err = logic() if err then return nil, err end
                stop = node.pr.stop:copy()
                table.insert(nodes, node)
            end
            return TupleNode(nodes, PositionRange(start, stop))
        end
        return node
    end
    typeDef = function() return binOp(tuple, { Token(T.kw, KW.typeDef) }) end
    assign = function() return binOp(typeDef, { Token(T.kw, KW.assign) }, assign) end
    expr = function()
        local node
        local start = tok.pr.start:copy()
        node, err = assign() if err then return nil, err end
        local stop = tok.pr.stop:copy()
        if tok == Token(T.smbl, SMBLS.do_) then advance() return DoNode(node, PositionRange(start, stop)) end
        return node
    end
    statement = function()
        if tok == Token(T.kw, KW.macro) then
            local start = tok.pr.start:copy()
            advance()
            local nameNode
            nameNode, err = index() if err then return nil, err end
            if tok.type == T.nl then
                local bodyNode
                bodyNode, err = statements({ Token(T.kw, KW.end_) }) if err then return nil, err end
                if tok ~= Token(T.kw, KW.end_) then return nil, Error("syntax error", "expected '"..KW.end_.."'", tok.pr:copy()) end
                advance()
                local stop = tok.pr.stop:copy()
                return MacroNode(nameNode, bodyNode, PositionRange(start, stop))
            end
            local node
            node, err = statement() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            return MacroNode(nameNode, node, PositionRange(start, stop))
        end
        if tok == Token(T.kw, KW.with) then
            local start = tok.pr.start:copy()
            advance()
            local nameNode
            nameNode, err = index() if err then return nil, err end
            if tok.type ~= T.nl then return nil, Error("syntax error", "expected "..T.nl, tok.pr:copy()) end
            advance()
            local bodyNode
            bodyNode, err = statements({ Token(T.kw, KW.end_) }) if err then return nil, err end
            if tok ~= Token(T.kw, KW.end_) then return nil, Error("syntax error", "expected '"..KW.end_.."'", tok.pr:copy()) end
            advance()
            local stop = tok.pr.stop:copy()
            return WithNode(nameNode, bodyNode, PositionRange(start, stop))
        end
        if tok == Token(T.kw, KW.while_) then
            local start = tok.pr.start:copy()
            advance()
            local condNode
            condNode, err = expr() if err then return nil, err end
            if tok.type == T.nl then
                local bodyNode
                advance()
                bodyNode, err = statements({ Token(T.kw, KW.end_) }) if err then return nil, err end
                if tok ~= Token(T.kw, KW.end_) then return nil, Error("syntax error", "expected '"..KW.end_.."'", tok.pr:copy()) end
                advance()
                local stop = tok.pr.stop:copy()
                return WhileNode(condNode, bodyNode, PositionRange(start, stop))
            end
            local node
            node, err = statement() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            return WhileNode(condNode, node, PositionRange(start, stop))
        end
        if tok == Token(T.kw, KW.repeat_) then
            local start = tok.pr.start:copy()
            advance()
            local countNode
            countNode, err = expr() if err then return nil, err end
            if tok.type == T.nl then
                local bodyNode
                advance()
                bodyNode, err = statements({ Token(T.kw, KW.end_) }) if err then return nil, err end
                if tok ~= Token(T.kw, KW.end_) then return nil, Error("syntax error", "expected '"..KW.end_.."'", tok.pr:copy()) end
                advance()
                local stop = tok.pr.stop:copy()
                return RepeatNode(countNode, bodyNode, PositionRange(start, stop))
            end
            local node
            node, err = statement() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            return RepeatNode(countNode, node, PositionRange(start, stop))
        end
        if tok == Token(T.kw, KW.if_) then
            local start = tok.pr.start:copy()
            local condNodes, bodyNodes, condNode, bodyNode, elseBodyNode = {}, {}
            advance()
            condNode, err = logic() if err then return nil, err end
            table.insert(condNodes, condNode)
            if tok.type == T.nl then
                advance()
                bodyNode, err = statements({ Token(T.kw, KW.end_), Token(T.kw, KW.else_), Token(T.kw, KW.elif_) }) if err then return nil, err end
                table.insert(bodyNodes, bodyNode)
                local stop = tok.pr.stop:copy()
                while tok == Token(T.kw, KW.elif_) do
                    advance()
                    condNode, err = logic() if err then return nil, err end
                    table.insert(condNodes, condNode)
                    if tok.type ~= T.nl then return nil, Error("syntax error", "expected "..T.nl, tok.pr:copy()) end
                    bodyNode, err = statements({ Token(T.kw, KW.end_), Token(T.kw, KW.else_), Token(T.kw, KW.elif_) }) if err then return nil, err end
                    table.insert(bodyNodes, bodyNode)
                end
                if tok == Token(T.kw, KW.else_) then
                    advance()
                    if tok.type ~= T.nl then return nil, Error("syntax error", "expected "..T.nl, tok.pr:copy()) end
                    advance()
                    elseBodyNode, err = statements({ Token(T.kw, KW.end_), Token(T.kw, KW.else_), Token(T.kw, KW.elif_) }) if err then return nil, err end
                end
                if tok ~= Token(T.kw, KW.end_) then return nil, Error("syntax error", "expected '"..KW.end_.."'", tok.pr:copy()) end
                stop = tok.pr.stop:copy()
                advance()
                return IfNode(condNodes, bodyNodes, elseBodyNode, PositionRange(start, stop))
            end
            return nil, Error("syntax error", "expected "..T.nl, tok.pr:copy())
        end
        if tok == Token(T.kw, KW.return_) then
            local start = tok.pr.start:copy()
            advance()
            local node
            node, err = expr() if err then return nil, err end
            local stop = tok.pr.stop:copy()
            return ReturnNode(node, PositionRange(start, stop))
        end
        return expr()
    end
    statements = function(stopTokens)
        if not stopTokens then stopTokens = { Token(T.eof) } end
        local errStr = ""
        for _, t in pairs(stopTokens) do
            if t.value then errStr=errStr.."'"..tostring(t.value).."'/" else errStr=errStr..tostring(t.type).."/" end
        end
        errStr=errStr:sub(1,#errStr-1)
        local body = {}
        while true do
            while tok.type == T.nl do advance() end
            if table.contains(stopTokens, tok) then break end
            local node
            if tok.type == T.eof and not table.contains(stopTokens, Token(T.eof)) then return nil, Error("syntax error", "expected "..errStr, tok.pr:copy()) end
            node, err = statement() if err then return nil, err end
            table.insert(body, node)
            if table.contains(stopTokens, tok) then break end
            if tok.type ~= T.nl then return nil, Error("syntax error", "expected "..T.nl, tok.pr:copy()) end
        end
        if #body > 0 then
            if #body == 1 then return body[1] end
            return BodyNode(body)
        end
        return
    end
    if tok.type == T.eof then return end
    local body
    body, err = statements() if err then return nil, err end
    return body
end

local Null, Number, Bool, String, Type, Array, Object, Macro, Function
Null = function()
    return setmetatable(
            { type = TKW.null, copy = function() return Null() end,
              asNumber = function(s) return Number(0) end,
              asString = function(s) return String(tostring(s)) end,
              asBoolean = function(s) return Bool(false) end,
              asType = function(s) return Type(s.type) end,
            },
            { __name = "Null", __tostring = function() return "null" end }
    )
end
Number = function(value)
    if value == nil then error("value for Number is nil", 2) end
    if math.floor(value) == value then value = math.floor(value) end
    return setmetatable(
            { type = TKW.num, value = value, copy = function(s) return Number(s.value) end,
              asNumber = function(s) return s:copy() end,
              asString = function(s) return String(tostring(s.value)) end,
              asBoolean = function(s) return Bool(s.value ~= 0) end,
              asType = function(s) return Type(s.type) end,
            },
            { __name = "Number", __tostring = function(s) return tostring(s.value) end }
    )
end
Bool = function(value)
    if value == nil then error("value for Bool is nil", 2) end
    return setmetatable(
            { type = TKW.bool, value = value, copy = function(s) return Bool(s.value) end,
              asNumber = function(s) if s.value then return Number(1) else return Number(0) end end,
              asString = function(s) return String(tostring(s.value)) end,
              asBoolean = function(s) return s:copy() end,
              asType = function(s) return Type(s.type) end,
            },
            { __name = "Number", __tostring = function(s) return tostring(s.value) end }
    )
end
String = function(value)
    if value == nil then error("value for String is nil", 2) end
    return setmetatable(
            { type = TKW.str, value = value, copy = function(s) return String(s.value) end,
              asString = function(s) return String(tostring(s.value)) end,
              asType = function(s) return Type(s.type) end,
            },
            { __name = "String", __tostring = function(s) return s.value end }
    )
end
Type = function(value)
    if value == nil then error("value for Type is nil", 2) end
    return setmetatable(
            { type = TKW.type, value = value, copy = function(s) return Type(s.value) end,
              asString = function(s) return String(tostring(s.value)) end,
              asType = function(s) return s:copy() end,
            },
            { __name = "Type", __tostring = function(s) return tostring(s.value) end }
    )
end
Array = function(values)
    if values == nil then error("values for Array is nil", 2) end
    return setmetatable(
            { type = TKW.array, values = values, copy = function(s)
                local valuesCopy = {}
                for i, v in ipairs(s.values) do
                    valuesCopy[i] = v:copy()
                end
                return Array(valuesCopy)
            end,
              asString = function(s) return String(tostring(s)) end,
              asType = function(s) return s.type end,
            },
            { __name = "Array", __tostring = function(s)
                local str = "["
                for _,v in pairs(s.values) do
                    str = str..tostring(v)..", "
                end
                return str:sub(1,#str-2).."]"
            end }
    )
end
Object = function(object) todo() end
Macro = function(bodyNode) todo() end
Function = function(varTupleNode, bodyNode) todo() end
local function Variable(name, ptr, type)
    return setmetatable(
            { name = name, ptr = ptr, type = type, copy = function(s) return Variable(s.name, s.ptr) end },
            { __name = "Variable", __tostring = function(s) return "<"..s.name..", "..tostring(s.ptr)..", "..tostring(s.type)..">" end }
    )
end
local function Context(vars, memory)
    return setmetatable(
            { vars = vars, memory = memory, copy = function(s)
                local varsCopy = {}
                for _, v in ipairs(s.vars) do
                    table.insert(varsCopy, v:copy())
                end
                local memoryCopy = {}
                for _, v in ipairs(s.memory) do
                    table.insert(memoryCopy, v:copy())
                end
                return Context(varsCopy, memoryCopy)
            end,
              getVar = function(s, name)
                  for _, v in pairs(s.vars) do
                      if v.name == name then return v end
                  end
              end,
              get = function(s, name)
                  for _, v in pairs(s.vars) do
                      if v.name == name then return s.memory[v.ptr] end
                  end
              end,
              new = function(s, name, value, type)
                  table.insert(s.memory, value)
                  table.insert(s.vars, Variable(name, #s.memory, type))
                  return s.vars[#s.vars]
              end,
            },
            { __name = "Context" }
    )
end
local function interpret(ast, globalContext)
    if not globalContext then globalContext = Context({}, {}) end
    if not ast then return nil, globalContext end
    local visit = setmetatable( {
        notImplemented = function(_, node, context)
            return nil, context, false, Error("not implemented", "node '"..node.type.."' can't be interpreted", node.pr)
        end,
        getPtr = function(_, node, context)
            if node.type == "name" then
                local variabel = context:getVar(node.tok.value)
                return variabel, context
            end
            return nil, context, false, Error("assign error", "cannot assign "..node.leftNode.type.." to a value, only names", node.leftNode.pr)
        end,
        binaryOp = function(visit, node, context)
            local op = node.opTok.value
            if op == KW.assign then
                local right, err, returning
                right, context, returning, err = visit[node.rightNode.type](visit, node.rightNode, context) if err then return nil, context, false, err end
                local nameNode, type_ = node.leftNode
                if nameNode.type == "binaryOp" then
                    if nameNode.opTok == Token(T.kw, KW.typeDef) then
                        type_, context, returning, err = visit[nameNode.rightNode.type](visit, nameNode.rightNode, context) if err then return nil, context, false, err end
                        if type_.type ~= TKW.type then return nil, context, false, Error("assign error", "expected type for type definition but got "..type_.type, nameNode.rightNode.pr) end
                        nameNode = nameNode.leftNode
                        if type_.value ~= right.type then return nil, context, false, Error("assign error", "type of value doesn't match type definition", node.rightNode.pr) end
                    end
                end
                local variabel
                variabel, context, returning, err = visit:getPtr(nameNode, context) if err then return nil, context, false, err end
                if not variabel then variabel = context:new(nameNode.tok.value, right, type_) end
                if variabel.type then if variabel.type.value ~= right.type then
                    return nil, context, false, Error("assign error", "type of value doesn't match type of the variable of '"..variabel.name.."'", node.rightNode.pr)
                end end
                context.memory[variabel.ptr] = right
                return right, context
            end
            local left, right, err, returning
            left, context, returning, err = visit[node.leftNode.type](visit, node.leftNode, context) if err then return nil, context, false, err end
            right, context, returning, err = visit[node.rightNode.type](visit, node.rightNode, context) if err then return nil, context, false, err end
            if op == SMBLS.add then
                if left.type == TKW.num and right.type == TKW.num then return Number(left.value + right.value), context end
            end
            if op == SMBLS.sub then
                if left.type == TKW.num and right.type == TKW.num then return Number(left.value - right.value), context end
            end
            if op == SMBLS.mul then
                if left.type == TKW.num and right.type == TKW.num then return Number(left.value * right.value), context end
            end
            if op == SMBLS.div then
                if left.type == TKW.num and right.type == TKW.num then return Number(left.value / right.value), context end
            end
            if op == SMBLS.idiv then
                if left.type == TKW.num and right.type == TKW.num then return Number(left.value // right.value), context end
            end
            if op == SMBLS.pow then
                if left.type == TKW.num and right.type == TKW.num then return Number(left.value ^ right.value), context end
            end
            if op == SMBLS.mod then
                if left.type == TKW.num and right.type == TKW.num then return Number(left.value % right.value), context end
            end
            if op == SMBLS.eq then
                return Bool(left.value == right.value), context
            end
            if op == SMBLS.ne then
                return Bool(left.value ~= right.value), context
            end
            if op == SMBLS.lt then
                if left.type == TKW.num and right.type == TKW.num then return Bool(left.value < right.value), context end
            end
            if op == SMBLS.gt then
                if left.type == TKW.num and right.type == TKW.num then return Bool(left.value > right.value), context end
            end
            if op == SMBLS.le then
                if left.type == TKW.num and right.type == TKW.num then return Bool(left.value <= right.value), context end
            end
            if op == SMBLS.ge then
                if left.type == TKW.num and right.type == TKW.num then return Bool(left.value >= right.value), context end
            end
            if op == SMBLS.range then
                if left.type == TKW.num and right.type == TKW.num then
                    local values = {}
                    for i = left.value, right.value do
                        table.insert(values, Number(i))
                    end
                    return Array(values), context
                end
            end
            if op == KW.typeDef then
                if right.type == TKW.type then
                    if right.value == TKW.num and left.asNumber then
                        local value
                        value, err = left:asNumber() if err then return nil, context, false, err end
                        return value, context
                    end
                    if right.value == TKW.str and left.asString then
                        local value
                        value, err = left:asString() if err then return nil, context, false, err end
                        return value, context
                    end
                    if right.value == TKW.bool and left.asBoolean then
                        local value
                        value, err = left:asBoolean() if err then return nil, context, false, err end
                        return value, context
                    end
                    if right.value == TKW.type and left.asType then
                        local value
                        value, err = left:asType() if err then return nil, context, false, err end
                        return value, context
                    end
                end
            end
            return nil, context, false, Error("operation error", "cannot do binary operation '"..op.."' with "..left.type.." and "..right.type, node.pr)
        end,
        unaryOp = function(visit, node, context)
            local op = node.opTok.value
            local value, err, returning
            value, context, returning, err = visit[node.node.type](visit, node.node, context) if err then return nil, context, false, err end
            if op == KW.len then
                if value.type == TKW.array then return Number(#value.value), context end
            end
            if op == KW.not_ then
                if value.type == TKW.bool then return Bool(not value.value), context end
            end
            if op == SMBLS.sub then
                if value.type == TKW.num then return Number(-value.value), context end
            end
            return nil, context, false, Error("operation error", "cannot do unary operation '"..op.."' with "..value.type, node.pr)
        end,
        body = function(visit, node, context, keepVars)
            local oldcontext = context:copy()
            for _, n in pairs(node.nodes) do
                local value, returning, err
                value, context, returning, err = visit[n.type](visit, n, context) if err then return nil, context, false, err end
                if returning then return value, context, returning end
            end
            for k, v in pairs(oldcontext.memory) do oldcontext.memory[k] = context.memory[k]:copy() end
            for k, v in pairs(oldcontext.vars) do oldcontext.vars[k] = context.vars[k]:copy() end
            if keepVars then return Null(), context
            else return Null(), oldcontext end
        end,
        null = function(_, _, context) return Null(), context end,
        number = function(_, node, context) return Number(node.tok.value), context end,
        bool = function(_, node, context) return Bool(node.tok.value), context end,
        string = function(_, node, context) return String(node.tok.value), context end,
        name = function(_, node, context)
            local value = context:get(node.tok.value)
            if not value then return nil, context, false, Error("name error", "name '"..node.tok.value.."' not registered", node.pr:copy()) end
            return value, context
        end,
        type = function(_, node, context) return Type(node.tok.value), context end,
        array = function(visit, node, context)
            local values, value, returning, err = {}
            for _, n in ipairs(node.nodes) do
                value, context, returning, err = visit[n.type](visit, n, context) if err then return nil, context, false, err end
                if value then table.insert(values, value) end
            end
            return Array(values), context
        end,
        ["return"] = function(visit, node, context)
            local value, err
            value, context, _, err = visit[node.node.type](visit, node.node, context) if err then return nil, context, false, err end
            return value, context, 1
        end,
    }, { __name = "Interpreter", __index = function(s, k)
                if table.containsKey(s, k) then
                    for node, f in pairs(s) do if node == k then return f end end
                else return s.notImplemented end
            end })
    return visit[ast.type](visit, ast, globalContext, true)
end

local function debugContext(context)
    print("--DEBUG--")
    print("variables: ")
    for _, v in ipairs(context.vars) do print("",tostring(v)) end
    print("memory: ")
    for i, v in ipairs(context.memory) do print("",i,tostring(v)) end
end
local function test()
    local tokens, ast, value, context, returning, err
    local file = io.open("test.l", "r")
    tokens, err = lex("test.l", file:read("*a")) if err then print(err) return end
    file:close()
    --for _,t in pairs(tokens) do io.write(tostring(t)," ") end print("")
    ast, err = parse(tokens) if err then print(err) return end
    --if ast ~= nil then print(tostring(ast)) end
    value, context, returning, err = interpret(ast) if err then print(err) debugContext(context) return end
    if value then print(value) end
    debugContext(context)
end
local function run(fn)
    local file = io.open(fn, "r")
    local ftext = file:read("*a") file:close()
    local tokens, ast, value, context, returning, err
    tokens, err = lex(fn, ftext) if err then print(err) return end
    ast, err = parse(tokens) if err then print(err) return end
    value, context, returning, err = interpret(ast) if err then print(err) return end
    return value
end
local function execute(text, context)
    local tokens, ast, value, returning, err
    tokens, err = lex("<execute>", text) if err then return nil, nil, false, err  end
    ast, err = parse(tokens) if err then return nil, nil, false, err end
    value, context, returning, err = interpret(ast) if err then return nil, context, false, err end
    return value, context, returning
end
return { run = run, test = test, execute = execute }