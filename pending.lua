---Clones an entity.
---@return Entity
function clone(entity)
    local clone = {}
    for k, v in next, entity do
        clone[k] = v
    end
    add(entity.archetype, clone).row = #entity.archetype
    return setmetatable(clone, pint_mt)
end

---Garbage collects all empty archetypes created this frame.
---Recently empty tables are ignored because they are likely to be filled again,
---and removing tables from cached queries would be a pain.
---This must be called before `update_phases` is called in `_update`
function clean_tables()
    for bits, archetype in next, query_cache do
        if #archetype == 0 then
            query_cache[bits], archetypes[bits] = nil
        end
    end
end

---Deletes every entity matching a query
---@param query Query
function delete_queried(query)
    for i = 1, #query do
        query[i] = {}
    end
end

---Creates a new entity.
---@param t { [string]: any } A table of component-value pairs
---@return Entity
function entity(t)
    local entity, bits = t or {}, 0
    for k in next, t do
        bits |= components[k] or 0
    end
    t = archetypes[bits]
    entity.archetype, entity.components, entity.row = t, bits, #t + 1
    return setmetatable(
        add(t, entity),
        pint_mt
    )
end
