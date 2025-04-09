#include pintity.lua

local function eq(a, b)
    assert(a == b, tostr(a).." does not equal "..tostr(b))
end

function Entity:assert_has(component)
    assert(self:has(component), "entity missing component "..tostr(component, 1))
    return self
end

function Entity:assert_has_value(component, value)
    assert(self:get(component) == value, "entity does not have value "..tostr(value))
    return self
end

function Entity:assert_has_all(components)
    local bits = 0
    for c in all(components) do bits |= c end
    return self:assert_has(bits)
end

-- Resets the state of the ECS
function reset_fn()
    arch0 = {entities = {}}
    archetypes, query_cache = {[0] = arch0}, {}
    component_bit = 1 >> 16
    components = {}
    queries, systems = {}, {}
end

function write(text)
    print(text)
    printh(text)
end

local function test(name, fn, ...)
    reset_fn()
    name..=": "
    local okay, message = coresume(cocreate(fn), ...)
    if not okay then
        write(name.."[failed]: ")
        write(message)
    else
        write(name.."[passed]")
    end
end

test("has components", function ()
    local foo, bar, baz = component(), component("bar"), component()
    local e = entity():set(foo):set(bar):set(baz, 25)
    e:assert_has(foo)
        :assert_has_value(bar, "bar")
        :assert_has(baz)
        :assert_has_value(baz, 25)
end)

test("components shift left", function ()
    local foo, bar, baz = component(), component(), component()
    eq(foo, 1 >> 16)
    eq(bar, 1 >> 15)
    eq(baz, 1 >> 14)
end)

test("32 component max (fails)", function ()
    for i = 1, 33 do
        component()
    end
end)

test("tags not added to archetype", function ()
    local tag = component()
    local e = entity():set(tag)
    eq(e.archetype[tag], nil)
end)

test("Zero entities not alive", function ()
    local e = entity()
    eq(e:alive(), false)
    local foo = component(10)

    e:set(foo)
    eq(e:alive(), true)
    e:remove(foo)
    eq(e:alive(), false)

    e:set(foo):set(component()):set(component())
    e:delete()
    eq(e:alive(), false)
end)

test("prefab instantiation", function ()
    local position, size, is_moving = component(), component(1), component()
    local pre = prefab(position, {5, 10}, size, 16, is_moving, nil)
    local e = instantiate(pre)
        :assert_has(position)
        :assert_has_value(size, 16)
    eq(e.archetype[is_moving], nil)

    eq(e.archetype, archetypes[pre.bits])
end)

test("prefab with preexisting archetype", function ()
    local foo, bar = component(1), component(2)
    local a = entity():set(foo):set(bar).archetype

    local pre = prefab(foo, 10, bar, 20)
    local e = instantiate(pre)
    local arch = e.archetype
    eq(arch, a)
    eq(#arch.entities, 2)
    eq(#arch[foo], 2)
    eq(#arch[bar], 2)
end)

test("bulk prefab instantiation", function ()
    local foo, bar, tag = component(1), component(2), component()
    local pre = prefab(foo, 1, bar, 10, tag)

    for i = 1, 256 do
        instantiate(pre)
    end

    local arch = archetypes[pre.bits]
    eq(#arch.entities, 256)
    eq(#arch[bar], 256)
    eq(arch[tag], nil)
end)

test("query matches multiple archetypes", function ()
    local foo, bar, baz = component(), component(), component()
    entity():set(foo):set(bar)
    entity():set(foo):set(baz)
    entity():set(bar):set(baz)

    eq(#query{ foo }, 3)
    eq(#query{ bar }, 3)
    eq(#query{ baz }, 2) -- "baz" archetype not created

    eq(#query{ foo, bar }, 1)
    eq(#query({ foo }, { bar }), 2)
end)

test("query updates", function ()
    local foo, bar = component(), component()
    local e = entity():set(foo)
    local q = query{ foo }
    eq(#q, 1)

    query_cache = {}
    e:set(bar)
    update_query(q)
    eq(#q, 2)
end)

test("replace components", function ()
    reset_fn()
    local foo, bar, baz = component(1), component(2), component(3)
    local e = entity():set(foo, 10)
    
    local fb_arch = e.archetype
    e:replace(foo, bar)
    assert(not e:has(foo), "e still has foo")
    e:assert_has_value(bar, 10)

    local bz_arch = e.archetype
    e:replace(bar, baz, 20)
    assert(not e:has(bar), "e still has bar")
    e:assert_has_value(baz, 20)

    local zf_arch = e.archetype
    e:replace(baz, foo)
    assert(not e:has(baz), "e still has baz")
    e:assert_has_value(foo, 20)

    -- Archetype asserts
    eq(fb_arch[bar], nil)
    eq(fb_arch[baz], nil)
    eq(bz_arch[baz], nil)
    eq(bz_arch[foo], nil)
    eq(zf_arch[foo], nil)
    eq(zf_arch[bar], nil)
end)