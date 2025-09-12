-- Parsers Subsection
-- These are combinators used to parse query terms
local function char(input, c)
    if input[1] == c then return sub(input, 2), c end
end

local function evaluate_wildcard(archetype, relationship, is_relationship)
    local wildcard = {}
    if is_relationship then
        for component in kpairs(archetype) do
            if relationships[component] then
                add(wildcard, component)
            end
        end
    elseif relationship then
        for target in kpairs(relationship) do
            add(wildcard, target)
        end
    else
        for component in kpairs(archetype) do
            if components[component] then
                add(wildcard, component)
            end
        end
    end
    return wildcard
end    

local function parse_component(input)
    -- Try wildcard
    if char(input, '*') then
        return function (arch, relationship, is_relationship)
            
        end
    end
    -- Parse variable
    local name, is_var = char(input, '@')
    input = name or input

    -- Parse identifier
    local i = 1
    local c = ord(input)
    -- C is between 'a' and 'z' or c is an underscore
    while c >= 97 and c <= 122 or c == 95 do
        i += 1
        c = ord(input, i)
    end

    input, name = sub(input, i + 1), sub(input, 1, i)
    -- TODO: figure out how component evaluation functions are going to be composed
    return is_var and
    function (arch, relationship, is_relationship)
        
    end or
    function (arch, relationship, is_relationship)
        
    end
end

--- Parses a component or pair with an optional source
local function parse_component_w_source(input)
    local input, component = parse_component(input)
    input = char(input, '(')
    if not input then return component end
    local source, target = upack(split(input, ':'))
    
end

local function parse_pair(input)
    input = char(input, '(')
    if input then
        local relationship, target = unpack(split(input, ':'))
        relationship, target = parse_component(relationship), parse_component(target)
        return function (archetype)
            -- Relationship is used to match all relationships on the archetype
            -- Target is used to match all targets in the relationship
            relationship(archetype, nil, target)
        end
    end
end

local function parse_term(input)
    return parse_pair(input) or
    parse_component_w_source(input)
end