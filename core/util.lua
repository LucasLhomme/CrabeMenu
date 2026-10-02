local Util = {}

local function squash(text)
    local lowered = tostring(text or ""):lower()
    local squashed = lowered:gsub("%s+", "")
    return squashed
end

--- Keeps the rows whose listed fields contain the query, ignoring case and spaces.
function Util.filter(rows, query, fields)
    local needle = squash(query)
    if needle == "" then return rows end

    local kept = {}
    for _, row in ipairs(rows) do
        for _, field in ipairs(fields) do
            if squash(row[field]):find(needle, 1, true) then
                kept[#kept + 1] = row
                break
            end
        end
    end
    return kept
end

--- Returns a filter that recomputes only when the rows or the query change.
function Util.newFilter(fields)
    local lastRows, lastQuery, lastResult
    return function(rows, query)
        if rows == lastRows and query == lastQuery then return lastResult end
        lastRows, lastQuery = rows, query
        lastResult = Util.filter(rows, query, fields)
        return lastResult
    end
end

--- Turns an identifier such as "INV_NPC_TS_Tourist" into readable words.
function Util.humanize(identifier)
    local text = identifier:gsub("^INV_", ""):gsub("^NPC_", ""):gsub("_", " ")
    return text
end

--- Reports whether a string is a dotted IPv4 address.
function Util.isIPv4(text)
    local a, b, c, d = tostring(text):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return false end
    for _, part in ipairs({ a, b, c, d }) do
        if tonumber(part) > 255 then return false end
    end
    return true
end

return Util
