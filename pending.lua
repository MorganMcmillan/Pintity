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