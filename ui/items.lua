local Items = {}

--- A row that runs `run()` when selected.
function Items.action(label, run, hint, value)
    return { kind = "action", label = label, run = run, hint = hint, value = value }
end

--- An on/off row: `get()` returns the state, `set(on)` applies it.
function Items.toggle(label, get, set, hint)
    return { kind = "toggle", label = label, get = get, set = set, hint = hint }
end

--- A row that opens `page`, which may also be a function returning the page.
function Items.submenu(label, page, hint, value)
    return { kind = "submenu", label = label, page = page, hint = hint, value = value }
end

--- A "< value >" row: `get()` returns the index into `options`, `set(index)` applies it.
function Items.choice(label, options, get, set, hint)
    return { kind = "choice", label = label, options = options, get = get, set = set, hint = hint }
end

--- A text row: Enter opens a prompt; `set(text)` runs on confirm, or on every key when live.
function Items.input(label, get, set, hint, live)
    return { kind = "input", label = label, get = get, set = set, hint = hint, live = live == true }
end

--- A read-only row showing `value`, a string or a function returning one.
function Items.info(label, value, hint)
    return { kind = "info", label = label, value = value, hint = hint }
end

--- A non-selectable heading that splits a long page into groups.
function Items.section(label)
    return { kind = "section", label = label }
end

--- Resolves a value that may be given as a function.
function Items.resolve(value)
    if type(value) == "function" then return value() end
    return value
end

return Items
