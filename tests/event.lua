#include test.lua
#include ../pintity.lua
#include ../extensions/event.lua

-- Resets the state of the ECS
function reset_fn()
    arch0 = {}
    archetypes, query_cache = {[0] = arch0}, {}
    cached_queries = {}
    component_bit = 1 >> 16
    components = {}
    phases = {}
    for k in next, events do
        events[k] = nil
    end
end

test("has event", function ()
    component"foo"
    component"bar"
    component"baz"
    event"test"

    on("test", "foo", function (e)
        write(e.foo)
    end)

    on("test", "bar", function (e)
        write(e.bar)
    end)

    on("test", "foo,bar", function (e)
        write"I'm a foobar!"
    end)
    
    on("test", "foo,bar,baz", function (e)
        write"I should not trigger"
    end)
    
    local e = entity()
    e.foo = "Look Ma. I got foo!"
    e.bar = "Look Ma. I got bar!"
    -- assert(e.test, "entity does not have test event")
    -- Events should be able to be called like methods
    assert(e.test, "entity does not have test event!")
    e:test()
end)

test("event accepts parameters", function ()
    foreach(split"attack,defense,healing,strength", component)
    event"play"
    
    on("play", "attack", function (card, player, enemy)
        enemy.health -= card.attack + player.strength - enemy.defense
    end)

    on("play", "defense", function (card, player)
        player.defense += card.defense
    end)

    on("play", "healing", function (card, player)
        player.health = min(player.health + card.healing, player.max_health)
    end)

    on("play", "strength", function (card, player)
        player.strength += card.strength
    end)

    local swing_dumbbell = prefab{
        attack = 10,
        strength = 2
    }

    local shield = prefab{
        defense = 5
    }

    local callous = prefab{
        defense = 3,
        healing = 3
    }

    local eat_vegetables = prefab{
        strength = 1,
        healing = 2
    }

    local vampirism = prefab{
        attack = 4,
        healing = 4
    }

    local player = {
        health = 80,
        max_health = 80,
        defense = 0,
        strength = 0,
        deck = {
            instantiate(swing_dumbbell),
            instantiate(eat_vegetables),
            instantiate(callous),
            instantiate(swing_dumbbell)
        }
    }

    local enemy = {
        health = 30,
        max_health = 30,
        defense = 0,
        strength = 0,
        deck = {
            instantiate(vampirism),
            instantiate(shield),
            instantiate(swing_dumbbell),
            instantiate(callous)
        }
    }

    for i = 1, #player.deck do
        player.deck[i]:play(player, enemy)
        write("enemy health: "..enemy.health)
        enemy.deck[i]:play(enemy, player)
        write("player health: "..player.health)
    end

end)