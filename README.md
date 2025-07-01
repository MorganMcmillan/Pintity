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

Components describe data and are added to entities. Components without data are called tags.

```lua
-- A component is a name that matches to an entity's attribute.
component"position"
component"velocity"
component"player"

-- The attribute name must match the component's name.
player.position = { x = 0, y = 0 }
player.velocity = { x = 1, y = 2 }
-- Nil is seen as a valid value for components,
-- in which case the component is used as a tag.
player.player = nil
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
    print(pos.x.." "..pos.y)
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

Component values can be set like regular key-value pairs. Just make sure that the name you use for your entity's pair matches the name of a component.

Example:
```lua
component"position"

local e = entity()
e.position = { x = 64, y = 64 }
```

Entities have a special `__newindex` metamethod that checks if the key matches any component's name, and if it does then the entity will be available to be queried.

Regular key-value pairs are treated as **non-fragmenting components**, meaning that they do not change which table the entity will be queried from, and may or may not show up in the same archetype.

### Getting Component Values

Component key-value pairs are nothing special. They are stored directly inside the entity, and so their values can be retrieved using dot syntax.

```lua
print(entity.position.x .. " " .. entity.position.y)
```

### Deleting Components and Entities

To remove a component from an entity and ensure that this is reflected in any queries, simply call the entity with the component's name, like this:

```lua
-- Deletes `position`
e"position"
```

This syntax may seem strange, but it actually saves several tokens.

This syntax can also be used to delete all components from an entity. Simply call the entity without any arguments.

```lua
-- Deletes all components
e()
```

## `system(phase, terms, [exclude,] callback(entities) -> skip: boolean) -> Query`

Systems are functions that are ran for each entity in bulk. Systems within the same *phase* are ran in the order they are declared.

`terms` and `exclude` are a list of components to include and exclude, respectively. They are the same kind that are passed to `query`, which this function calls internally.

`callback` receives a list of *entities*, each guaranteed to have the component they are queried for, and not the ones that are excluded.

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

# Tips and Tricks

## Create Multiple Components

One trick to save tokens is to `split` a list of component names and call `component` for each of them.

```lua
foreach(split"position,velocity,acceleration,color,player", component)
```

## Dynamically Replace Systems

It's possible to get the index of the system that was last created that phase using `#phase.systems`.

```lua
function one_fish() ...
function two_fish() ...

system(OnUpdate, "fish", one_fish)
local idx_fish = #OnUpdate.systems

-- Replace one_fish with two_fish
OnUpdate.systems[idx_fish] = two_fish
```

This can be useful for handling multiple scenes or when a specific piece of logic needs to be run only once and then replaced thereafter.

# Lite Version

Pintity offers a lite version for the token-conscious. It removes certain features and has worse performance in exchange for a token count of ~300.

## Changes and Removed Features

- `component` doesn't check if more than 32 components have been made
- Garbage component values are not deleted when components are removed
- `system` no longer takes an `exclude` parameter
- Removed `phase` and phases
    - Lite opts to use a global phase for all systems, intended to be progressed in `_update`
    - `system` and `progress` no longer receive a phase
- Systems can no longer be skipped by returning true in `progress`
