local Loader = ...
local Util = Loader.load("core.util")
local Items = Loader.load("ui.items")

local List = {}

--- Builds a page that lists `source()` rows behind a live search row.
--- options: fields (searched), toItem(row) -> item, emptyLabel, emptyHint, header() -> items.
function List.page(title, source, options)
    local search = ""
    local filter = Util.newFilter(options.fields)
    local builtFrom, builtHeader, built = nil, nil, {}

    local searchRow = Items.input("Search", function() return search end, function(text) search = text end,
        "Type part of a name; the list narrows as you type", true)

    local function build(rows, visible, header)
        built = {}
        for _, item in ipairs(header) do built[#built + 1] = item end
        built[#built + 1] = searchRow
        if #rows == 0 then
            built[#built + 1] = Items.info(options.emptyLabel or "Nothing here yet", nil, options.emptyHint)
        else
            built[#built + 1] = Items.info("Results", string.format("%d of %d", #visible, #rows))
        end
        for _, row in ipairs(visible) do built[#built + 1] = options.toItem(row) end
    end

    return {
        title = title,
        items = function()
            local rows = source() or {}
            local visible = filter(rows, search)
            local header = options.header and options.header() or {}
            if visible ~= builtFrom or #header ~= builtHeader then
                builtFrom, builtHeader = visible, #header
                build(rows, visible, header)
            end
            return built
        end,
    }
end

return List
