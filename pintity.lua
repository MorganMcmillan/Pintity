-- Pintity: a stupid simple ECS for Pico-8
-- By Morgan.

-- 733 tokens compressed

--- Type definitions:
--- @class Entity { components: ComponentSet, archetype: Archetype, row: integer } An object containing arbitrary data
--- @alias Component integer a singular bit identifying a component
--- @class ComponentSet integer bitset of components
--- @alias System fun(entities: Entity[], ...: any[]) -> skip?: boolean
--- @class Phase { [integer]: Query, systems: System[] }
--- @alias Query { terms: Component[], bits: ComponentSet, exclude: ComponentSet, [integer]: any[] }
--- @alias Archetype Entity[]
--- @class Prefab { bits: ComponentSet, string: any }

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
        self.components, self[name] ^^= components[name]
    else
        -- Remove all components.
        -- Note: component data is not actually removed, but it should never be accessed.
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

---Checks if an entity is alive.\
---Note: an entity is not considered alive until it has at least one (fragmenting) component
---@return boolean
function alive(e)
    return e.components ~= 0
end

-- Returns the last item of the table
function last(t) return t[#t] end

-- Removes the item at i and swaps its value with the last value
function swap_remove(t, i)
    i, t[i] = t[i], last(t)
    deli(t)
    return i
end

---Changes the archetype of an entity.\
---This is a low-level operation that is not meant to be used directly. Instead use `set`, `remove` or `replace`
---@param exclude Component when creating a new archetype with remove, ensures that this component is not added
---@param include? Component when creating a new archetype with set, add this component to have its value set
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

---Replaces one component with another.\
---This is functionally equivalent to calling `remove` followed by `set`, but saves an archetype move.\
---This should never be called with tags.
---@param component Component the component to replace
---@param with Component the component that's replacing the other one
---@param value? any the value to replace with. If nil, replaces `with` with the value of `component`.
---@return self
function Entity:replace(component, with, value)
    -- Prevents column from being emptied or entity having `component` ADDED
    if self.components & component == 0 then return self:set(with, value) end
    value = value or self:get(component)
    -- Xor remove, or add
    self.components = self.components ^^ component | with
    self:update_archetype(component, with)
    return self:rawset(with, value)
end

---Creates a new component identifier.\
---Note: Pintity can only handle creating up to 32 components.
---@param name string the name of the component
local function component(name)
    assert(component_bit ~= 0, "Error: component limit reached. Applications can only have up to 32 components.")
    components[name] = component_bit
    component_bit <<= 1
end

---Queries match entities with specific components.
---@param terms string A comma separated string of component names
---@param exclude? string A comma separated string of component names to exclude
---@return Archetype[] query Every archetype matched with the query
local function query(terms, exclude)
    local filter = 0
    for term in split(terms) do filter |= components[term] end

    local results = { bits = filter, exclude = 0 }

    if exclude then
        filter = 0
        for excludeTerm in split(exclude) do filter |= components[excludeTerm] end
        results.exclude = filter
    end

    update_query(results, archetypes)
    return results
end

--- Updates the contents of the query to represent the current state of the ECS.\
--- Adds new archetypes after they are created
---@param query Query
---@param tables Archetype[]
function update_query(query, tables)
    if not query.bits then return end
    for bits, archetype in next, tables or query_cache do
        if bits & query.bits == query.bits
        and bits & query.exclude == 0 then
            add(query, archetype)
        end
    end
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
        for phase in all(phases) do
            foreach(phase, update_query)
        end
    end
    query_cache = {}
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
    return add(phase, terms and query(terms, callback and exclude) or {{0}}) -- Empty table to ensure iteration
end

---Creates a new prefab. A prefab is a template for an entity, like a blueprint.\
---Entities can be created from these using instantiate
---@param t any
---@return any
function prefab(t)
    local bits, new = 0, {}
    for k, v in next, t do
        local bit = components[k]
        if bit then
            bits |= bit
        end
    end
    if not archetypes[bits] then
        archetypes[bits], query_cache[bits] = new, new
    end
    t.bits = bits
    return t
end

---Instantiates a new entity from a prefab created by `prefab`.\
---Note: this does not recycle entities.
---@param prefab Prefab
---@return Entity instance
function instantiate(prefab)
    local e, arch = {}, archetypes[prefab.bits]
    -- Copy the prefab's components into the entity instance
    for k, v in next, prefab do
        e[k] = v
    end
    add(e, arch).row = #arch
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