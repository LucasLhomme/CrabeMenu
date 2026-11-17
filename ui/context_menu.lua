local Loader = ...
local State = Loader.load("core.state")
local Input = Loader.load("core.input")
local Theme = Loader.load("ui.theme")
local FreeCam = Loader.load("modules.freecam")
local Cheats = Loader.load("modules.cheats")
local SpeedHack = Loader.load("modules.speedhack")

local ContextMenu = {}

local MENU_W = 246
local SUB_W = 228
local ROW_H = 26
local HEADER_H = 34
local PAD_Y = 6
local RADIUS = 6

local menuX, menuY = 260, 180
local hoverMain = 1
local hoverSub = 0
local openSubKey = nil
local focusPane = "main" -- "main" or "sub"
local keyEdges = {}
local lastCursorUnlock = nil

local function setCursorUnlocked(wantUnlock)
    local val = wantUnlock and "1" or "0"
    if lastCursorUnlock == val then return end
    lastCursorUnlock = val
    if Crabe and Crabe.Plugins and Crabe.Plugins.set then
        Crabe.Plugins.set("dev_toolkit.cursor_unlocked", val)
    end
end

local function keyPressed(vk)
    local down = Crabe and Crabe._keyDown and (Crabe._keyDown(vk) == 1) or false
    local prev = keyEdges[vk] or false
    keyEdges[vk] = down
    return down and not prev
end

local function sendCmd(cmdStr)
    if Crabe and Crabe.Plugins and Crabe.Plugins.set then
        Crabe.Plugins.set("dev_toolkit.cmd", cmdStr)
    end
end

local function copyClipboard(text)
    if not text or text == "" then
        State.setStatus("Nothing to copy", "warning")
        return
    end
    if Crabe and Crabe.Plugins and Crabe.Plugins.set then
        Crabe.Plugins.set("dev_toolkit.clipboard", text)
        State.setStatus("Copied to clipboard: " .. text, "success")
    end
end

local function readTelemetry()
    if not (Crabe and Crabe.Plugins and Crabe.Plugins.get) then return {} end
    local raw = Crabe.Plugins.get("dev_toolkit.telemetry") or ""
    if raw == "" then return {} end
    return {
        selHandle = tonumber(raw:match('"selHandle"%s*:%s*([0-9]+)')) or 0,
        selName = raw:match('"selName"%s*:%s*"([^"]*)"') or "",
        rayHit = raw:match('"rayHit"%s*:%s*true') ~= nil,
        rayX = tonumber(raw:match('"rayX"%s*:%s*([%-0-9%.]+)')) or 0,
        rayY = tonumber(raw:match('"rayY"%s*:%s*([%-0-9%.]+)')) or 0,
        rayZ = tonumber(raw:match('"rayZ"%s*:%s*([%-0-9%.]+)')) or 0,
        px = tonumber(raw:match('"x"%s*:%s*([%-0-9%.]+)')) or 0,
        py = tonumber(raw:match('"y"%s*:%s*([%-0-9%.]+)')) or 0,
        pz = tonumber(raw:match('"z"%s*:%s*([%-0-9%.]+)')) or 0,
    }
end

local function readDna()
    if not (Crabe and Crabe.Plugins and Crabe.Plugins.get) then return {} end
    local raw = Crabe.Plugins.get("dev_toolkit.dna") or ""
    if raw == "" or raw == "{}" then return {} end
    return {
        valid = raw:match('"valid"%s*:%s*true') ~= nil,
        handle = tonumber(raw:match('"handle"%s*:%s*([0-9]+)')) or 0,
        name = raw:match('"name"%s*:%s*"([^"]*)"') or "",
        typeName = raw:match('"typeName"%s*:%s*"([^"]*)"') or "",
        creationKey = raw:match('"creationKey"%s*:%s*"([^"]*)"') or "",
        dnaFile = raw:match('"dnaFile"%s*:%s*"([^"]*)"') or "",
        archetype = raw:match('"archetype"%s*:%s*"([^"]*)"') or "",
    }
end

local function activeTargetHandle(telem)
    if telem.selHandle and telem.selHandle > 0 then
        return telem.selHandle
    end
    if State.selectedActor and State.selectedActor.handle and State.selectedActor.handle > 0 then
        return State.selectedActor.handle
    end
    return 0
end

