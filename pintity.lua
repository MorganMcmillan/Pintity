-- Pintity: a stupid simple ECS for Pico-8
-- By Morgan.

--- Type definitions:
--- @alias Entity { archetype: Archetype, _row: integer } An object containing arbitrary data
--- @alias Component string The name of a component
--- @alias Relationship string The name of a relationship
--- @alias System fun(entities: Entity[]) -> skip?: boolean
--- @alias Phase { [integer]: Query, systems: System[] }
--- @alias Term fun(...) A closure that dictates the evaluation of a query
--- @alias Match string | { first: string, second: any }
--- @alias Query { [integer]: Term, matches: { [Archetype]: Match[] } }
--- @alias Archetype { [integer]: Entity, [Component]: Archetype, _with: { [Component]: Archetype } }

--- @type Archetype
--- The archetype containing no components. Used for recycling.
arch0 = { _with = {} }

--- @type Query[]
cached_queries = {}

--- @type { Component: Archetype[] }
components = {}

--- @type { Relationship: { any: Archetype[] } }
relationships = {}

--- @type Phase[]
phases = {}

pint_mt = {}

relationship_mt = {}

local function create_relationship(entity, name)
    return setmetatable({}, {
            __newindex = function(relationship, target, value)
                update_archetype(entity, relationship, nil, target)
                rawset(relationship, target, value)
            end,
            -- Used to delete a target from the relationship
            -- Unlike the entity's `__call` this one requires that a name be passed in
            __call = function(relationship, target)
                update_archetype(entity, nil, name, target)
                rawset(relationship, target, nil)
            end
        })
end

-- Used primarily to access unassigned relationships and add them
function pint_mt:__index(name)
    if relationships[name] then
        -- This is done to make relationship-target access syntax more consistent
        return rawset(self, name, create_relationship(self, name))
    end
end

-- Used to add a new component
function pint_mt:__newindex(name, value)
    if components[name] then
        update_archetype(self, name)
    elseif relationships[name] then
        -- Used for single-target relationships like `parent`
        update_archetype(self, name, nil, value)
    end
    rawset(self, name, value)
end

-- Used to delete a value from an entity. This may look strange, but it actually saves 2 tokens.
-- If name is not given, then the entity is deleted.
function pint_mt:__call(name)
    if name then
        -- Remove just one component
        -- Checks for single-target relationship
        update_archetype(self, nil, name, relationships[name] and self[name])
        -- Used to prevent tags from being re-added
        -- And to ensure __newindex is called
        rawset(self, name, nil)
    else
        -- Remove self from archetype
        swap_remove_entity(self.archetype, self._row)
        -- TODO: code for entity deletion
    end
end

