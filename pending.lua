---Progress the ECS each frame. Should be called in `_update`
function progress_each()
    if next(query_cache) then
        foreach(queries, update_query)
        -- The archetypes are no longer new this frame
        query_cache = {}
    end
    for i, system in inext, systems do
        for cols in all(queries[i]) do
            -- Note: empty tables are never deleted, so they aren't removed from queries
            -- Skip empty archetypes
            for j = #cols[1], 1, -1 do
                local values = {}
                for k = 1, #cols do
                    values[k] = cols[k][j]
                end
                system(unpack(values))
            end
        end
    end
end