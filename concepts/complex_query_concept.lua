-- This is a concept for more complex queries. This likely won't be needed for any Pico-8 game, but can be emulated within systems.

--- Returns query terms as a parsed list of expressions
local function parse_terms(terms)
    local query = {}
    for i, term in inext, split(terms) do
        local operator, rest = term[1], split(sub(term, 2), '|')
        if operator == '!' then
            query[i] = { operator = term_not, term = rest}
        elseif operator == '?' then
            query[i] = { operator = term_optional, term = rest }
        elseif operator == '@' then
            query = { operator = term_variable, term = {sub(term, 2)} }
        else
            query[i] = { operator = term_identity, term = split(term, '|') }
        end
    end
end

--- Like the old query function, except this version uses a proper syntax:
--- Normal term: "name" a plain component name
--- Exlcuded term: "!name"
--- Optional term: "?name" normally would be a no-op, but I'm thinking of adding query information to systems
--- Or terms: "foo|bar|baz" these form a group of components that can either match. Technically every term is an or term with just one component in the group
--- Pair term: "(likes:apples)" based on Flecs' relationships. Uses ':' instead of ',' because of `split`
--- Variable: "@var" creates a new query variable who's value is the component it matches on.
--- Variables are used to restrict the set of results a wildcard returns, so "(likes:@var),(eats:@var)" returns only the strict subset of things this entity both likes and eats
--- Equality: "@var==foo|bar|baz"
--- Negated equality: "@var!=foo|bar|baz"
local function query(terms)
    update_query({terms = parse_terms(terms)}, archetypes)
end

--- Tests whether or not a query matches a specific archetype.
---@param query Query
---@param archetype Archetype
---@return boolean match if the query matches.
local function query_matches_archetype(query, archetype)
    for term in all(query.terms) do
        for or_term in all(term.term) do
            if not term.operator(or_term) then return false end
        end
    end
    return true
end
