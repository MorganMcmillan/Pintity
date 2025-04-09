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

---@class Phase { [integer]: Query, systems: System[] }

phases = {}

---Creates a new phase. Systems can be added to phases.\
---All phases are updated using `update_phases` in `_update` before `progress` is called.
---Phases are run using `progress`.
---@return Phase
local function phase()
    return add(phases, { systems = {} })
end

---Updates all created phases. Must be called in `_update` before `progress` is called
function update_phases()
    if next(query_cache) then
        for phase in all(phases) do
            foreach(phase, update_query)
        end
    end
end

local function system(phase, terms, exclude, callback)
    add(phase, terms and query(terms, callback and exclude) or {{0}}) -- Empty table to ensure iteration
    return add(phase.systems, callback or exclude)
end

---Progress the ECS each frame. Should be called in `_update`
---@param phase Phase
function progress(phase)
    for i, query in inext, phase do
        local system = phase.systems[i]
        for cols in all(query) do
            -- Note: empty tables are never deleted, so they aren't removed from queries
            -- Skip empty archetypes
            if #cols[1] ~= 0 then
                -- Skip system if it returns true
                if system(unpack(cols)) then break end
            end
        end
    end
end