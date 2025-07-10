#include test.lua
#include ../pintity.lua
#include ../extensions/prefab.lua

-- Resets the state of the ECS
function reset_fn()
    arch0 = {}
    archetypes, query_cache = {[0] = arch0}, {}
    cached_queries = {}
    component_bit = 1 >> 16
    components = {}
    phases = {}
end

test("has components", function ()
    component"foo"
    component"bar"
    component"baz"

    local e = entity()
    e.foo = true
    e.bar = "bar"
    e.baz = 25
    assert_has(e, "foo")
    assert_has(e, "bar")
    eq(e.bar, "bar")
    assert_has(e, "baz")
    eq(e.baz, 25)
end)

test("components shift left", function ()
    foreach(split"foo,bar,baz", component)

    eq(components.foo, 1 >> 16)
    eq(components.bar, 1 >> 15)
    eq(components.baz, 1 >> 14)
end)

test("prefab instantiation", function ()
    foreach(split"position,size,is_moving", component)
    local pre = prefab{position = {5, 10}, size = 16, is_moving = true}
    local e = instantiate(pre)
    assert_has(e, "position")
    assert_has(e, "size")
    eq(e.size, 16)
    assert_has(e, "is_moving")


    eq(e.archetype, archetypes[pre.components])
end)

test("prefab with preexisting archetype", function ()
    component"foo"
    component"bar"
    local e = entity()
    e.foo = 5
    e.bar = 10
    local a = e.archetype

    local pre = prefab{foo = 10, bar = 20}
    local arch = instantiate(pre).archetype
    eq(arch, a)
    eq(#arch, 2)
end)

test("bulk prefab instantiation", function ()
    foreach(split"foo,bar,tag", component)
    local pre = prefab{foo = 1, bar = 10, tag = true}
    local arch = pre.archetype

    for i = 1, 256 do
        eq(instantiate(pre).archetype, arch)
    end

    eq(#arch, 256)
end)

function count_arches()
    local i = 0
    for _ in next, archetypes do i += 1 end
    return i
end

test("query matches multiple archetypes", function ()
    local e
    foreach(split"foo,bar,baz", component)
    e = entity()
    e.foo = 0
    e.bar = 0
    e = entity()
    e.foo = 0
    e.baz = 0
    e = entity()
    e.bar = 0
    e.baz = 0

    write(count_arches())

    eq(#query"foo", 3)
    eq(#query"bar", 3)
    eq(#query"baz", 2) -- "baz" archetype not created

    eq(#query"foo,bar", 1)
    eq(#query("foo", "bar"), 2)
end)

test("query updates", function ()
    component"foo"
    component"bar"
    local e = entity()
    e.foo = true
    local q = query"foo"
    eq(#q, 1)

    query_cache = {}
    e.bar = true
    update_query(q)
    eq(#q, 2)
end)

test("phases update correctly", function ()
    foreach(split"foo,bar,baz", component)

    local on_test = phase()
    system(on_test, "foo,bar,baz", function (e)
        write"system running on phase on_test"
    end)
    
    local e = entity()
    e.foo, e.bar, e.baz = 0, 1, 2
    update_phases()
    progress(on_test)
end)

test("component adds with nil", function ()
    component"foo"

    local e = entity()
    e.foo = nil
    eq(e.components, components.foo)
end)