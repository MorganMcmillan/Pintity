-- Pintity: a stupid simple ECS for Pico-8
-- By Morgan.

-- 474 tokens compressed
-- 259 tokens less than 1.0.0 (733 tokens)

--- Type definitions:
--- @class Entity { components: ComponentSet, archetype: Archetype, row: integer } An object containing arbitrary data
--- @alias Component integer a singular bit identifying a component
--- @class ComponentSet integer bitset of components
--- @alias System fun(entities: Entity[]) -> skip?: boolean
--- @class Phase { [integer]: Query, systems: System[] }
--- @alias Query { terms: Component[], bits: ComponentSet, exclude: ComponentSet, [integer]: any[] }
--- @alias Archetype Entity[]
--- @class Prefab { bits: ComponentSet, [string]: any }

--- @type Archetype
--- The archetype containing no components. Used for recycling.
arch0 = {}

--- @type { ComponentSet: Archetype }
archetypes = {[0] = arch0}

--- @type Query[]
cached_queries = {}

--- @type { ComponentSet: Archetype }
--- New archetypes created this frame to update queries by.\
--- Prevents system queries from adding archetypes twice.
query_cache = {}

--- @type Component
--- The current component ID\
--- Pico-8 uses 32-bit fixed point numbers, so `1` is actually bit 16
component_bit = 1 >> 16

--- @type { string: Component }
components = {}

--- @type Phase[]
phases = {}

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
    if name then
        -- Remove just one component
        self.components ^^= components[name]
        update_archetype(self)
        -- Used to prevent tags from being re-added
        rawset(self, name, nil)
    else
        -- Remove self from archetype
        swap_remove_entity(self.archetype, self.row)
    end
end

---Creates a new entity.
---@return Entity
function entity()
    return setmetatable(
        add(arch0, { archetype = arch0, components = 0, row = #arch0 + 1 }),
        pint_mt
    )
end

-- Removes the entity at row swaps it with the last entity
function swap_remove_entity(archetype, row)
    archetype[row] = archetype[#archetype]
    archetype[row].row = row
    deli(archetype)
end

---Changes the archetype of an entity.
function update_archetype(entity)
    local components = entity.components
    local new = archetypes[components]

    -- Invariant if the last entity is this one
    swap_remove_entity(entity.archetype, entity.row)
    if new then
        -- Move entity from old archetype to new
        add(new, entity)
    else
        -- Create new archetype from old's entity and add it
        new = {entity}

        archetypes[components], query_cache[components] = new, new
    end
    entity.archetype = new
    entity.row = #new
end

---Creates a new component identifier.\
---Note: Pintity can only handle creating up to 32 components.
---@param name string the name of the component
local function component(name)
    assert(component_bit ~= 0, "Error: component limit reached. Applications can only have up to 32 components.")
    components[name] = component_bit
    component_bit <<= 1
end

function or_terms(terms)
    local bits = 0
    if terms then
        for term in all(split(terms)) do bits |= components[term] end
    end
    return bits
end

---Queries match entities with specific components.
---@param terms string A comma separated string of component names
---@param exclude? string A comma separated string of component names to exclude
---@return Archetype[] query Every archetype matched with the query
local function query(terms, exclude)
    return update_query({ bits = or_terms(terms), exclude = or_terms(exclude) }, archetypes)
end

---Cached queries are queries that are updated at the start of every call to _update with `
---@param terms string A comma separated string of component names
---@param exclude? string A comma separated string of component names to exclude
---@return Archetype[] query Every archetype matched with the query
local function cached_query(terms, exclude)
    return add(cached_queries, query(terms, exclude))
end

--- Updates the contents of the query to represent the current state of the ECS.\
--- Adds new archetypes after they are created
---@param query Query
---@param tables Archetype[]
function update_query(query, tables)
    for bits, archetype in next, tables or query_cache do
        if bits & query.bits == query.bits
        and bits & query.exclude == 0 then
            add(query, archetype)
        end
    end
    return query
end

---Creates a new phase. Systems can be added to phases.\
---Phases are run using `progress`.\
---All phases must be updated using `update_phases()` in `_update` before `progress` is called.\
---Example: `OnUpdate, OnDraw = phase(), phase()`
---@return Phase
local function phase()
    return add(phases, { systems = {} })
end

--- Automatically updates all phases. Must be called in `_update` before any `progress` is called.
function update_phases()
    if next(query_cache) then
        foreach(cached_queries, update_query)
        query_cache = {}
    end
end

--- Create and add a new system.\
--- Systems are run once per frame, and in the order they are created.\
--- If a system needs to stop iteration, return `true`.\
--- Important: if a system needs to delete entities or add new components, it should iterate **in reverse** to prevent entities from being skipped.
---@param phase Phase the phase to run this system on
---@param terms string
---@param exclude? string|System
---@param callback? System
---@return Archetype[] query
local function system(phase, terms, exclude, callback)
    add(phase.systems, callback or exclude)
    return add(phase, terms and cached_query(terms, callback and exclude) or {{0}}) -- Empty table to ensure iteration
end

---Creates a new prefab. A prefab is a template for an entity, like a blueprint.\
---Entities can be created from these using instantiate
---@param t any
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

---Runs all systems that are part of `phase`
---@param phase Phase the current phase to run.
function progress(phase)
    for i, query in inext, phase do
        local system = phase.systems[i]
        for arch in all(query) do
            -- Note: empty tables are never deleted, so they aren't removed from queries
            -- Skip empty archetypes
            if #arch ~= 0 then
                -- Skip system if it returns true
                if system(arch) then break end
            end
        end
    end
end