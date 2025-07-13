local function eq(a, b)
    assert(a == b, tostr(a).." does not equal "..tostr(b))
end

function write(text)
    print(text)
    printh(text)
end

local function test(name, fn, ...)
    reset_fn()
    name..=": "
    local co = cocreate(fn)
    local okay, message = coresume(co, ...)
    if not okay then
        write(name.."[failed]: ")
        write(message)
        write(trace(co))
    else
        write(name.."[passed]")
    end
end