local function closeMenu()
    State.isContextMenuOpen = false
    openSubKey = nil
    hoverMain = 1
    hoverSub = 0
    focusPane = "main"
    keyEdges = {}
    State.applyCapture()
end

local function buildSubmenus(telem, dna)
    local h = activeTargetHandle(telem)
    local hasTarget = h > 0

    return {
        select = {
            { label = "Pick Actor Under Crosshair", action = function() sendCmd("select_ray") end },
            { label = "Pick Nearest Actor", action = function() sendCmd("select_nearest") end },
            { label = "Select Local Avatar", action = function()
                if Game and Game.GetAvatarHandle then
                    local ah = Game.GetAvatarHandle(0)
                    if ah and ah ~= 0 then sendCmd("select_handle:" .. tostring(ah)) end
                end
            end },
            { label = "Clear Selection", action = function()
                State.selectedActor = nil
                sendCmd("select_clear")
            end },
        },
        manip = {
            { label = "Teleport to Crosshair", disabled = not (hasTarget and telem.rayHit), action = function()
                sendCmd(string.format("actor_transform:%d:pos:%.3f,%.3f,%.3f", h, telem.rayX, telem.rayY + 0.5, telem.rayZ))
            end },
            { label = "Lift +2.0m (Y)", disabled = not hasTarget, action = function()
                local s = State.selectedActor or { x = telem.px, y = telem.py, z = telem.pz }
                sendCmd(string.format("actor_transform:%d:pos:%.3f,%.3f,%.3f", h, s.x, s.y + 2.0, s.z))
            end },
            { label = "Rotate Yaw +45 deg", disabled = not hasTarget, action = function()
                sendCmd(string.format("actor_transform:%d:rot:0,45,0", h))
            end },
            { label = "Scale 0.5x", disabled = not hasTarget, action = function() sendCmd(string.format("actor_scale:%d:0.5", h)) end },
            { label = "Scale 2.0x", disabled = not hasTarget, action = function() sendCmd(string.format("actor_scale:%d:2.0", h)) end },
            { label = "Restore Scale (1.0x)", disabled = not hasTarget, action = function() sendCmd(string.format("actor_scale:%d:restore", h)) end },
            { label = "Heal Full", disabled = not hasTarget, action = function() sendCmd(string.format("actor_health:%d:reset:0", h)) end },
            { label = "Damage 25", disabled = not hasTarget, action = function() sendCmd(string.format("actor_health:%d:damage:25", h)) end },
            { label = "Kill Actor", disabled = not hasTarget, action = function() sendCmd(string.format("actor_health:%d:kill:0", h)) end },
            { label = "Destroy Actor", disabled = not hasTarget, action = function() sendCmd(string.format("actor_health:%d:destroy:0", h)) end },
            { label = "Control Selected Actor", disabled = not hasTarget, action = function()
                sendCmd(string.format("actor_control:%d", h))
                closeMenu()
            end },
        },
        visuals = {
            { label = (State.show3DCollisions and "[x] " or "[ ] ") .. "3D Collision Wireframe", keepOpen = true, action = function() State.show3DCollisions = not State.show3DCollisions end },
            { label = (State.show3DAnimRig and "[x] " or "[ ] ") .. "3D Animation Rig", keepOpen = true, action = function() State.show3DAnimRig = not State.show3DAnimRig end },
            { label = (State.show3DSplines and "[x] " or "[ ] ") .. "3D Splines & Rails", keepOpen = true, action = function() State.show3DSplines = not State.show3DSplines end },
            { label = (State.show3DTriggers and "[x] " or "[ ] ") .. "3D Trigger Boxes", keepOpen = true, action = function() State.show3DTriggers = not State.show3DTriggers end },
            { label = (State.isOverlayOpen and "[x] " or "[ ] ") .. "Dev Inspector HUD (F6)", keepOpen = true, action = function() State.toggleOverlay() end },
        },
        fx = {
            { label = "Apply Skin: Hologram", disabled = not hasTarget, action = function() sendCmd(string.format("actor_fx:%d:start:Skin_Hologram", h)) end },
            { label = "Apply Skin: Stealth", disabled = not hasTarget, action = function() sendCmd(string.format("actor_fx:%d:start:Skin_Stealth", h)) end },
            { label = "Apply Skin: Gold", disabled = not hasTarget, action = function() sendCmd(string.format("actor_fx:%d:start:Skin_Gold", h)) end },
            { label = "End Skin: Hologram", disabled = not hasTarget, action = function() sendCmd(string.format("actor_fx:%d:end:Skin_Hologram", h)) end },
            { label = "Kill All FX on Actor", disabled = not hasTarget, action = function() sendCmd(string.format("actor_fx:%d:kill_all:", h)) end },
        },
        dna = {
            { label = "Key: " .. ((dna.creationKey and dna.creationKey ~= "") and dna.creationKey or "(none)"), disabled = not hasTarget, action = function()
                if dna.creationKey and dna.creationKey ~= "" then copyClipboard(dna.creationKey) else sendCmd("inspect_dna:" .. tostring(h)) end
            end },
            { label = "DNA: " .. ((dna.dnaFile and dna.dnaFile ~= "") and dna.dnaFile or "(none)"), disabled = not hasTarget, action = function()
                if dna.dnaFile and dna.dnaFile ~= "" then copyClipboard(dna.dnaFile) else sendCmd("inspect_dna:" .. tostring(h)) end
            end },
            { label = "Copy Handle (" .. tostring(h) .. ")", disabled = not hasTarget, action = function() copyClipboard(tostring(h)) end },
            { label = "Copy World Position", action = function()
                local s = State.selectedActor
                if s then
                    copyClipboard(string.format("%.3f, %.3f, %.3f", s.x, s.y, s.z))
                else
                    copyClipboard(string.format("%.3f, %.3f, %.3f", telem.px, telem.py, telem.pz))
                end
            end },
        },
        time = {
            { label = "Speed 0.1x (Slow-Mo)", action = function() SpeedHack.setSpeed(0.1) end },
            { label = "Speed 0.25x", action = function() SpeedHack.setSpeed(0.25) end },
            { label = "Speed 0.5x", action = function() SpeedHack.setSpeed(0.5) end },
            { label = "Speed 1.0x (Normal)", action = function() SpeedHack.setSpeed(1.0) end },
            { label = "Speed 2.0x", action = function() SpeedHack.setSpeed(2.0) end },
            { label = "Speed 3.0x", action = function() SpeedHack.setSpeed(3.0) end },
            { label = "Toggle Free Camera (F1)", action = function() FreeCam.toggle(); closeMenu() end },
            { label = "Toggle God Mode (F2)", action = function() Cheats.setGodMode(not Cheats.isGodMode()) end },
            { label = "Toggle One-Hit Kills (F3)", action = function() Cheats.setOneShotKill(not Cheats.isOneShotKill()) end },
        },
    }
