local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Items = Loader.load("ui.items")

-- Renders the Crabe.Menu registry: the entries other mods declare with
-- Crabe.Menu.register / registerInCategory (Disney Infinity Complete's warps,
-- Radahn's spawns, ...). The contract is CrabeLoader's src/api/15_menu.lua:
-- submenu (items or build), action, toggle (state + onToggle) and cycle
-- (cycle + index + onCycle), each handler returning an optional status line.
-- Those handlers belong to other mods, so they run through Native.run: one
-- failing shows in the footer instead of counting against CrabeMenu's own
-- update callback.

local toItems

local function cleanLabel(label)
    return (tostring(label or "?"):gsub("%s*>%s*$", ""))
end

local function report(status)
    if status ~= nil and status ~= "" then State.setStatus(tostring(status), "info") end
end

-- Converts a list once per change: menu.lua asks for the items every tick,
-- and a registry list only changes when a mod registers something.
local function memoized(source)
    local from, count, built = nil, -1, {}
    return function()
        local entries = source() or {}
        if entries ~= from or #entries ~= count then
            from, count = entries, #entries
            built = toItems(entries)
        end
        return built
    end
end

local function submenuPage(entry)
    local submenu = entry.submenu
    local label = cleanLabel(entry.label)
    return function()
        -- A build function lists what only exists once the game runs, so it
        -- runs on every entry; a string result is a reason the list is empty.
        if type(submenu.build) == "function" then
            local ok, result, failure = Native.run(label, submenu.build)
            if ok and type(result) == "table" then
                submenu.items = result
            elseif ok then
                report(failure or result or "Nothing to list yet")
            end
        end
        return {
            title = cleanLabel(submenu.title or label),
            items = memoized(function() return submenu.items end),
        }
    end
end

local function toggleItem(entry, label)
    return Items.toggle(label,
        function() return entry.state == true end,
        function(on)
            if on == (entry.state == true) then return end
            entry.state = on
            local ok, status = Native.run(label, entry.onToggle, on)
            if ok then report(status) else entry.state = not on end
        end)
end

local function cycleItem(entry, label)
    return Items.choice(label, entry.cycle,
        function() return entry.index or 1 end,
        function(index)
            entry.index = index
            local ok, status = Native.run(label, entry.onCycle, entry.cycle[index], index)
            if ok then report(status) end
        end)
end

local function actionItem(entry, label)
    return Items.action(label, function()
        local ok, status = Native.run(label, entry.action)
        if ok then report(status) end
    end)
end

toItems = function(entries)
    local list = {}
    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            local label = cleanLabel(entry.label)
            if type(entry.submenu) == "table" then
                list[#list + 1] = Items.submenu(label, submenuPage(entry))
            elseif entry.toggle then
                list[#list + 1] = toggleItem(entry, label)
            elseif type(entry.cycle) == "table" and #entry.cycle > 0 then
                list[#list + 1] = cycleItem(entry, label)
            elseif type(entry.action) == "function" then
                list[#list + 1] = actionItem(entry, label)
            else
                list[#list + 1] = Items.info(label)
            end
        end
    end
    if #list == 0 then
        list[1] = Items.info("No mod menus", nil, "Mods add entries here with Crabe.Menu.register")
    end
    return list
end

return {
    title = "Mods",
    items = memoized(function() return Crabe.Menu and Crabe.Menu.root and Crabe.Menu.root.items end),
}
