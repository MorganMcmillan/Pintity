#include parens8.lua

-- Query parser pseudocode
-- Currently only constructs an AST

function parse(query)
    local terms = split(query)
    local output = {}
    for i, term in inext, terms do
        output[i] = parse_term(term)
    end
    return output
end

local parsers = {}

function parse_term(term)
    local parser = parsers[term[1]]
    if parser then
        return parser(sub(term, 2))
    else
        return { type = "plain", value = term }
    end
end

parsers["*"] = function () return { type = "wildcard" } end

parsers["("] = function (term)
    local pair = split(term, ":")
    return { type = "pair", first = parse_term(pair[1]), second = parse_term(sub(pair[2], 1, -2)) }
end

parsers["!"] = function (term)
    return { type = "not", value = term }
end

parsers["?"] = function (term)
    return { type = "optional", value = parse_term(term) }
end

parsers["@"] = function (term)
    return { type = "variable", value = term }
end

-- Debug function for tables
function print_table(t)
    print(t)
    for _, v in inext, t do
        print(v.type)
        print(v.value or v.first.type)
    end
end

print_table(parse("@var,!foo,bar,(*:target)"))