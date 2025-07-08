-- Events module for Pintity.
-- By Morgan.

event_mt = {__call = emit}

--- @alias Event { callbacks: fun(entity: Entity, ...: any)[], terms: ComponentSet[], exclusions: ComponentSet[] } A set of functions that are called if an entity matches a query.

---Creates a new event. An event is just a set of functions that match on certain entities.
---@return Event
local function event()
    return setmetatable({
        callbacks = {},
        terms = {},
        exclusions = {}
    }, event_mt)
end

---Attaches a callback to the event, matched by a query
---@param event Event The event to execute on
---@param terms string A comma separated string of component names
---@param exclude? string A comma separated string of component names to exclude
---@param callback any
local function on(event, terms, exclude, callback)
    add(event.terms, or_terms(terms))
    add(event.exclusions, or_terms(callback and exclude))
    add(event.callbacks, callback or exclude)
end

---Emits an event for a singular entity.
---@param event Event The event to emit
---@param entity Entity The entity to match all handlers on
---@param ... any Extra arguments to event handlers
function emit(event, entity, ...)
    local components = entity.components
    -- Get cached handlers
    local handlers = event[components]
    if not handlers then
        handlers = {}
        -- Manually match event handlers
        local callbacks, exclusions = event.callbacks, event.exclusions
        for i, terms in inext, event.terms do
            if components & terms == terms
            and components & exclusions[i] == 0 then
                add(handlers, callbacks[i])
            end
        end
        -- Cache event handlers
        event[components] = handlers
    end
    for i = 1, #handlers do
        handlers[i](entity, ...)
    end
end