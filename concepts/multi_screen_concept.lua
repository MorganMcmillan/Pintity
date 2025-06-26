-- Multiple screen rendering concept

local screen_components = split"screen_1,screen_2,screen_3,screen_4"

foreach(screen_components, component)

-- System that detects if sprite is off screen
system(post_update, "position,sprite,sprite_size", function (es)
    local screen_left, screen_top, current_screen = camera_x, camera_y, current_screen
    for e in all(es) do
        if e.position.x + e.sprite_size * 8 < screen_left or
        e.position.x >= screen_left + 128 or
        e.position.y + e.sprite_size * 8 < screen_top or
        e.position.y >= screen_top + 128 then
            e(current_screen)
        end
    end
end)

-- System that detects if sprite is on screen
system(post_update, "position,sprite,sprite_size", function (es)
    local screen_left, screen_top, current_screen = camera_x, camera_y, current_screen
    for e in all(es) do
        if e.position.x + e.sprite_size * 8 >= screen_left or
        e.position.x < screen_left + 128 or
        e.position.y + e.sprite_size * 8 >= screen_top or
        e.position.y < screen_top + 128 then
            e[current_screen] = nil
        end
    end
end)

-- Note: I may need a way to enqueue entity moves/deletions so they don't get checked twice

function screen_systems()
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

function draw_system(phase, terms, exclude, callback)
    for screen in all(screen_components) do
        system(phase, terms..","..screen, exclude, callback)
    end
end

-- And then the draw phases can be called as normal