---Creates a new entity.
---@return Entity
function entity()
    return setmetatable(
        add(arch0, { archetype = arch0, _row = #arch0 + 1 }),
        pint_mt
    )
end

---Registers a new component name(s).
---@param names string A comma separated string of component names
local function component(names)
    for name in all(split(names)) do
        components[name] = {}
    end
end

---Registers a new relationship name(s).
---@param names string A comma separated string of relationship names
local function relationship(names)
    for name in all(split(names)) do
        relationships[name] = {}
    end
end

--- Removes the entity at row and swaps it with the last entity
function swap_remove_entity(archetype, row)
    archetype[row] = archetype[#archetype]
    archetype[row]._row = row
    deli(archetype)
end

--- Gets the value of a relationship target or component
local function get_target(table, name, target)
    local value = name and table[name]
    if value and target then value = value[target] end
    return value
end

--- Sets the value of a relationship target, or creates it
local function set_target(table, name, target, value)
    local relationship = table[name]
    if relationship then
        relationship[target] = value
    else
        table[name] = {[target] = value}
    end
end

--- Removes the relationship target from a table
--- If the relationship ends up empty then it is removed from the table entirely
--- Assumes that the specified relationship and target already exists within the table
local function remove_target(table, name, target)
    local relationship = table[name]
    relationship[target] = nil
    if not next(relationship) then table[name] = nil end
end

function add_graph_edges(lesser_arch, greater_arch, with, without, target)
    if without then
        lesser_arch, greater_arch, with = greater_arch, lesser_arch, without
    end
    if target then
        set_target(greater_arch, with, target, lesser_arch)
        set_target(lesser_arch._with, with, target, greater_arch)
    else
        greater_arch[with] = lesser_arch
        lesser_arch._with[with] = greater_arch
    end
end

--- Returns an iterator beginning at the first key of the table
--- This function can be thought of as the complement of `ipairs`
local function kpairs(table)
    return next, table, #table > 0 and #table or nil
end

local function copy_component_edges(from, to)
    for component, relationship in kpairs(from) do
        if relationships[component] then
            local target_set = {}
            for target in next, relationship do
                target_set[target] = true
            end
            to[component] = target_set
        else
            to[component] = true
        end
    end
end

-- Creates a set representing the archetype with or without the specified component or target
local function offset_archetype(arch, with, without, target)
    local component_set = {}
    -- Copy component/relationship-target set from archetype
    copy_component_edges(arch, component_set)
    -- Modify set to reflect the desired target archetype
    if target then
        if with then
            set_target(component_set, with, target, true)
        else
            remove_target(component_set, without, target)
        end
    else
        component_set[with or without] = with
    end
    return component_set
end

--- Checks that the archetype is a subset of `subset`
local function arch_subset(subset, arch)
    for component, relationship in kpairs(arch) do
        local entry = subset[component]
        if not entry then return false end
        if relationships[component] then
            for target in next, relationship do
                if not entry[target] then return false end
            end
        end
    end
    return true
end

--- Returns the exact match of an archetype with or without the specified component
---@param arch Archetype The archetype to compare with
---@param ...? string Both `with`, `without`, and `target`. Replaced with `...` to save tokens.
-- Maybe put arch in it as well. Will need to change each function that receives it.
function exact_match_archetype(arch, ...)
    local offset = offset_archetype(arch, ...)
    for other in all(archetypes) do
        -- Check that the other archetype has all the components of this archetype
        if arch_subset(offset, other) and arch_subset(other, offset) then
            add_graph_edges(arch, other, ...)
            return other
        end
    end
end

-- Gets the component or relationship edge of an archetype and ensures that it points to another archetype.
function get_edge(arch, with, target)
    local edge = get_target(arch, with, target)
    if edge ~= true then return edge end
end

---Changes the archetype of an entity.
---@param entity Entity The entity to move
---@param with? string The name of the component to add
---@param without? string The name of the component to remove
---@param target? any The target if with|without is a relationship
function update_archetype(entity, with, without, target)
    local old = entity.archetype
    local new = get_edge(old._with, with, target) or get_edge(old, without, target) or
    exact_match_archetype(old, with, without, target)

    -- Invariant if the last entity is this one
    swap_remove_entity(old, entity._row)
    if new then
        -- Move entity from old archetype to new
        add(new, entity)
    else
        -- Create new archetype from old's entity and add it
        new = { entity, _with = {} }
        -- Ensure that new has all of old's components (except for without)
        copy_component_edges(old, new)
        if without then
            if target then
                remove_target(new, without, target)
            else
                new[without] = nil
            end
        end
        -- Manage graph. This will also add `with` to the new archetype
        add_graph_edges(old, new, with, without, target)

        -- Add archetype to it's component/relationship records
        for k, targets in kpairs(new) do
            local rel_targets = relationships[k]
            if rel_targets then
                for target in next, targets do
                    local record = rel_targets[target] or {}
                    add(record, new)
                    rel_targets[target] = record
                end
            elseif k ~= "_with" then
                add(components[k], new)
            end
        end
    end
    entity.archetype = new
    entity._row = #new
end

local function get_query_matches(archetype, results, query, matches)
    local term = query[#results + 1]
    if term then
        term(archetype, results, query, matches)
    else
        add(matches, {unpack(results)})
    end
    -- Done for terms that add to the results table
    deli(results)
end

local function on_entity_delete(entity)
    for _, rel in next, relationships do
        local arch = rel[entity]
        if arch then delete_arch(arch) end
    end
end

local function char(input, c)
    if input[1] == c then return sub(input, 2), c end
end

local function parse_term(input)
    if input[1] == '(' then
        local relationship, target = unpack(split(sub(input, 2), ':'))
        return function (arch)
            local rel = arch[relationship]
            return rel and rel[target] and { first = relationship, second = target }
        end
    end
    return function (arch)
        return arch[input]
    end
end

--- Parses a comma separated string of terms into a list of closures that test if a term matches a query
--- Terms are not allowed to contain any whitespace
--- @param terms any
local function parse_query(terms)
    local closures = {}
    for term in all(split(terms)) do
        local operator, rest = term[1], sub(term, 2)
        if operator == '!' then
            term = parse_term(rest)
            add(closures, function (arch, results, ...)
                if not term(arch) then
                    add(results, true)
                    get_query_matches(arch, results, ...)
                end
            end)
        elseif operator == '?' then
            term = parse_term(rest)
            add(closures, function (arch, results, ...)
                local result = term(arch)
                add(results, result or false)
                get_query_matches(arch, results, ...)
            end)
        else
            term = parse_term(term)
            add(closures, function (arch, results, ...)
                local result = term(arch)
                if result then
                    add(results, result)
                    get_query_matches(arch, results, ...)
                end
            end)
        end
    end
end

---Queries match entities with specific components.
---@param terms string A comma separated string of query terms
---@return Archetype[] query Every archetype matched with the query
local function query(terms)
    return update_query(parse_query(terms), archetypes)
end

---Cached queries are queries that are updated at the start of every call to `_update`
---@param terms string A comma separated string of query terms
---@return Archetype[] query Every archetype matched with the query
local function cached_query(terms)
    return add(cached_queries, query(terms))
end

--- Updates the contents of the query to represent the current state of the ECS.\
--- Adds new archetypes after they are created
---@param query Query
---@param tables? Archetype[] defaults to query_cache
---@return Query query
function update_query(query, tables)
    for archetype in all(tables or query_cache) do
        local matches = {}
        get_query_matches(archetype, query, {}, matches)
        if #matches > 0 then
            query.matches[archetype] = matches
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
    return { systems = {} }
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
    return add(phase, terms and cached_query(terms, callback and exclude) or { { 0 } }) -- Empty table to ensure iteration
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
