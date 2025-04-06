-- Pintity: a stupid simple ECS for Pico-8
-- By Morgan.

--- Type definitions:
--- @class Entity { components: ComponentSet, archetype: Archetype, row: integer } An object containing arbitrary data
--- @class Component integer a singular bit identifying a component
--- @class ComponentSet integer bitset of components
--- @alias System fun(entities: Entity[], ...: any[]) -> bool
--- @alias Query { terms: Component[], bits: ComponentSet, exclude: ComponentSet, [integer]: any[] }
--- @alias Archetype { Component: any[], entities: integer[] }
--- @class Prefab { Archetype, ComponentSet, { Component: any } }

arch0 = {entities = {}}
--- @type { ComponentSet: Archetype }
archetypes = {[0] = arch0}

--- @type { ComponentSet: Archetype }
--- New archetypes created this frame
--- Prevents system queries from adding archetypes twice by setting it to all archetypes this frame
--- All archetypes are new on the first frame
new_archetypes = archetypes

--- @type Component
--- The current component ID\
--- Pico-8 uses 32-bit fixed point numbers, so `1` is actually bit 16
component_bit = 1 >> 16

--- @type { Component: any }
components = {}

--- @type System[]
--- Systems to be run each frame
systems = {}

--- @type Query[]
--- Queried components to use with each system\
--- Empty queries represent tasks
queries = {}

---@class Entity
local pint_mt = {}
--preserve: pint_mt.*, !pint_mt.move_archetype

function pint_mt:has(component)
    return self.components & component == component
end

-- Note: an entity is not considered alive until it has at least one component
function pint_mt:alive()
    return self.components ~= 0
end

function pint_mt:__index(component)
    return components[component] and self.archetype[component][self.row]
end

function last(t) return t[#t] end

function swap_remove(t, i)
    local val = t[i]
    t[i], t[#t] = last(t) --, nil
    return val
end

---Changes the archetype of the entity.\
---This is a low-level operation that is not meant to be used by
---@param new? Archetype if nil, creates a new archetype
---@param exclude Component when creating a new archetype with remove, ensures that this component is not added
---@param include? Component when creating a new archetype with set, add this component to have its value set
function pint_mt:move_archetype(new, exclude, include)
    local row, old = self.row, self.archetype
    last(old.entities).row = row
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
---Important: a component must not be set to nil, unless it is known to be a tag without any preexisting data.
---@param component Component
---@param value? any or nil if `component` is a tag
---@return self
function pint_mt:set(component, value)
    value = value or components[component]
    if not self:has(component) then
        self.components |= component
        self:move_archetype(archetypes[self.components], 0, value and component)
    end
    if value then
        self.archetype[component][self.row] = value
    end
    return self
end

pint_mt.__newindex = pint_mt.set

---Removes a component from an entity
---@param component Component
---@return self
function pint_mt:remove(component)
    if not self:has(component) then return end
    local old_arch = self.archetype
    -- Xor remove the entity
    self.components ^^= component
    self:move_archetype(archetypes[self.components], component)
    return self
end

---Replaces one component with another.\
---This is functionally equivalent to calling `remove` followed by `set`, but saves an archetype move.\
---This should never be called 
---@param component Component the component to replace
---@param with Component the component that's replacing the other one
---@param value? any the value to replace with. If nil, replaces `with` with the value of `component`.
---@return self
function pint_mt:replace(component, with, value)
    local bitset = self.components
    if bitset & component == 0 then return self:set(component, value) end
    value = value or self[component]
    -- Xor remove
    bitset = (bitset ^^ component) | with
    self:move_archetype(archetypes[bitset], component, with)
    self.components = bitset
    self.archetype[component][self.row] = value
    return self
end

---Delete the entity and all its components.
function pint_mt:delete()
    self.components = 0
    self:move_archetype(arch0, 0)
end

--preserve: entity, component

---Creates a new entity
---@return Entity
function entity(arch, bits, values)
    -- Recycle unused entities
    local e = deli(arch0.entities) or {}
    local arch = arch or arch0
    -- NOTE: entities could be recycled by using the empty (0) archetype
    if values then
        for bit, value in next, values do
            arch[bit] = value
        end
    end
    add(arch.entities, e)
    e.arch, e.row, e.bits = arch, #arch.entities, bits or 0
    return setmetatable(e, pint_mt)
end

---Creates a new component identifier.\
---Note: Pintity can only handle creating up to 32 components.
---@return Component component
function component(value)
    --@type Component
    local b = component_bit
    assert(b ~= 0, "Error: component limit reached. Applications can only have up to 32 components.")
    components[b] = value
    component_bit <<= 1
    return b
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

--preserve: prefab, instantiate, query, system, progress

---Queries match entities with specific components.
---@param terms Component[] the list of components to be queried
---@param exclude? Component[] a list of components to exclude from the query
---@return Archetype[] query Every archetype matched with the query
function query(terms, exclude)
    local filter = 0
    for term in all(terms) do filter |= term end
    local results = { terms = terms, bits = filter }
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
    for bits, components in next, tables or new_archetypes do
        if bits & query.bits == query.bits
        and bits & query.exclude == 0 then
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
function system(terms, exclude, callback)
    add(queries, terms and query(terms, callback and exclude) or {{0}}) -- Empty table to ensure iteration
    add(systems, callback or exclude)
end

---Creates a new prefab. Call `instantiate` on it to spawn a new entity.\
---Example: `enemy = prefab(Position, {5, 10}, Sprite, 1, Target, player, Enemy, nil)`
---@param ... Component|any components and values, or `nil` values for tags
---@return Prefab prefab
function prefab(...)
    local components, bits = {}, 0
    for i = 1, select("#", ...), 2 do
        local component = select(i, ...)
        bits |= component
        -- Tags are ignored as `add(table, nil)` has the same behavior as `add(nil, value)`.
        components[component] = copy(select(i + 1, ...))
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

    return { archetype, bits, components }
end

---Instantiates a new entity from a prefab created by `prefab`.
---@param prefab Prefab
---@return Entity instance
function instantiate(prefab)
    return entity(unpack(prefab))
end

---Progress the ECS each frame. Should be called in `_update`
function progress()
    if new_archetypes ~= archetypes and #new_archetypes > 0 then
        foreach(queries, update_query)
        -- The archetypes are no longer new this frame
        new_archetypes = {}
    end
    for i, query in inext, queries do
        local system = systems[i]
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