local awful = require("awful")
local test_client = require("_client")

awful.util.deprecate = function() end

local has_spawned = false
local steps = {

function(count)

if count <= 1 and not has_spawned and #client.get() < 2 then
    awful.spawn("xterm")
    awful.spawn("xterm")
    has_spawned = true
elseif #client.get() >= 2 then

-- Test properties
client.focus = client.get()[1]
local c  = client.focus
-- local c2 = client.get()[2]

c.foo = "bar"

-- Check if the property system works
assert(c.foo == "bar")
assert(c.foo == awful.client.property.get(c, "foo"))

-- Test jumpto

--FIXME doesn't work
-- c2:jump_to()
-- assert(client.focus == c2)
-- awful.client.jumpto(c)
-- assert(client.focus == c)

-- Test moveresize
c.size_hints_honor = false
c:geometry {x=0,y=0,width=50,height=50}
c:relative_move( 100, 100, 50, 50 )
for _,v in pairs(c:geometry()) do
    assert(v == 100)
end
awful.client.moveresize(-25, -25, -25, -25, c )
for _,v in pairs(c:geometry()) do
    assert(v == 75)
end

-- Test movetotag

local t  = mouse.screen.tags[1]
local t2 = mouse.screen.tags[2]

c:tags{t}
assert(c:tags()[1] == t)
c:move_to_tag(t2)
assert(c:tags()[1] == t2)
awful.client.movetotag(t, c)
assert(c:tags()[1] == t)

-- Test toggletag

c:tags{t}
c:toggle_tag(t2)
assert(c:tags()[1] == t2 or c:tags()[2] == t2)
awful.client.toggletag(t2, c)
assert(c:tags()[1] == t and c:tags()[1] ~= t2 and c:tags()[2] == nil)

-- Test floating
assert(c.floating ~= nil and type(c.floating) == "boolean")
c.floating = true
assert(awful.client.floating.get(c))
awful.client.floating.set(c, false)
assert(not c.floating)

return true
end
end
}

local has_error

table.insert(steps, function()
    -- Make sure there is no extra callbacks that causes double screen changes
    -- (regress #1028 #1052)
    client.connect_signal("property::screen",function(c)
        if c.class and c.class ~= "screen"..c.screen.index then
            has_error = table.concat {
                "An unexpected screen change did occur\n",
                debug.traceback(),"\n",
                c.class, " Screen: ",c.screen.index
            }
        end
    end)

    return true
end)

local multi_screen_steps = {}

-- Add a test client on each screen.
table.insert(multi_screen_steps, function()
    has_error = false
    for i=1, screen.count() do
        local s = screen[i]
        test_client("screen"..i, nil, {
            screen = s,
        })
    end

    return true
end)

-- Test if the clients have been placed on the right screen
table.insert(multi_screen_steps, function()
    if #client.get() ~= screen.count() then return end

    if has_error then print(has_error) end
    assert(not has_error)

    for i=1, screen.count() do
        local s = screen[i]

        -- Just in case
        for _, t in ipairs(s.selected_tags) do
            assert(t.screen == s)
        end

        local t = s.selected_tag
        assert(t and t.screen == s)

        -- In case the next step has failed, find what went wrong
        for _, c in ipairs(t:clients()) do
            -- This is _supposed_ to be impossible, but can be forced by buggy
            -- lua code.
            if c.screen ~= t.screen then
                local tags = c:tags()
                for _, t2 in ipairs(tags) do
                    assert(t2.screen == c.screen)
                end

                assert(false)
            end
            assert(c.screen.index == i)
        end

        -- Check that the right client is placed, the loop above will trigger
        -- asserts already, but in case the tag has more than 1 client and
        -- everything is messed up, those asserts are still necessary.
        assert(#t:clients() == 1)
        assert(t:clients()[1].class == "screen"..i)
        assert(t:clients()[1].screen == s)

        -- Make sure it stays where it belongs
        awful.placement.maximize(t:clients()[1])
        assert(t:clients()[1] and t:clients()[1].screen == t.screen)
    end

    return true
end)

require("_multi_screen")(steps, multi_screen_steps)

require("_runner").run_steps(steps)
