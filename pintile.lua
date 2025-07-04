-- Pintile: A Pintity tilemap utility for easily spawning entities

---Spawns a new entity for each tile that is matched by `entities`.
---When an entity is spawned, it will attempt to have its "position", "sprite", and "tile" components set if they were already set to true.
---@param entities {}[] tile sprite mapping to tables with component-value pairs
---@param replacements {}[] tile sprite mapping to the sprite to replace this tile with
---@param x? integer the x starting coordinate of the tilemap
---@param y? integer the y starting coordinate of the tilemap
---@param width? integer the width of the tilemap area to spawn from
---@param height? integer the height of the tilemap area to spawn from
function spawn(entities, replacements, x, y, width, height)
    -- Convert entity data into prefabs
    for i = 1, #entities do
        entities[i] = prefab(entities[i])
    end
    -- Scan each tile of the map
    x, y = x or 1, y or 1
    for x = x, width or 128 do
        for y = y, height or 64 do
            local sprite = mget(x, y)
            local entity, replacement = entities[sprite], replacements[sprite]

            if entity then
                -- Spawn entity
                entity = instantiate(entity)
                if entity.position then entity.position = { x = x * 8 - 8, y = y * 8 - 8 } end
                if entity.sprite then entity.sprite = sprite end
                if entity.tile then entity.tile = { x = x, y = y } end
            end
            if replacement then
                -- Replace tile
                mset(x, y, replacement)
            end
        end
    end
end