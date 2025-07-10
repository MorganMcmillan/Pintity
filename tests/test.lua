local function eq(a, b)
    assert(a == b, tostr(a).." does not equal "..tostr(b))
end

local function assert_has(e, c)
    local bits = components[c]
    assert(e.components & bits == bits, "entity missing component "..c)
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
