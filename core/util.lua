local Util = {}

local function squash(text)
    local lowered = tostring(text or ""):lower()
    local squashed = lowered:gsub("[%s_]+", "")
    return squashed
end

local searchKeys = setmetatable({}, { __mode = "k" })

local function searchKey(row, fields)
    local key = searchKeys[row]
    if key then return key end

    local parts = {}
    for index, field in ipairs(fields) do parts[index] = squash(row[field]) end
    key = table.concat(parts, "\1")
    searchKeys[row] = key
    return key
end

--- Keeps the rows whose listed fields contain the query, ignoring case, spaces and underscores.
--- Each row's searchable text is computed once, so typing in a list of thousands stays cheap.
function Util.filter(rows, query, fields)
    local needle = squash(query)
    if needle == "" then return rows end

    local kept = {}
    for _, row in ipairs(rows) do
        if searchKey(row, fields):find(needle, 1, true) then kept[#kept + 1] = row end
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
