-- Events module for Pintity.
-- By Morgan.

event_mt = {}

---Emits event for a singular entity.
---Events can be thought of as "dynamic functions" for entities,
---as their execution is based on what components an entity has.
---@param entity Entity The entity to match all handlers on
---@param ... any Extra arguments to event handlers
function event_mt:__call(entity, ...)
    local archetype = entity.archetype
    -- Get cached handlers
    -- The set of events corresponds to the archetype the entity belongs to
    local handlers = self[archetype]
    if not handlers then
        handlers = {}
        -- Manually match event handlers
        local callbacks, exclusions = self.callbacks, self.exclusions
        for i, terms in inext, self.terms do
            for term in all(terms) do
                if not archetype[term] then goto event_query_match_failed end
            end
            for exclude_term in all(exclusions) do
                if archetype[exclude_term] then goto event_query_match_failed end
            end
            add(handlers, callbacks[i])
            ::event_query_match_failed::
        end
        -- Cache event handlers
        self[archetype] = handlers
    end
    for i = 1, #handlers do
        handlers[i](entity, ...)
    end
end

--- @alias Event { callbacks: fun(entity: Entity, ...: any)[], terms: ComponentSet[], exclusions: ComponentSet[] } A set of functions that are called if an entity matches a query.

---Creates a new event. An event is just a set of functions that match on certain entities.
---Events are called just like regular functions. The main difference being that they match an arbitrary amount of functions based on what components the entity has.
---In a way they can be thought of as systems that only match a single entity.
---@return Event event the newly created event
local function event()
    return setmetatable({
        terms = {},
        exclusions = {}
    }, event_mt)
end

---Attaches a callback to the event, matched by a query
---@param event Event the event to execute on
---@param terms string A comma separated string of component names
---@param exclude? string A comma separated string of component names to exclude
---@param callback any
local function on(event, terms, exclude, callback)
    add(event.terms, split(terms))
    add(event.exclusions, split(callback and exclude))
    add(event, callback or exclude)
end
