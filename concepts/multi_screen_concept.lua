-- Multiple screen rendering concept

local screen_components = split"screen_1,screen_2,screen_3,screen_4"

foreach(screen_components, component)

function screen_check_systems()
    -- Create on screen checks
    for screen in all(screen_components) do
        -- Check if offscreen
        system(post_update, "position,sprite,"..screen, function (es)
            local camera_x, camera_y = camera_x, camera_y
            for e in all(es) do
                local sprite_size = e.sprite_size or 1
                if e.position.x + sprite_size * 8 < camera_x or
                e.position.x >= camera_x + 128 or
                e.position.y + sprite_size * 8 < camera_y or
                e.position.y >= camera_y + 128 then
                    e(screen)
                end
            end
        end)
        
        -- Note: I may need a way to enqueue entity moves/deletions so they don't get checked twice
        -- Check if onscreen
        system(post_update, "position,sprite", screen, function (es)
            local camera_x, camera_y = camera_x, camera_y
            for e in all(es) do
                local sprite_size = e.sprite_size or 1
                if e.position.x + sprite_size * 8 >= camera_x or
                e.position.x < camera_x + 128 or
                e.position.y + sprite_size * 8 >= camera_y or
                e.position.y < camera_y + 128 then
                    e[screen] = nil
                end
            end
        end)
    end
end

-- Run all screen checks

for i = 0, 3 do
    _map_display(i)
    -- Offset camera for display
    camera_x, camera_y = 128 * (i & 1), 128 * (i >> 1)
    camera(camera_x, camera_y)
    current_screen = screen_components[i]
    progress(post_update)
end

-- Special systems need to be created for drawing

on_screen_phases = {phase(), phase(), phase(), phase()}

function draw_system(terms, exclude, callback)
    for i, screen in inext, screen_components do
        system(on_screen_phases[i], terms..","..screen, exclude, callback)
    end
end

-- Then in __draw

for i = 1, 4 do
    _map_display(i - 1)
    -- There will likely be an actual camera implementation
    camera_x, camera_y = 128 * (i & 1), 128 * (i >> 1)
    progress(on_screen_phases[i])
end

-- And then the draw phases can be called as normal