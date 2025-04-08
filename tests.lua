#include "pintity.lua"

local function eq(a, b)
    assert(a == b)
end

function Entity:assert_has(component)
    assert(self:has(component))
    return self
end

function Entity:assert_has_value(component, value)
    assert(self:get(component) == value)
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
    archetypes, new_archetypes = {[0] = arch0}, {}
    component_bit = 1 >> 16
    components = {}
    queries, systems = {}, {}
end

local function test(name, fn, ...)
    reset_fn()
    name..=": "
    local ok, value, result = pcall(fn, ...)
    if not ok then
        result = name.."[FAILED]"
        print(result)
        printh(result)
    else
        result = name.."[PASSED]: "..tostr(value)
        print(result)
        printh(result)
    end
end
