# Pintity: Minimalist ECS For Pico-8

Pintity is a bitset-archetype ECS for Pico-8, meaning that entities and components are represented as bitsets and stored in tables. That also means it's extremely fast and efficient for handling multiple entities

# Features

- Fast and easy to use API
- Fast archetype SOA storage
- Extremely fast queries that can be updated automatically
- Automatic systems that iterate multiple entities at once
- Prefabs for quick spawning of entities
- Phases to separate update logic from drawing logic

# Usage

All functions are exposed to the global environment.

Entities are objects with any number of components.

```lua
local player = entity()
```

Components describe data and are added to entities.

```lua
-- Components can be given default values
local Position = component({0, 0})
local Velocity = component()
local Player = component()

player:set(Position)
    -- component operations can be chained together
    :set(Velocity, {1, 2})
-- Tags can be added as components without any data
    :set(Player)
```

Systems are functions that are run automatically for all entities that match a query. It iterates over all entities that have the component.

```lua
local Move = system(OnUpdate, { Position, Velocity }, function(entities, positions, velocities)
    for i = 1, #entities do
        positions[i].x += velocities[i].x
        positions[i].y += velocities[i].y
    end
end)

-- Tasks are systems without any query, and run only once each frame
local DisplayPlayer = system(OnUpdate, nil, function()
    local pos = player:get(Position)
    print(pos.x, pos.y)
end)
```

Systems are then run by calling `progress()` each frame.

```lua
function _update60()
    -- Run systems at 60fps
    progress()
end
```

# API

## `entity() -> Entity`

Spawns a new *entity*. *Entities* are objects that can have an arbitrary amount of data associated with them.

Pintity implements **entity recycling**, which means entities that have been deleted will have their data reused to save memory. This means that you should never call `entity` twice without adding at least one *component*.

### `Entity:get(component) -> value|nil`

Gets the value of an entity's *component*, or `nil` if it doesn't have it.

### `Entity:has(component) -> boolean`

Whether or not the entity has the specified component. Returns true even for tags.

### `Entity:alive() -> boolean`

Whether or not the entity is alive. An entity is dead if it has no components, either through being newly made, `remove`ing all components, or after calling `delete`.

### `Entity:set(component, [value]) -> self`

Sets the value of the entity's *component*, and adds it if it didn't already have it. Can be chained.

If value is not given, it either defaults to the *component's* value, or the *component* is treated as a *tag*.

### `Entity:rawset(component, value) -> self`

Sets the value of the entity's *component* without checking for it. This should **ONLY** ever be used for overriding prefab values or in systems that match the specified component.

### `Entity:remove(component) -> self`

Removes the *component* from the entity. Can be chained.

### `Entity:replace(component, with, [value]) -> self`

Replaces a *component* with another *component*, setting either to `value` or the value of the previous *component*. Can be chained.

This is the same as calling `remove` followed by `set`, but is more efficient.

### `Entity:delete()`

Deletes all data from the entity and makes it not alive. Deleted entities will be made available for recycling.

## `component([default]) -> Component`

Creates a new *component* identifier. Components represent data that can be added to an *entity*, and are matched by *queries* and *systems*.

*Components* can be used as *tags* by not specifying any default value and never calling `entity:set` with a value. Components and tags **cannot be mixed**.

> [!WARNING]
> Because Pintity is a bitset-based ECS, and Pico-8 only allows 32-bit numbers, the maximum amount of components that can be created is 32. A *component* is just an integer with a single bit set to 1.

## `system(phase, terms, [exclude,] callback(entities, ...) -> skip: boolean) -> callback`

Systems are functions that are ran for each entity in bulk. Systems within the same *phase* are ran in the order they are declared.

`terms` and `exclude` are a list of components to include and exclude, respectively. They are the same kind that are passed to `query`, which this function calls internally.

`callback` receives a list of *entities*, followed by lists of *component values* associated with each entity, in the order they are specified in `terms`. System code should iterate over each entity's index, and fetch the value of each component at that index.

Example:
```lua
local Move = system(OnUpdate { Position, Velocity }, function(entities, positions, velocities)
    for i = 1, #entities do
        positions[i].x += velocities[i].x
        positions[i].y += velocities[i].y
    end
end)
```

## `query(terms, [exclude]) -> { Entity[], ... }`

Returns list of each archetype matching `terms` that doesn't match any `exclude` terms.

## `phase() -> Phase`

Creates a new phase. Phases contain both queries and systems, and are all updated via `update_phases`.

Phases were created to address Pico-8's division of the game loop into *update* and *draw* functions.

## `update_phases()`

Updates all queries for each phase, ensuring systems are able to match with newly created entities.

> **MUST** be called before `progress` is called within `_update`. 

## `progress(phase)`

Run all systems in a phase. This is intended to be called in Pico-8's `_update[60]` and `_draw` callbacks.

Example:
```lua
local OnUpdate = phase()
local OnDraw = phase()

function _update()
    update_phases()
    progress(OnUpdate)
end

function _draw()
    progress(OnDraw)
end
```

## `prefab(component, value, component, value, ...) -> Prefab`

A prefab allows for the efficient creation of entities with many components and values. Tags can be included by passing `nil` as their value.

Prefab entities can then be created with `instantiate`.

Example:
```lua
local Circle = prefab(Position, { 0, 0 }, Color, 8, Radius, 4, IsShape, nil)
```

## `instantiate(prefab) -> Entity`

Creates an *entity* from a *prefab*. The entity will have the *components* and values of the prefab.

Example:
```lua
local e = instantiate(Circle):rawset(Position, { 64, 64 })
```


# Lite Version

Pintity offers a lite version for the token-conscious. It removes certain features and has worse performance in exchange for a token count of ~450.

## Changes and Removed Features

- `component` doesn't check if more than 32 components have been made
- Removed 
- `get` throws if the entity doesn't have the component
- `set` may not receive a nil value
- `remove` and `replace` do not check if the entity has the specific component
- `system` no longer takes an `exclude` parameter
- Removed `Entity:alive`
- Removed support for tags
- Removed `query`
- Removed `phase` and phases
    - Lite opts to use a global phase for all systems, intended to be progressed in `_update`
    - `system` and `progress` no longer receive a phase
- Systems can no longer be skipped by returning true in `progress`