end

local MAIN_ITEMS = {
    { key = "select", label = "Actor Selection" },
    { key = "manip", label = "Actor Manipulation" },
    { key = "visuals", label = "3D Visualizers & Rig" },
    { key = "fx", label = "Cosmo FX (SkinSwapper)" },
    { key = "dna", label = "DNA Inspector & Copy" },
    { key = "time", label = "Time Control & Cheats" },
}

local function hitTestList(mx, my, x, y, w, count)
    if mx < x or mx > x + w then return 0 end
    local idx = math.floor((my - y) / ROW_H) + 1
    if idx >= 1 and idx <= count then return idx end
    return 0
end

function ContextMenu.update()
    if State.isMenuOpen or State.isTyping then
        if State.isContextMenuOpen then closeMenu() end
        setCursorUnlocked(false)
        return
    end

    local altDown = Crabe and Crabe._keyDown and (Crabe._keyDown(0x12) == 1) or false
    local freeCamOn = FreeCam.isActive()
    setCursorUnlocked(State.isContextMenuOpen or altDown or freeCamOn)

    local openTriggered = Input.contextMenuTriggered()
    local openedViaMouse = false
    if openTriggered then
        openedViaMouse = altDown and Input.mouseRightClicked()
    elseif freeCamOn and Input.mouseRightClicked() and not State.isContextMenuOpen then
        openTriggered = true
        openedViaMouse = true
    end

    if openTriggered then
        if State.isContextMenuOpen then
            closeMenu()
            return
        end
        local screenW, screenH = ImGui.GetDisplaySize()
        if not screenW or screenW <= 0 then screenW, screenH = 1920, 1080 end
        local mx, my = Input.mousePosition()
        menuX = mx or math.floor(screenW * 0.5)
        menuY = my or math.floor(screenH * 0.45)
        menuX = math.max(12, math.min(screenW - MENU_W - 24, menuX))
        menuY = math.max(12, math.min(screenH - (#MAIN_ITEMS * ROW_H + HEADER_H + 24), menuY))
        State.isContextMenuOpen = true
        setCursorUnlocked(true)
        openSubKey = "select"
        hoverMain = 1
        hoverSub = 0
        focusPane = "main"
        keyEdges = {}
        State.applyCapture()
        if openedViaMouse and mx and my then
            sendCmd(string.format("select_ray_screen:%.1f,%.1f,%.1f,%.1f", mx, my, screenW, screenH))
        else
            sendCmd("select_ray")
        end
        return
    end

    if not State.isContextMenuOpen then return end

    if Input.isEscapePressed() then
        closeMenu()
        return
    end

    local telem = readTelemetry()
    local dna = readDna()
    local submenus = buildSubmenus(telem, dna)

    -- Keyboard navigation (works even when the game locks the OS mouse cursor)
    local subList = openSubKey and submenus[openSubKey] or nil
    if keyPressed(0x26) then -- VK_UP
        if focusPane == "sub" and subList and #subList > 0 then
            hoverSub = (hoverSub <= 1) and #subList or (hoverSub - 1)
        else
            hoverMain = (hoverMain <= 1) and #MAIN_ITEMS or (hoverMain - 1)
            openSubKey = MAIN_ITEMS[hoverMain].key
            hoverSub = 0
        end
    elseif keyPressed(0x28) then -- VK_DOWN
        if focusPane == "sub" and subList and #subList > 0 then
            hoverSub = (hoverSub >= #subList) and 1 or (hoverSub + 1)
        else
            hoverMain = (hoverMain >= #MAIN_ITEMS) and 1 or (hoverMain + 1)
            openSubKey = MAIN_ITEMS[hoverMain].key
            hoverSub = 0
        end
    elseif keyPressed(0x27) then -- VK_RIGHT
        if subList and #subList > 0 then
            focusPane = "sub"
            if hoverSub < 1 or hoverSub > #subList then hoverSub = 1 end
        end
    elseif keyPressed(0x25) then -- VK_LEFT
        if focusPane == "sub" then
            focusPane = "main"
            hoverSub = 0
        end
    elseif keyPressed(0x0D) then -- VK_RETURN
        if focusPane == "main" and subList and #subList > 0 then
            focusPane = "sub"
            hoverSub = 1
        elseif focusPane == "sub" and subList and subList[hoverSub] then
            local item = subList[hoverSub]
            if not item.disabled and item.action then
                item.action()
                if not item.keepOpen then
                    closeMenu()
                end
            end
        end
    end

    local mx, my = Input.mousePosition()
    if mx and my then
        local mIdx = hitTestList(mx, my, menuX, menuY + HEADER_H + PAD_Y, MENU_W, #MAIN_ITEMS)
        if mIdx > 0 then
            hoverMain = mIdx
            openSubKey = MAIN_ITEMS[mIdx].key
            focusPane = "main"
        end

        subList = openSubKey and submenus[openSubKey] or nil
        if subList then
            local screenW = select(1, ImGui.GetDisplaySize()) or 1920
            local subX = (menuX + MENU_W + SUB_W + 12 <= screenW) and (menuX + MENU_W + 4) or (menuX - SUB_W - 4)
            local subY = menuY + HEADER_H + ((hoverMain > 0 and hoverMain or 1) - 1) * ROW_H
            local sIdx = hitTestList(mx, my, subX, subY + PAD_Y, SUB_W, #subList)
            if sIdx > 0 then
                hoverSub = sIdx
                focusPane = "sub"
            end
        end

        if Input.mouseLeftClicked() then
            if hoverSub > 0 and subList and subList[hoverSub] then
                local item = subList[hoverSub]
                if not item.disabled and item.action then
                    item.action()
                    if not item.keepOpen then
                        closeMenu()
                    end
                end
            elseif mIdx == 0 and hoverSub == 0 then
                closeMenu()
            end
        end
    end
end

function ContextMenu.render()
    local altDown = Crabe and Crabe._keyDown and (Crabe._keyDown(0x12) == 1) or false
    local showCursorOnly = (not State.isContextMenuOpen) and (not State.isMenuOpen) and (altDown or FreeCam.isActive())
    if showCursorOnly then
        Theme.beginFrame(1, 0, 0, 1)
        local mx, my = Input.mousePosition()
        if mx and my then
            ImGui.DrawRect(mx - 4, my - 4, 8, 8, Theme.color("obsidianText", 240), 4, 0)
            ImGui.DrawRect(mx - 5, my - 5, 10, 10, Theme.color("obsidianBorder", 255), 5, 1)
        end
        return
    end
    if not State.isContextMenuOpen then return end

    local screenW, screenH = ImGui.GetDisplaySize()
    if not screenW or screenW <= 0 then screenW, screenH = 1920, 1080 end
    Theme.beginFrame(1, 0, 0, 1)

    local telem = readTelemetry()
    local dna = readDna()
    local submenus = buildSubmenus(telem, dna)
    local h = activeTargetHandle(telem)
    local title = h > 0
        and string.format("%s (#%d)", (telem.selName ~= "" and telem.selName) or (dna.name ~= "" and dna.name) or "Actor", h)
        or "Dev Context Menu"

    local totalH = HEADER_H + PAD_Y * 2 + #MAIN_ITEMS * ROW_H
    ImGui.DrawRect(menuX, menuY, MENU_W, totalH, Theme.color("obsidianBg", 242), RADIUS, 0)
    ImGui.DrawRect(menuX, menuY, MENU_W, totalH, Theme.color("obsidianBorder", 255), RADIUS, 1)

    ImGui.DrawRect(menuX, menuY, MENU_W, HEADER_H, Theme.color("obsidianSurface", 255), RADIUS, 0)
    if Theme.text then
        Theme.text(menuX + 10, menuY + 9, title, Theme.color("obsidianText", 255), 12)
    end

    for i, item in ipairs(MAIN_ITEMS) do
        local ry = menuY + HEADER_H + PAD_Y + (i - 1) * ROW_H
        local active = (hoverMain == i or openSubKey == item.key)
        if active then
            ImGui.DrawRect(menuX + 4, ry, MENU_W - 8, ROW_H - 2, Theme.color("obsidianHover", 255), 4, 0)
        end
        if Theme.text then
            local col = active and Theme.color("obsidianText", 255) or Theme.color("obsidianMuted", 255)
            Theme.text(menuX + 10, ry + 5, item.label, col, 12)
            Theme.text(menuX + MENU_W - 18, ry + 5, ">", Theme.color("obsidianSubtle", 255), 12)
        end
    end

    local subList = openSubKey and submenus[openSubKey] or nil
    if subList and #subList > 0 then
        local subX = (menuX + MENU_W + SUB_W + 12 <= screenW) and (menuX + MENU_W + 4) or (menuX - SUB_W - 4)
        local subY = math.max(8, math.min(screenH - (#subList * ROW_H + PAD_Y * 2 + 8),
            menuY + HEADER_H + ((hoverMain > 0 and hoverMain or 1) - 1) * ROW_H))
        local subH = PAD_Y * 2 + #subList * ROW_H

        ImGui.DrawRect(subX, subY, SUB_W, subH, Theme.color("obsidianBg", 242), RADIUS, 0)
        ImGui.DrawRect(subX, subY, SUB_W, subH, Theme.color("obsidianBorder", 255), RADIUS, 1)

        for i, subItem in ipairs(subList) do
            local ry = subY + PAD_Y + (i - 1) * ROW_H
            local active = (hoverSub == i and not subItem.disabled)
            if active then
                ImGui.DrawRect(subX + 4, ry, SUB_W - 8, ROW_H - 2, Theme.color("obsidianHover", 255), 4, 0)
            end
            if Theme.text then
                local col = subItem.disabled and Theme.color("obsidianSubtle", 190)
                    or (active and Theme.color("obsidianText", 255) or Theme.color("obsidianMuted", 255))
                Theme.text(subX + 10, ry + 5, subItem.label, col, 12)
            end
        end
    end

    local mx, my = Input.mousePosition()
    if mx and my then
        ImGui.DrawRect(mx - 3, my - 3, 6, 6, Theme.color("obsidianText", 240), 3, 0)
        ImGui.DrawRect(mx - 4, my - 4, 8, 8, Theme.color("obsidianBorder", 255), 4, 1)
    end
end

return ContextMenu
