# Pintity: Minimalist ECS in Lua

Pintity is an entity component system for Pico-8.
It is designed as a bitset-archetype ECS, meaning that entities and components are represented as bitsets.

# Features

- Bitset component indexes, allowing for up to 32 components
- Fast archetype SOA storage
- Extremely fast queries that can be updated automatically
- Automatic systems that iterate multiple entities
- Prefabs for easy spawning of entities

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
local Move = system({ Position, Velocity }, function(entities, positions, velocities)
    for i = 1, #entities do
        positions[i].x += velocities[i].x
        positions[i].y += velocities[i].y
    end
end)

-- Tasks are systems without any query, and run only once each frame
local DisplayPlayer = system(nil, function()
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
