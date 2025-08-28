-- Events module for Pintity.
-- By Morgan.

events, event_mt = {}, {}

pint_mt.__index = events

---Emits event for a singular entity.
---@param entity Entity The entity to match all handlers on
---@param ... any Extra arguments to event handlers
function event_mt:__call(entity, ...)
    local archetype = entity._archetype
    -- Get cached handlers
    local handlers = self[components]
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
---@param name string The name of the event
local function event(name)
    events[name] = setmetatable({
        callbacks = {},
        terms = {},
        exclusions = {}
    }, event_mt)
end

---Attaches a callback to the event, matched by a query
---@param event string The name of the event to execute on
---@param terms string A comma separated string of component names
---@param exclude? string A comma separated string of component names to exclude
---@param callback any
local function on(event, terms, exclude, callback)
    event = events[event]
    add(event.terms, terms)
    add(event.exclusions, callback and exclude)
    add(event.callbacks, callback or exclude)
end
