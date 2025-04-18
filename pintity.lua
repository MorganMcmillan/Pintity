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
--- @alias Archetype { [Component]: any[], entities: Entity[] }
--- @class Prefab { bits: ComponentSet, [integer]: any }

--- @type Archetype
--- The archetype containing no components. Used for recycling.
arch0 = {entities = {}}

--- @type { ComponentSet: Archetype }
archetypes = {[0] = arch0}

--- @type { ComponentSet: Archetype }
--- New archetypes created this frame to update queries by\
--- Prevents system queries from adding archetypes twice
query_cache = {}

--- @type Component
--- The current component ID\
--- Pico-8 uses 32-bit fixed point numbers, so `1` is actually bit 16
component_bit = 1 >> 16

--- @type { Component: any }
components = {}

--- @type Phase[]
phases = {}

--- @type System[]
--- Systems to be run each frame
systems = {}

--- @type Query[]
--- Queried components to use with each system\
--- Empty queries represent tasks
queries = {}

---An entity is an object that can have an arbitrary amount of data added to it.
---@class Entity
---@field archetype Archetype
---@field components ComponentSet
---@field row integer
local Entity = {}
Entity.__index = Entity

---Creates a new entity.\
---Dead entities may be recycled, so this should never be called twice before adding a component.
---@return Entity
function entity()
    -- Recycle unused entities
    return last(arch0.entities) or setmetatable(
        -- Row is known to be 1, as arch0 is empty
        add(arch0.entities, { archetype = arch0, components = 0, row = 1 }),
        Entity
    )
end

---Checks if an entity has a component or set of components
---@param component Component|ComponentSet
---@return boolean
function Entity:has(component)
    return self.components & component == component
end

---Checks if an entity is alive.\
---Note: an entity is not considered alive until it has at least one component
---@return boolean
function Entity:alive()
    return self.components ~= 0
end

---Returns the value of an entity's component, or nil if it doesn't have it.
---@param component Component
---@return any|nil
function Entity:get(component)
    local col = self.archetype[component]
    return col and col[self.row]
end

---Sets the component's value, but without checking that it exists.\
---This should only be used if the entity is known to have the component.
---@param component Component
---@param value any
---@return self
function Entity:rawset(component, value)
    self.archetype[component][self.row] = value
    return self
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
function Entity:update_archetype(exclude, include)
    local components = self.components
    local row, old, new = self.row, self.archetype, archetypes[self.components]
    -- Invariant if the last entity is this one
    last(old.entities).row = row
    -- Swap remove out all components
    -- Note: "entities" is treated like a regular component, and will be included
    if new then
        -- Move row from old archetype to new
        for bit, col in next, old do
            add(new[bit], swap_remove(col, row))
        end
    else
        -- Create new archetype from old's row and add it
        new = {}
        for bit, col in next, old do
            new[bit] = {swap_remove(col, row)}
        end

        -- `remove`: Remove falsely added component
        new[exclude] = nil
        -- `set`: Ensures the newly set component is included in the archetype
        if include then new[include] = {} end

        archetypes[components] = new
        query_cache[components] = new
    end
    self.archetype = new
    self.row = #new.entities
end

---Sets the value of an entity's component.\
---Important: a component must not be set to nil, unless it either has a default value or is a tag.
---@param component Component
---@param value? any
---@return self
function Entity:set(component, value)
    value = value or copy(components[component])
    if self.components & component ~= component then
        -- Add the component with bitwise or
        self.components |= component
        self:update_archetype(0, value and component)
    end
    if value then
        self:rawset(component, value)
    end
    return self
end

Entity.add = Entity.set

---Removes a component from an entity.
---@param component Component
---@return self
function Entity:remove(component)
    if self:has(component) then
        -- Xor remove the entity
        self.components ^^= component
        self:update_archetype(component)
    end
    return self
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

---Deletes an entity and all of its components.
function Entity:delete()
    self.components = 0
    self:update_archetype(0)
end

---Performs a shallow copy of a table or other value
---@param value any
---@return any
function copy(value)
    if type(value) ~= "table" then return value end
    local copied = {}
    for k, v in next, value do
        copied[k] = v
    end
    return copied
end

---Creates a new component identifier.\
---Note: Pintity can only handle creating up to 32 components.
---@param value? any
---@return Component component
local function component(value)
    ---@type Component
    local b = component_bit
    assert(b ~= 0, "Error: component limit reached. Applications can only have up to 32 components.")
    components[b] = value
    component_bit <<= 1
    return b
end

---Queries match entities with specific components.
---@param terms Component[] the list of components to be queried
---@param exclude? Component[] a list of components to exclude from the query
---@return Archetype[] query Every archetype matched with the query
local function query(terms, exclude)
    local filter = 0
    for term in all(terms) do filter |= term end
    local results = { terms = terms, bits = filter, exclude = 0 }
    if exclude then
        filter = 0
        for excludeTerm in all(exclude) do filter |= excludeTerm end
        results.exclude = filter
    end
    update_query(results, archetypes)
    return results
end

---Updates the contents of the query to represent the current state of the ECS.
---@param query Query
---@param tables Archetype[]
function update_query(query, tables)
    if not query.terms then return end
    for bits, archetype in next, tables or query_cache do
        if bits & query.bits == query.bits
        and bits & query.exclude == 0 then
            local fields = { archetype.entities }
            for term in all(query.terms) do
                add(fields, archetype[term])
            end
            add(query, fields)
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

---Automatically updates all phases. Must be called in `_update` before any `progress` is called.
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
---@param terms Component[]
---@param exclude? Component[]|System
---@param callback? System
---@return System callback
local function system(phase, terms, exclude, callback)
    add(phase, terms and query(terms, callback and exclude) or {{0}}) -- Empty table to ensure iteration
    return add(phase.systems, callback or exclude)
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
    local new = e:set(prefab.bits).archetype
    -- Saves several archetype moves
    for bit, value in next, prefab do
        if (new[bit]) e:rawset(bit, value) else new[bit] = {value}
    end
    -- Keep "bits" field from creeping in
    new.bits = nil
    return e
end

---Runs all systems that are part of `phase`
---@param phase Phase the current phase to run.
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