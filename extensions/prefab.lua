-- Prefab: easily spawn entities with multiple components

--- @alias Prefab { bits: ComponentSet, [string]: any }

---Creates a new prefab. A prefab is a template for an entity, like a blueprint.\
---Entities can be created from these using instantiate
---@param t { [string]: any }
---@return any
function prefab(t)
    local bits, new = 0, {}
    for k in next, t do
        local bit = components[k]
        if bit then
            bits |= bit
        end
    end
    if not archetypes[bits] then
        archetypes[bits], query_cache[bits] = new, new
    end
    t.components, t.archetype = bits, archetypes[bits]
    return t
end

---Instantiates a new entity from a prefab created by `prefab`.\
---Note: this does not recycle entities.
---@param prefab Prefab
---@return Entity instance
function instantiate(prefab)
    local e = {}
    -- Copy the prefab's components into the entity instance
    for k, v in next, prefab do
        e[k] = v
    end

    add(e.archetype, e).row = #e.archetype
    return setmetatable(e, pint_mt)
end