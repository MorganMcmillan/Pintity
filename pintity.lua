-- TODO: optimize code size for Pico-8 syntax

--- Type definitions:
--- @class Entity integer an increasing id
--- @class Component integer a singular bit identifying a component
--- @class ComponentSet integer bitset of components
--- @alias System fun(entities: Entity[], ...: any[]) -> bool
--- @alias Query { terms: Component[], bits: integer, [integer]: any[] }
--- @alias Archetype { Component: any[], entities: integer[] }
--- @class Prefab { { Component: any }, Archetype, ComponentSet }

---@type { Entity: ComponentSet }
entities = {}
---@type { Entity: integer }
entity_rows = {}

arch0 = {entities = {}}
--- @type { ComponentSet: Archetype }
archetypes = {[0] = arch0}

--- @type { [integer]: Archetype }
--- New archetypes created this frame
--- Prevents system queries from adding archetypes twice by setting it to all archetypes this frame
new_archetypes = archetypes

--- @type Component
--- The current component ID\
--- Pico-8 uses 32-bit fixed point numbers, so `1` is actually bit 16
component_bit = 1 >> 16

--- @type System[]
--- Systems to be run each frame
systems = {}

--- @type Query[]
--- Queried components to use with each system\
--- Empty queries represent tasks
queries = {}

---Creates a new entity
---@return Entity
function entity()
    -- NOTE: entities could be recycled by using the empty (0) archetype
    add(entities, 0)
    add(arch0.entities, #entities)
    add(entity_rows, #arch0.entities)
    return #entities
end

---Creates a new component identifier.\
---Note: Pintity can only handle creating up to 32 components.
---@return Component component
function component()
    local b = component_bit
    assert(b ~= 0, "Error: component limit reached. Applications can only have up to 32 components.")
    component_bit <<= 1
    return b
end

function has(entity, component)
    return entities[entity] & component == component
end

-- Note: an entity is not considered alive until it has at least one component
function alive(entity)
    return entities[entity] ~= 0
end

function get_type(entity)
    return archetypes[entities[entity]]
end

function get(entity, component)
    return get_type(entity)[component][entity_rows[entity]]
end

function last(t) return t[#t] end

function swap_remove(t, i)
    local val = t[i]
    t[i], t[#t] = last(t) --, nil
    return val
end

function move_archetype(entity, old, new, exclude, include)
    local row = entity_rows[entity]
    entity_rows[last(old.entities)] = row
    if new then
        for bit, col in next, old do
            add(new[bit], swap_remove(col, row))
        end
    else
        new = {}
        for bit, col in next, old do
            new[bit] = {swap_remove(col, row)}
        end

        -- `remove`: Remove falsely added component
        new[exclude] = nil
        -- `set`: Ensures the newly set component is included in the archetype
        if include then new[include] = {} end

        archetypes[entities[entity]] = new
        new_archetypes[entities[entity]] = new
    end
    entity_rows[entity] = #new.entities
end

---Sets the value of an entity's component.\
---Important: a component must not be set to nil, unless it is known to be a tag without any preexisting data.
---@param entity Entity
---@param component Component
---@param value? any or nil if `component` is a tag
function set(entity, component, value)
    local arch, has_value = get_type(entity), value ~= nil
    if not has(entity, component) then
        entities[entity] |= component
        move_archetype(entity, arch, get_type(entity), 0, has_value and component)
        arch = get_type(entity)
    end
    if has_value then
        arch[component][entity_rows[entity]] = value
    end
end

---Removes a component from an entity
---@param entity Entity
---@param component Component
function remove(entity, component)
    if not has(entity, component) then return end
    local old_arch = get_type(entity)
    -- Xor remove the entity
    entities[entity] ^^= component
    move_archetype(entity, old_arch, get_type(entity), component)
end

---Replaces one component with another.\
---This is functionally equivalent to calling `remove` followed by `set`, but saves an archetype move.\
---@param entity Entity
---@param component Component the component to replace
---@param with Component the component that's replacing the other one
---@param value? any the value to replace with. If nil, replaces `with` with the value of `component`.
function replace(entity, component, with, value)
    local bitset = entities[entity]
    if bitset & component == 0 then return set(entity, with, value) end
    value = value or get(entity, component)
    -- Xor remove
    bitset ^^= component
    bitset |= with
    move_archetype(entity, get_type(entity), archetypes[bitset], component)
    entities[entity] = bitset
    archetypes[bitset][component][entity_rows[entity]] = value
end

---Delete the entity and all its components.
---@param entity Entity
function delete(entity)
    move_archetype(entity, get_type(entity), arch0, 0)
    entities[entity] = 0
end

---Performs a shallow copy of a table or other value
---@param value any
function copy(value)
    if type(value) ~= "table" then return value end
    local copied = {}
    for k, v in next, value do
        copied[k] = v
    end
    return copied
end

---Creates a new prefab. Call `instantiate` on it to spawn a new entity.\
---Example: `enemy = prefab(Position, {5, 10}, Sprite, 1, Target, player, Enemy, nil)`
---@param ... Component|any components and values, or `nil` values for tags
---@return Prefab prefab
function prefab(...)
    local components, bits = {}, 0
    for i = 1, select("#", ...), 2 do
        local component, value = select(i, ...), select(i + 1, ...)
        bits |= component
        -- Tags are ignored as `add(table, nil)` has the same behavior as `add(nil, value)`.
        components[component] = copy(value)
    end

    -- Premake archetype if needed.
    local archetype = archetypes[bits]
    if not archetype then
        archetype = { entities = {} }
        for component in next, components do
            archetype[component] = {}
        end
    archetypes[bits] = archetype
    end

    return { components, archetype, bits }
end

---Instantiates a new entity from a prefab created by `prefab`.
---@param prefab Prefab
---@return Entity instance
function instantiate(prefab)
    local archetype = prefab[2]
    for component, value in next, prefab[1] do
        add(archetype[component], value)
    end
    add(entities, prefab[3])
    add(archetype.entities, #entities)
    add(entity_rows, #archetype.entities)
    return #entities
end

---Queries match entities with specific components.
---@param terms Component[] the list of components to be queried
---@return Archetype[] query Every archetype matched with the query
function query(terms)
    local filter = 0
    for term in all(terms) do filter |= term end
    local results = { terms = terms, bits = filter }
    update_query(results, archetypes)
    return results
end

---Updates the contents of the query to represent the current state of the ECS.
---@param query Query
---@param tables Archetype[]
function update_query(query, tables)
    if not query.terms then return end
    for bits, components in next, tables or new_archetypes do
        if bits & query.bits == query.bits then
            local fields = { components.entities }
            for term in all(query.terms) do
                add(fields, components[term])
            end
            add(query, fields)
        end
    end
end

--- Create and add a new system.\
--- Systems are run once per frame, and in the order they are created.\
--- If a system needs to stop iteration, return `true`.\
--- Important: if a system needs to delete entities or add new components, it should iterate **in reverse** to prevent entities from being skipped.
---@param terms Component[]
---@param callback System
function system(terms, callback)
    add(queries, terms and query(terms) or {{}}) -- Empty table to ensure iteration
    add(systems, callback)
end

---Progress the ECS each frame. Should be called in `_update`
function progress()
    if new_archetypes ~= archetypes and #new_archetypes > 0 then
        foreach(queries, update_query)
        -- The archetypes are no longer new this frame
        new_archetypes = {}
    end
    for i, query in inext, queries do
        -- Note: empty tables are never deleted, so we don't exclude them from our queries
        for cols in all(query) do
            -- Skip system if it returns true
            if systems[i](unpack(cols)) then break end
        end
    end
end