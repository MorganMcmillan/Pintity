-- This is a concept for more complex queries. This likely won't be needed for any Pico-8 game, but can be emulated within systems.

function complex_query(terms, excludeTerms, optionalTerms, orTerms)
    local results = {}
    local termBits = orAll(terms)
    if orTerms then
        for orTerm in all(orTerms) do
            for term in all(orTerm) do
                termBits |= term
            end
        end
    end

    excludeTerms = orAll(excludeTerms)
    for bitset, archetype in next, archetypes do
        if bitset & termBits ~= 0 and bitset & excludeTerms == 0 then
            local fields = {}
            for term in all(terms) do
                add(fields, archetype[term])
            end
            if optionalTerms then
                for term in all(optionalTerms) do
                    add(fields, archetype[term] or false) 
                end
            end
            if orTerms then
                for orTerm in all(orTerms) do
                    for term in all(orTerm) do
                        col = archetype[term]
                        if col then add(fields, col) end
                        break 
                    end
                end
            end
            add(results, fields)
        end
    end
    return results
end