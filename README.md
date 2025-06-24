# Pintity: Minimalist ECS For Pico-8

Pintity is a bitset-archetype ECS for Pico-8, meaning that components are represented by bits and entities are stored into tables. That also means it's efficient for querying lots of entities.

# Features

- Fast and easy to use API
- Simplistic AOS storage that feels just like OOP
- Extremely fast queries that can be updated automatically
- Automatic systems that iterate multiple entities at once
- Prefabs for quick spawning of entities
- Phases to separate update logic from drawing code

# Usage

All functions are exposed to the global environment.

Entities are objects with any number of components.

```lua
local player = entity()
```

Components describe data and are added to entities.

```lua
-- A component is a name that matches to an entity's attribute.
component"postion"
component"velocity"
component"player"

-- The attribute name must match the component's name.
player.position = {0, 0}
player.velocity = {1, 2}
-- Tags are simply represented with the boolean true.
player.player = true
```

Systems are functions that are run automatically for all entities that match a query. They iterate over all entities that have the specified components.

```lua
-- Systems take in a comma separated string of component names to look for.
local Move = system(OnUpdate, "position,velocity", function(entities)
    for e in all(entities) do
        e.position.x += e.velocity.x
        e.position.y += e.velocity.y
    end
end)

-- Tasks are systems without any query, and run only once each frame
local DisplayPlayer = system(OnUpdate, nil, function()
    local pos = player.position
    print(pos.x, pos.y)
end)
```

Systems return the entities that they are queried for, which allows said query to be used inside the system and updated automatically.
Here is an example of a collision resolution system.

```lua
local CheckCollisions = system(OnUpdate, "position, hitbox", function(entities)
    for e in all(entities) do
        for arch in all(CheckCollisions) do
            for other in all(arch) do
                if is_colliding(e, other) then
                    resolve_collision(e, other)
                end
            end
        end
    end
end)
```

Systems are then run by calling `progress()` each frame.
Their queries must be updated by calling `update_phases()` within `_update` before progress is called.

```lua
function _update60()
    -- Update all system queries
    update_phases()
    -- Run systems at 60fps
    progress(OnUpdate)
end
```

# API

## `component(name)`

Creates a new named component.

> [!WARNING]
> Because Pintity is a bitset-based ECS, and Pico-8 only allows 32-bit numbers, the maximum amount of components that can be created is 32. A *component* is just an integer with a single bit set to 1.

## `entity() -> Entity`

Spawns a new *entity*. *Entities* are objects that can have an arbitrary amount of data associated with them.

Pintity implements **entity recycling**, which means entities that have been deleted will have their data reused to save memory. This means that you should never call `entity` twice without adding at least one *component*.

Deletes all data from the entity and makes it not alive. Deleted entities will be made available for recycling.

### Setting Component Values

TODO

### Getting Component Values

### Deleting Components and Entities

### 


## `system(phase, terms, [exclude,] callback(entities) -> skip: boolean) -> Query`

Systems are functions that are ran for each entity in bulk. Systems within the same *phase* are ran in the order they are declared.

`terms` and `exclude` are a list of components to include and exclude, respectively. They are the same kind that are passed to `query`, which this function calls internally.

`callback` receives a list of *entities*, each guarenteed to have the component they are queried for, and not the ones that are excluded.

Example:
```lua
local Move = system(OnUpdate, "position,velocity", function(entities)
    for e in all(entities) do
        e.position.x += e.velocity.x
        e.position.y += e.velocity.y
    end
end)
```

## `query(terms, [exclude]) -> { Entity[], ... }`

Returns list of each archetype matching `terms` that doesn't match any `exclude` terms.

## `phase() -> Phase`

Creates a new phase. Phases contain both queries and systems, and are all updated via `update_phases` once per frame.

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

## `prefab{component: value, ...) -> Prefab`

A prefab allows for the efficient creation of entities with many components and values.

Prefab entities can be created with `instantiate`.

Example:
```lua
local Circle = prefab{position = { 0, 0 }, color = 8, radius = 4, is_shape = true}
```

## `instantiate(prefab) -> Entity`

Creates an *entity* from a *prefab*. The entity will have the *components* and values of the prefab.

Example:
```lua
local e = instantiate(circle)
circle.postion = { 64, 64 }
```

# Lite Version

Pintity offers a lite version for the token-conscious. It removes certain features and has worse performance in exchange for a token count of ~450.

> [!Important]
> The current version of Pintity-Lite has not yet caught up to the full version's changes.

## Changes and Removed Features

- `component` doesn't check if more than 32 components have been made
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
