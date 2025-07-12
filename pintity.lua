-- Pintity: a stupid simple ECS for Pico-8
-- By Morgan.

-- 375 tokens compressed
-- 358 tokens less than 1.0.0 (733 tokens)

--- Type definitions:
--- @alias Entity { components: ComponentSet, archetype: Archetype, row: integer } An object containing arbitrary data
--- @alias Component string The name of a component
--- @alias System fun(entities: Entity[]) -> skip?: boolean
--- @alias Phase { [integer]: Query, systems: System[] }
--- @alias Query { terms: Component[], bits: ComponentSet, exclude: ComponentSet, [integer]: any[] }
--- @alias Archetype { [integer]: Entity, [Component]: Archetype, _with: { [Component]: Archetype }, _len: integer }

--- @type Archetype
--- The archetype containing no components. Used for recycling.
arch0 = {_with = {}, _len = 0}

--- @type Archetype[]
archetypes = {arch0}

--- @type Query[]
cached_queries = {}

--- @type Archetype[]
--- New archetypes created this frame to update queries by.\
--- Prevents system queries from adding archetypes twice.
query_cache = {}

--- @type Component
--- The current component ID\
--- Pico-8 uses 32-bit fixed point numbers, so `1` is actually bit 16
component_bit = 1 >> 16

--- @type { Component: true }
components = {}

--- @type Phase[]
phases = {}

pint_mt = {}

-- Used to add a new component
function pint_mt:__newindex(name, value)
    local bit = components[name]
    if bit then
        update_archetype(self, name)
    end
    rawset(self, name, value)
end

-- Used to delete a value from an entity. This may look strange, but it actually saves 2 tokens.
-- If name is not given, then the entity is deleted.
function pint_mt:__call(name)
    if name then
        -- Remove just one component
        update_archetype(self, nil, name)
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
        add(arch0, { archetype = arch0, row = #arch0 + 1 }),
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
---@param entity Entity The entity to move
---@param with? string The name of the component to add
---@param without? string The name of the component to remove
function update_archetype(entity, with, without)
    local old = entity.archetype
    local new = exact_match_archetype(old, with, without)

    -- Invariant if the last entity is this one
    swap_remove_entity(old, entity.row)
    if new then
        -- Move entity from old archetype to new
        add(new, entity)
    else
        -- Create new archetype from old's entity and add it
        new = {entity, _with = {}}
        -- Add graph edges
        if with then
            new[with] = old
            old._with[with] = new
            new._len = old._len + 1
        elseif without then
            old[without] = new
            new._with[without] = old
            new._len = old._len - 1
        end

        add(archetypes, add(query_cache, new))
    end
    entity.archetype = new
    entity.row = #new
end

---Registers a new component name(s).
---@param name string A comma separated string of component names
local function component(names)
    for name in all(split(names)) do
        components[name] = true
    end
end

---Queries match entities with specific components.
---@param terms string A comma separated string of component names
---@param exclude? string A comma separated string of component names to exclude
---@return Archetype[] query Every archetype matched with the query
local function query(terms, exclude)
    return update_query({ terms = split(terms), exclude = split(exclude) }, archetypes)
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
---@return Query query
function update_query(query, tables)
    for archetype in all(tables or query_cache) do
        if archetype._len < #query.terms then goto ecs_match_failed end
        for term in all(query.terms) do
            if not archetype[term] then goto ecs_match_failed end
        end
        for exclude_term in all(query.exclude) do
            if archetype[exclude_term] then goto ecs_match_failed end
        end
        add(query, archetype)
        ::ecs_match_failed::
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
    if #query_cache > 0 then
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