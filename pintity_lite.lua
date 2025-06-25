-- Pintity_lite: an even simpler ECS for Pico-8
-- By Morgan.

-- This version removes a lot of features and safety checks that the full version has.

-- 341 tokens compressed

--- Type definitions:
--- @class Entity { components: ComponentSet, archetype: Archetype, row: integer } An object containing arbitrary data
--- @alias Component integer a singular bit identifying a component
--- @class ComponentSet integer bitset of components
--- @alias System fun(entities: Entity[], ...: any[]) -> skip?: boolean
--- @alias Query { terms: Component[], bits: ComponentSet, exclude: ComponentSet, [integer]: any[] }
--- @alias Archetype Entity[]
--- @class Prefab { [string]: any }

--- @type Archetype
--- The archetype containing no components. Used for recycling.
arch0 = {}

--- @type { ComponentSet: Archetype }
archetypes = {[0] = arch0}

--- @type { ComponentSet: Archetype }
--- New archetypes created this frame to update queries by.\
--- Prevents system queries from adding archetypes twice.
query_cache = {}

--- @type Component
--- The current component ID\
--- Pico-8 uses 32-bit fixed point numbers, so `1` is actually bit 16
component_bit = 1

--- @type { string: Component }
components = {}

--- @type System[]
systems = {}

--- @type Query[]
queries = {}

pint_mt = {}

-- Used to add a new component
function pint_mt:__newindex(name, value)
    local bit = components[name]
    if bit then
        self.components |= bit
        update_archetype(self)
    end
    rawset(self, name, value)
end

-- Used to delete a value from an entity. This may look strange, but it actually saves 2 tokens.
-- If name is not given, then the entity is deleted.
function pint_mt:__call(name)
    -- Note: component data is not actually removed, but it should never be accessed.
    if name then
        -- Remove just one component
        self.components ^^= components[name]
    else
        -- Remove all components.
        self.components = 0
    end
    update_archetype(self)
end

---Creates a new entity.\
---Entities with no components may be recycled, so this should never be called twice before adding a component.
---@return Entity
function entity()
    -- Recycle unused entities
    return last(arch0) or setmetatable(
        -- Row is known to be 1, as arch0 is empty
        add(arch0, { archetype = arch0, components = 0, row = 1 }),
        pint_mt
    )
end

-- Returns the last item of the table
function last(t) return t[#t] end

-- Removes the item at i and swaps its value with the last value
function swap_remove(t, i)
    i, t[i] = t[i], last(t)
    deli(t)
    return i
end

---Changes the archetype of an entity.
function update_archetype(entity)
    local components = entity.components
    local row, old, new = entity.row, entity.archetype, archetypes[components]
    -- Invariant if the last entity is this one
    last(old).row = row
    if new then
        -- Move entity from old archetype to new
        add(new, swap_remove(old, row))
    else
        -- Create new archetype from old's entity and add it
        new = {swap_remove(old, row)}

        archetypes[components], query_cache[components] = new, new
    end
    entity.archetype = new
    entity.row = #new
end

---Creates a new component identifier.\
---Note: Pintity can only handle creating up to 32 components.
---@param name string the name of the component
local function component(name)
    components[name] = component_bit
    component_bit <<>= 1
end

---Queries match entities with specific components.
---@param terms string A comma separated string of component names
---@return Archetype[] query Every archetype matched with the query
local function query(terms)
    local filter = 0
    for term in all(split(terms)) do filter |= components[term] end

    local results = { bits = filter }

    update_query(results, archetypes)
    return results
end

--- Updates the contents of the query to represent the current state of the ECS.\
--- Adds new archetypes after they are created
---@param query Query
---@param tables Archetype[]
function update_query(query, tables)
    for bits, archetype in next, tables or query_cache do
        if bits & query.bits == query.bits then
            add(query, archetype)
        end
    end
end

--- Create and add a new system.\
--- Systems are run once per frame, and in the order they are created.\
--- If a system needs to stop iteration, return `true`.\
--- Important: if a system needs to delete entities or add new components, it should iterate **in reverse** to prevent entities from being skipped.
---@param phase Phase the phase to run this system on
---@param terms string
---@param callback System
---@return Archetype[] query
local function system(phase, terms, callback)
    add(systems, callback)
    return add(queries, query(terms, callback))
end

---Instantiates a new entity from a simple table containing key-value pairs.
---@param prefab Prefab
---@return Entity instance
function instantiate(prefab)
    local e = entity()
    -- Copy the prefab's components into the entity instance
    for k, v in next, prefab do
        e[k] = v
    end
    return e
end

---Runs all systems
function progress()
    foreach(queries, update_query)
    query_cache = {}
    for i, query in inext, queries do
        local system = systems[i]
        for arch in all(query) do
            -- Note: empty tables are never deleted, so they aren't removed from queries
            -- Skip empty archetypes
            if #arch ~= 0 then
                -- Skip system if it returns true
                system(arch)
            end
        end
    end
end