-- old: 132
-- new: 100 (-32)

---Creates a new entity
---@return Entity
function entity()
    -- Recycle unused entities
    return last(arch0.entities) or setmetatable(
        add(arch0.entities, { archetype = arch0, components = 0, row = 1 }),
        pint_mt
    )
end

---Creates a new prefab. Call `instantiate` on it to spawn a new entity.\
---Example: `enemy = prefab(Position, {5, 10}, Sprite, 1, Target, player, Enemy, nil)`
---@param ... Component|any components and values, or `nil` values for tags
---@return Prefab prefab
local function prefab(...)
    local components, args = { bits = 0 }, {...}
    for i = 1, #args, 2 do
        local component = args[i]
        components.bits |= component
        -- Tags are ignored as `add(table, nil)` has the same behavior as `add(nil, value)`.
        components[component] = copy(args[i+1])
    end
    return components
end
    
---Instantiates a new entity from a prefab created by `prefab`.
---@param prefab Prefab
---@return Entity instance
function instantiate(prefab)
    local e = entity()
    -- Saves several archetype moves
    local new = e:set(prefabs.bits).archetype
    for bit, value in next, prefab do
        add(new[bit], value)
    end
    return e
end