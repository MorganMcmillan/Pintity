-- Pintity_lite: an even simpler ECS for Pico-8
-- By Morgan.

-- 507 tokens compressed

--- Type definitions:
--- @class Entity { components: ComponentSet, archetype: Archetype, row: integer } An object containing arbitrary data
--- @alias Component integer a singular bit identifying a component
--- @class ComponentSet integer bitset of components
--- @alias System fun(entities: Entity[], ...: any[]) -> bool
--- @alias Query { Terms: Component[], bits: ComponentSet, [integer]: any[] }
--- @alias Archetype { Component: any[], entities: Entity[] }

arch0 = {entities = {}}
--- @type { ComponentSet: Archetype }
archetypes = {[0] = arch0}

--- @type { ComponentSet: Archetype }
--- New archetypes created this frame
--- Prevents system queries from adding archetypes twice by setting it to all archetypes this frame
new_archetypes = {}

--- @type Component
--- The current component ID\
--- Pico-8 uses 32-bit fixed point numbers, so `1` is actually bit 16
component_bit = 1 << 15


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

---Creates a new entity
---@return Entity
function entity()
    -- Recycle unused entities
    return last(arch0.entities) or setmetatable(
        -- Row is known to be 1, as arch0 is empty
        add(arch0.entities, { archetype = arch0, components = 0, row = 1 }),
        Entity
    )
end

---Checks if the entity has a component or set of components
---@param component Component|ComponentSet
---@return boolean
function Entity:has(component)
    return self.components & component == component
end

---Returns the value of this entity's component, or nil if it doesn't have it
---@param component Component
---@return any|nil
function Entity:get(component)
    local col = self.archetype[component]
    return col and col[self.row]
end

---Sets the component's value, but without checking that it exists.\
---This should only be used if the entity is known to have the component
---@param component Component
---@param value any
function Entity:rawset(component, value)
    self.archetype[component][self.row] = value
end

-- Returns the last item of the table
function last(t) return t[#t] end

-- Removes the item at i and swaps its value with the last value
function swap_remove(t, i)
    local val = t[i]
    if t[2] then t[i] = last(t) end
    t[#t] = nil
    return val
end

---Changes the archetype of the entity.\
---This is a low-level operation that is not meant to be used directly. Instead use `set`, `remove` or `replace`
---@param exclude Component when creating a new archetype with remove, ensures that this component is not added
---@param include? Component when creating a new archetype with set, add this component to have its value set
function Entity:update_archetype(exclude, include)
    local row, old, new = self.row, self.archetype, archetypes[self.components]
    -- Invariant if the last entity is this one
    last(old.entities).row = row
    -- Swap remove out all components
    -- Note: "entities" is treated like a regular component, and will be included
    if new then
        for bit, col in next, old do
            add(new[bit], swap_remove(col, row))
        end
    else -- Create new archetype and add it
        new = {}
        for bit, col in next, old do
            new[bit] = {swap_remove(col, row)}
        end

        -- `remove`: Remove falsely added component
        new[exclude] = nil
        -- `set`: Ensures the newly set component is included in the archetype
        if include then new[include] = {} end

        archetypes[self.components] = new
        new_archetypes[self.components] = new
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
    -- Xor remove, or add
    self.components = self.components ^^ component | with
    self:update_archetype(component, with)
    self:rawset(component, value or self:get(component))
    return self
end

---Delete the entity and all its components.
function Entity:delete()
    self.components = 0
    self:update_archetype(0)
end

---Creates a new component identifier.\
---Note: Pintity can only handle creating up to 32 components.
---@return Component component
function component(value)
    ---@type Component doesn't assert when there are more than 32 components
    component_bit <<>= 1
    return component_bit
end

---Queries match entities with specific components.
---@param terms Component[] the list of components to be queried
---@param exclude? Component[] a list of components to exclude from the query
---@return Archetype[] query Every archetype matched with the query
local function query(terms, exclude)
    local filter = 0
    for term in all(terms) do filter |= term end
    return { terms = terms, bits = filter }
end

---Updates the contents of the query to represent the current state of the ECS.
---@param query Query
---@param tables Archetype[]
function update_query(query, tables)
    if not query.bits then return end
    for bits, archetype in next, tables or new_archetypes do
        if bits & query.bits == query.bits then
            local fields = { archetype.entities }
            for term in all(query.terms) do
                add(fields, archetype[term])
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
---@param exclude Component[]|System
---@param callback? System
---@return System callback
local function system(terms, callback)
    add(queries, terms and query(terms) or {{0}}) -- Empty table to ensure iteration
    return add(systems, callback)
end

---Progress the ECS each frame. Should be called in `_update`
function progress()
    if next(new_archetypes) then
        foreach(queries, update_query)
        -- The archetypes are no longer new this frame
        new_archetypes = {}
    end
    for i, system in inext, systems do
        for cols in all(queries[i]) do
            -- Note: empty tables are never deleted, so they aren't removed from queries
            -- Skip empty archetypes
            if #cols[1] ~= 0 then
                -- Skip system if it returns true
                if system(unpack(cols)) then break end
            end
        end
    end
end