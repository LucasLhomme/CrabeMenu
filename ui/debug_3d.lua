local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Theme = Loader.load("ui.theme")

local Debug3D = {}

local FALLBACK_WIDTH, FALLBACK_HEIGHT = 1920, 1080
local DEFAULT_FOV_DEG = 60.0
local lastSentModeMask = -1

local function syncDebug3dMode(modeMask)
    if modeMask == lastSentModeMask then return end
    if Crabe and Crabe.Plugins and Crabe.Plugins.set then
        Crabe.Plugins.set("dev_toolkit.debug_3d_mode", tostring(modeMask))
        lastSentModeMask = modeMask
    end
end

local function splitCommaNumbers(str)
    local out = {}
    for tok in str:gmatch("[^,]+") do
        out[#out + 1] = tonumber(tok)
    end
    return out
end

local function splitCommaTokens(str)
    local out = {}
    local idx = 1
    while true do
        local sep = str:find(",", idx, true)
        if not sep then
            out[#out + 1] = str:sub(idx)
            break
        end
        out[#out + 1] = str:sub(idx, sep - 1)
        idx = sep + 1
    end
    return out
end

local function parseDebug3dStream(raw)
    if not raw or raw == "" then return nil end

    local frame = {
        cam = nil,
        act = nil,
        ray = nil,
        aabb = nil,
        cap = nil,
        gnd = nil,
        ceil = nil,
        wat = nil,
        radials = {},
        grid = {},
        splines = {},
        triggers = {},
        sel = nil,
        aitxt = nil,
        rig = nil,
    }

    for rec in raw:gmatch("[^;]+") do
        local tag, rest = rec:match("^([^,]+),(.*)$")
        if tag and rest then
            local v = splitCommaNumbers(rest)
            if tag == "CAM" and #v >= 13 then
                frame.cam = {
                    x = v[1], y = v[2], z = v[3],
                    fx = v[4], fy = v[5], fz = v[6],
                    ux = v[7], uy = v[8], uz = v[9],
                    rx = v[10], ry = v[11], rz = v[12],
                    fov = v[13] or DEFAULT_FOV_DEG,
                }
            elseif tag == "ACT" and #v >= 8 then
                frame.act = {
                    handle = v[1],
                    x = v[2], y = v[3], z = v[4],
                    vx = v[5], vy = v[6], vz = v[7],
                    coordType = v[8],
                }
            elseif tag == "RAY" and #v >= 9 then
                frame.ray = {
                    hit = (v[1] == 1),
                    x = v[2], y = v[3], z = v[4],
                    nx = v[5], ny = v[6], nz = v[7],
                    dist = v[8], surf = v[9],
                }
            elseif tag == "AABB" and #v >= 6 then
                frame.aabb = {
                    cx = v[1], cy = v[2], cz = v[3],
                    sx = v[4], sy = v[5], sz = v[6],
                }
            elseif tag == "CAP" and #v >= 8 then
                frame.cap = {
                    p1 = { v[1], v[2], v[3] },
                    p2 = { v[4], v[5], v[6] },
                    r1 = v[7], r2 = v[8],
                }
            elseif tag == "GND" and #v >= 7 then
                frame.gnd = {
                    x = v[1], y = v[2], z = v[3],
                    nx = v[4], ny = v[5], nz = v[6],
                    dist = v[7],
                }
            elseif tag == "CEIL" and #v >= 7 then
                frame.ceil = {
                    x = v[1], y = v[2], z = v[3],
                    nx = v[4], ny = v[5], nz = v[6],
                    dist = v[7],
                }
            elseif tag == "WAT" and #v >= 6 then
                frame.wat = {
                    x = v[1], y = v[2], z = v[3],
                    nx = v[4], ny = v[5], nz = v[6],
                }
            elseif tag == "RAD" and #v >= 7 then
                frame.radials[#frame.radials + 1] = {
                    hit = (v[1] == 1),
                    ex = v[2], ey = v[3], ez = v[4],
                    nx = v[5], ny = v[6], nz = v[7],
                }
            elseif tag == "GRID" and #v >= 8 then
                local gx, gz = v[1], v[2]
                if not frame.grid[gz] then frame.grid[gz] = {} end
                frame.grid[gz][gx] = { v[3], v[4], v[5], v[6], v[7], v[8] }
            elseif tag == "SPL" and #v >= 10 then
                local nPts = math.floor(v[10] or 0)
                local pts = {}
                local base = 10
                for i = 1, nPts do
                    local idx = base + (i - 1) * 3
                    if v[idx + 3] then
                        pts[#pts + 1] = { v[idx + 1], v[idx + 2], v[idx + 3] }
                    end
                end
                frame.splines[#frame.splines + 1] = {
                    handle = v[1], length = v[2], nearDist = v[3],
                    nearPt = { v[4], v[5], v[6] },
                    nearTan = { v[7], v[8], v[9] },
                    points = pts,
                }
            elseif tag == "TRG" and #v >= 8 then
                frame.triggers[#frame.triggers + 1] = {
                    x = v[1], y = v[2], z = v[3],
                    nx = v[4], ny = v[5], nz = v[6],
                    dist = v[7], objId = v[8],
                }
            elseif tag == "SEL" then
                local t = splitCommaTokens(rest)
                if #t >= 14 then
                    frame.sel = {
                        handle = tonumber(t[1]) or 0,
                        name = t[2] or "",
                        x = tonumber(t[3]) or 0, y = tonumber(t[4]) or 0, z = tonumber(t[5]) or 0,
                        minX = tonumber(t[6]) or 0, minY = tonumber(t[7]) or 0, minZ = tonumber(t[8]) or 0,
                        maxX = tonumber(t[9]) or 0, maxY = tonumber(t[10]) or 0, maxZ = tonumber(t[11]) or 0,
                        fx = tonumber(t[12]) or 0, fy = tonumber(t[13]) or 0, fz = tonumber(t[14]) or 1,
                    }
                end
            elseif tag == "AITXT" then
                local t = splitCommaTokens(rest)
                if #t >= 11 then
                    frame.aitxt = {
                        handle = tonumber(t[1]) or 0,
                        name = t[2] or "",
                        typeName = t[3] or "",
                        hp = tonumber(t[4]) or 0,
                        maxHp = tonumber(t[5]) or 0,
                        alive = (tonumber(t[6]) == 1),
                        speed = tonumber(t[7]) or 0,
                        states = t[8] or "",
                        sx = tonumber(t[9]) or 1, sy = tonumber(t[10]) or 1, sz = tonumber(t[11]) or 1,
                    }
                end
            elseif tag == "RIG" then
                local t = splitCommaTokens(rest)
                local count = tonumber(t[2]) or 0
                local joints = {}
                local idx = 3
                for _ = 1, count do
                    if idx + 4 <= #t then
                        joints[#joints + 1] = {
                            name = t[idx] or "",
                            parent = tonumber(t[idx + 1]) or -1,
                            x = tonumber(t[idx + 2]) or 0,
                            y = tonumber(t[idx + 3]) or 0,
                            z = tonumber(t[idx + 4]) or 0,
                        }
                    end
                    idx = idx + 5
                end
                frame.rig = {
                    handle = tonumber(t[1]) or 0,
                    joints = joints,
                }
            end
        end
    end

    return frame
end

--- Projects a 3D world point (x, y, z) to 2D screen coordinates (sx, sy)
local function worldToScreen(px, py, pz, camX, camY, camZ, fwdX, fwdY, fwdZ, rightX, rightY, rightZ, upX, upY, upZ, w, h, tanHalfFov)
    local dx = px - camX
    local dy = py - camY
    local dz = pz - camZ

    local camZDepth = dx * fwdX + dy * fwdY + dz * fwdZ
    if camZDepth <= 0.2 then return nil, nil end

    local camXPos = dx * rightX + dy * rightY + dz * rightZ
    local camYPos = dx * upX + dy * upY + dz * upZ

    local aspect = w / h
    local ndcX = camXPos / (camZDepth * tanHalfFov * aspect)
    local ndcY = camYPos / (camZDepth * tanHalfFov)

    local sx = (ndcX * 0.5 + 0.5) * w
    local sy = (1.0 - (ndcY * 0.5 + 0.5)) * h
    return sx, sy
end

local function draw3DLine(p1, p2, cam, screenW, screenH, tanHalfFov, color, thickness)
    local sx1, sy1 = worldToScreen(p1[1], p1[2], p1[3], cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz, cam.rx, cam.ry, cam.rz, cam.ux, cam.uy, cam.uz, screenW, screenH, tanHalfFov)
    local sx2, sy2 = worldToScreen(p2[1], p2[2], p2[3], cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz, cam.rx, cam.ry, cam.rz, cam.ux, cam.uy, cam.uz, screenW, screenH, tanHalfFov)

    if sx1 and sx2 then
        Theme.line(sx1, sy1, sx2, sy2, color, thickness or 2)
    end
end

local function draw3DCross(p, size, cam, screenW, screenH, tanHalfFov, color, thickness)
    draw3DLine({ p[1] - size, p[2], p[3] }, { p[1] + size, p[2], p[3] }, cam, screenW, screenH, tanHalfFov, color, thickness)
    draw3DLine({ p[1], p[2] - size, p[3] }, { p[1], p[2] + size, p[3] }, cam, screenW, screenH, tanHalfFov, color, thickness)
    draw3DLine({ p[1], p[2], p[3] - size }, { p[1], p[2], p[3] + size }, cam, screenW, screenH, tanHalfFov, color, thickness)
end

local function draw3DBox(minP, maxP, cam, screenW, screenH, tanHalfFov, color, thickness)
    local c = {
        { minP[1], minP[2], minP[3] },
        { maxP[1], minP[2], minP[3] },
        { maxP[1], maxP[2], minP[3] },
        { minP[1], maxP[2], minP[3] },
        { minP[1], minP[2], maxP[3] },
        { maxP[1], minP[2], maxP[3] },
        { maxP[1], maxP[2], maxP[3] },
        { minP[1], maxP[2], maxP[3] },
    }
    local edges = {
        {1,2}, {2,3}, {3,4}, {4,1},
        {5,6}, {6,7}, {7,8}, {8,5},
        {1,5}, {2,6}, {3,7}, {4,8}
    }
    for _, edge in ipairs(edges) do
        draw3DLine(c[edge[1]], c[edge[2]], cam, screenW, screenH, tanHalfFov, color, thickness)
    end
end

local function draw3DCapsule(p1, p2, r1, r2, cam, screenW, screenH, tanHalfFov, color, thickness)
    local ax, ay, az = p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]
    local len = math.sqrt(ax * ax + ay * ay + az * az)
    if len < 0.001 then
        ax, ay, az = 0, 1, 0
    else
        ax, ay, az = ax / len, ay / len, az / len
    end

    local refX, refY, refZ = 0, 1, 0
    if math.abs(ay) > 0.9 then refX, refY, refZ = 1, 0, 0 end

    local uX = ay * refZ - az * refY
    local uY = az * refX - ax * refZ
    local uZ = ax * refY - ay * refX
    local uLen = math.sqrt(uX * uX + uY * uY + uZ * uZ)
    if uLen < 0.001 then uLen = 1.0 end
    uX, uY, uZ = uX / uLen, uY / uLen, uZ / uLen

    local vX = ay * uZ - az * uY
    local vY = az * uX - ax * uZ
    local vZ = ax * uY - ay * uX

    local segs = 12
    local ring1, ring2 = {}, {}
    for i = 1, segs do
        local ang = ((i - 1) / segs) * math.pi * 2.0
        local ca, sa = math.cos(ang), math.sin(ang)
        local ox = uX * ca + vX * sa
        local oy = uY * ca + vY * sa
        local oz = uZ * ca + vZ * sa
        ring1[i] = { p1[1] + ox * r1, p1[2] + oy * r1, p1[3] + oz * r1 }
        ring2[i] = { p2[1] + ox * r2, p2[2] + oy * r2, p2[3] + oz * r2 }
    end

    for i = 1, segs do
        local nxt = (i % segs) + 1
        draw3DLine(ring1[i], ring1[nxt], cam, screenW, screenH, tanHalfFov, color, thickness)
        draw3DLine(ring2[i], ring2[nxt], cam, screenW, screenH, tanHalfFov, color, thickness)
    end
    for _, idx in ipairs({ 1, 4, 7, 10 }) do
        draw3DLine(ring1[idx], ring2[idx], cam, screenW, screenH, tanHalfFov, color, thickness)
    end
end

local function normalizeCam(cam)
    local rMag = cam.rx * cam.rx + cam.ry * cam.ry + cam.rz * cam.rz
    if rMag > 0.01 then return cam end

    local fX, fY, fZ = cam.fx, cam.fy, cam.fz
    local fLen = math.sqrt(fX * fX + fY * fY + fZ * fZ)
    if fLen < 0.001 then return nil end
    fX, fY, fZ = fX / fLen, fY / fLen, fZ / fLen

    local rx, ry, rz = -fZ, 0.0, fX
    local rLen = math.sqrt(rx * rx + rz * rz)
    if rLen < 0.001 then rx, rz = 1.0, 0.0; rLen = 1.0 end
    rx, rz = rx / rLen, rz / rLen

    local ux = ry * fZ - rz * fY
    local uy = rz * fX - rx * fZ
    local uz = rx * fY - ry * fX
    return {
        x = cam.x, y = cam.y, z = cam.z,
        fx = fX, fy = fY, fz = fZ,
        rx = rx, ry = ry, rz = rz,
        ux = ux, uy = uy, uz = uz,
        fov = cam.fov or DEFAULT_FOV_DEG,
    }
end

--- Returns the camera of this very frame, read from the engine, with the plugin snapshot's field of view.
--- The plugin publishes its snapshot from a worker thread, so drawing with it made boxes trail the view.
local function liveCamera(snapshot)
    if not (Crabe and Crabe.callNative and Crabe.hostPlayer) then return snapshot end
    local player = Crabe.hostPlayer()
    local okEye, ex, ey, ez = Crabe.callNative("CameraGetPosition", player)
    local okDir, dx, dy, dz = Crabe.callNative("CameraGetFacingVector", player)
    if not (okEye and okDir and ex and dx) then return snapshot end
    return { x = ex, y = ey, z = ez, fx = dx, fy = dy, fz = dz, rx = 0, ry = 0, rz = 0, fov = snapshot.fov }
end

--- Moves the snapshot's selection box to where the actor is this frame.
local function liveSelection(s)
    if not (Game and Game.ActorPosition and s.handle and s.handle > 0) then return s end
    local x, y, z = Game.ActorPosition(s.handle)
    if not (x and s.x) then return s end
    local dx, dy, dz = x - s.x, y - s.y, z - s.z
    local moved = {}
    for k, v in pairs(s) do moved[k] = v end
    moved.x, moved.y, moved.z = x, y, z
    moved.minX, moved.minY, moved.minZ = s.minX + dx, s.minY + dy, s.minZ + dz
    moved.maxX, moved.maxY, moved.maxZ = s.maxX + dx, s.maxY + dy, s.maxZ + dz
    return moved
end

function Debug3D.render()
    local modeMask = (State.show3DCollisions and 1 or 0)
        + (State.show3DSplines and 2 or 0)
        + (State.show3DTriggers and 4 or 0)
        + (State.show3DAnimRig and 8 or 0)
    syncDebug3dMode(modeMask)

    if not (Crabe and Crabe.Plugins and Crabe.Plugins.get) then
        return
    end

    local rawStream = Crabe.Plugins.get("dev_toolkit.debug_3d")
    if modeMask == 0 and (not rawStream or rawStream == "" or (not rawStream:find("SEL,", 1, true) and not rawStream:find("AITXT,", 1, true))) then
        return
    end

    local screenW, screenH = ImGui.GetDisplaySize()
    if not screenW or screenW <= 0 then screenW, screenH = FALLBACK_WIDTH, FALLBACK_HEIGHT end
    Theme.beginFrame(1, 0, 0, 1)

    local frame = parseDebug3dStream(rawStream)
    if not frame or not frame.cam then return end

    local cam = normalizeCam(liveCamera(frame.cam))
    if not cam then return end

    local tanHalfFov = math.tan(math.rad(cam.fov or DEFAULT_FOV_DEG) * 0.5)

    -- Always draw crosshair ray hit reticle & editor snap placement preview when valid
    if frame.ray and frame.ray.hit then
        local r = frame.ray
        State.lastRayHit = { x = r.x, y = r.y, z = r.z, nx = r.nx, ny = r.ny, nz = r.nz, dist = r.dist, surf = r.surf }
        draw3DCross({ r.x, r.y, r.z }, 0.35, cam, screenW, screenH, tanHalfFov, Theme.color("gold", 230), 2)
        draw3DLine({ r.x, r.y, r.z }, { r.x + r.nx * 0.85, r.y + r.ny * 0.85, r.z + r.nz * 0.85 },
                   cam, screenW, screenH, tanHalfFov, Theme.color("white", 220), 2)

        if State.isEditorMode then
            local px, py, pz = r.x, r.y, r.z
            local snap = tonumber(State.editorSnapGrid) or 0
            if snap > 0 then
                px = math.floor((px / snap) + 0.5) * snap
                py = math.floor((py / snap) + 0.5) * snap
                pz = math.floor((pz / snap) + 0.5) * snap
            end
            draw3DBox({ px - 0.6, py, pz - 0.6 }, { px + 0.6, py + 1.2, pz + 0.6 },
                      cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 220), 2)
        end
    end

    -- 1. Real Octane Collisions (AABB, Capsule, Ground/Ceiling/Water rays, 16x Radial fan, 5x5 Terrain Grid)
    if State.show3DCollisions then
        if frame.aabb then
            local b = frame.aabb
            local hx, hy, hz = math.abs(b.sx) * 0.5, math.abs(b.sy) * 0.5, math.abs(b.sz) * 0.5
            draw3DBox({ b.cx - hx, b.cy - hy, b.cz - hz }, { b.cx + hx, b.cy + hy, b.cz + hz },
                      cam, screenW, screenH, tanHalfFov, Theme.color("green", 230), 2)
        end

        if frame.cap then
            local cap = frame.cap
            draw3DCapsule(cap.p1, cap.p2, cap.r1, cap.r2, cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 210), 2)
        end

        local ax = frame.act and frame.act.x or cam.x
        local ay = frame.act and frame.act.y or cam.y
        local az = frame.act and frame.act.z or cam.z

        if frame.gnd then
            local g = frame.gnd
            draw3DLine({ ax, ay + 0.5, az }, { g.x, g.y, g.z }, cam, screenW, screenH, tanHalfFov, Theme.color("green", 220), 2)
            draw3DCross({ g.x, g.y, g.z }, 0.25, cam, screenW, screenH, tanHalfFov, Theme.color("gold", 230), 2)
            draw3DLine({ g.x, g.y, g.z }, { g.x + g.nx * 0.8, g.y + g.ny * 0.8, g.z + g.nz * 0.8 },
                       cam, screenW, screenH, tanHalfFov, Theme.color("white", 220), 2)
        end

        if frame.ceil then
            local c = frame.ceil
            draw3DLine({ ax, ay + 0.5, az }, { c.x, c.y, c.z }, cam, screenW, screenH, tanHalfFov, Theme.color("gold", 210), 2)
            draw3DCross({ c.x, c.y, c.z }, 0.25, cam, screenW, screenH, tanHalfFov, Theme.color("gold", 230), 2)
        end

        if frame.wat then
            local w = frame.wat
            draw3DCross({ w.x, w.y, w.z }, 0.6, cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 220), 2)
            draw3DBox({ w.x - 1.5, w.y - 0.02, w.z - 1.5 }, { w.x + 1.5, w.y + 0.02, w.z + 1.5 },
                      cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 160), 1)
        end

        local radOrigin = { ax, ay + 0.6, az }
        for _, rad in ipairs(frame.radials) do
            local color = rad.hit and Theme.color("red", 220) or Theme.color("green", 110)
            local endPt = { rad.ex, rad.ey, rad.ez }
            draw3DLine(radOrigin, endPt, cam, screenW, screenH, tanHalfFov, color, rad.hit and 2 or 1)
            if rad.hit then
                draw3DLine(endPt, { endPt[1] + rad.nx * 0.6, endPt[2] + rad.ny * 0.6, endPt[3] + rad.nz * 0.6 },
                           cam, screenW, screenH, tanHalfFov, Theme.color("gold", 220), 2)
            end
        end

        for gz = -2, 2 do
            local row = frame.grid[gz]
            if row then
                for gx = -2, 2 do
                    local p = row[gx]
                    if p then
                        local rightP = row[gx + 1]
                        local fwdP = frame.grid[gz + 1] and frame.grid[gz + 1][gx] or nil
                        if rightP then
                            draw3DLine(p, rightP, cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 150), 1)
                        end
                        if fwdP then
                            draw3DLine(p, fwdP, cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 150), 1)
                        end
                    end
                end
            end
        end
    end

    -- 2. Real Engine CurveBSpline Curves, Nearest Point & Tangents
    if State.show3DSplines then
        for _, sp in ipairs(frame.splines) do
            for i = 2, #sp.points do
                draw3DLine(sp.points[i - 1], sp.points[i], cam, screenW, screenH, tanHalfFov, Theme.color("gold", 240), 3)
            end
            draw3DCross(sp.nearPt, 0.35, cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 240), 2)
            draw3DLine(sp.nearPt,
                       { sp.nearPt[1] + sp.nearTan[1] * 2.0, sp.nearPt[2] + sp.nearTan[2] * 2.0, sp.nearPt[3] + sp.nearTan[3] * 2.0 },
                       cam, screenW, screenH, tanHalfFov, Theme.color("white", 230), 2)

            local sx, sy = worldToScreen(sp.nearPt[1], sp.nearPt[2] + 0.6, sp.nearPt[3],
                                         cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz,
                                         cam.rx, cam.ry, cam.rz, cam.ux, cam.uy, cam.uz,
                                         screenW, screenH, tanHalfFov)
            if sx and sy and Theme.text then
                Theme.text(sx, sy, string.format("SPL 0x%X (%.1fm)", sp.handle, sp.length), Theme.color("gold", 240), 11)
            end
        end
    end

    -- 3. Real Trigger Volumes & Contacts
    if State.show3DTriggers then
        for _, t in ipairs(frame.triggers) do
            local p = { t.x, t.y, t.z }
            draw3DBox({ t.x - 0.35, t.y - 0.35, t.z - 0.35 }, { t.x + 0.35, t.y + 0.35, t.z + 0.35 },
                      cam, screenW, screenH, tanHalfFov, Theme.color("violet", 220), 2)
            draw3DLine(p, { t.x + t.nx * 1.1, t.y + t.ny * 1.1, t.z + t.nz * 1.1 },
                       cam, screenW, screenH, tanHalfFov, Theme.color("gold", 220), 2)
            local sx, sy = worldToScreen(t.x, t.y + 0.5, t.z,
                                         cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz,
                                         cam.rx, cam.ry, cam.rz, cam.ux, cam.uy, cam.uz,
                                         screenW, screenH, tanHalfFov)
            if sx and sy and Theme.text then
                Theme.text(sx, sy, string.format("TRG #%d (%.1fm)", t.objId or 0, t.dist or 0), Theme.color("violet", 240), 11)
            end
        end
    end

    -- 4. Selected Actor Highlight & Floating AI Debug Text (Dark Obsidian)
    if frame.sel then
        local s = liveSelection(frame.sel)
        State.selectedActor = s
        draw3DBox({ s.minX, s.minY, s.minZ }, { s.maxX, s.maxY, s.maxZ },
                  cam, screenW, screenH, tanHalfFov, Theme.color("gold", 230), 2)
        draw3DLine({ s.x, s.y + 0.8, s.z }, { s.x + s.fx * 1.4, s.y + 0.8 + s.fy * 1.4, s.z + s.fz * 1.4 },
                   cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 240), 2)

        if frame.aitxt and Theme.text then
            local a = frame.aitxt
            local sx, sy = worldToScreen(s.x, s.maxY + 0.45, s.z,
                                         cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz,
                                         cam.rx, cam.ry, cam.rz, cam.ux, cam.uy, cam.uz,
                                         screenW, screenH, tanHalfFov)
            if sx and sy then
                local panelW, panelH = 215, 76
                local px = math.max(8, math.min(screenW - panelW - 8, sx - panelW * 0.5))
                local py = math.max(8, math.min(screenH - panelH - 8, sy - panelH))
                ImGui.DrawRect(px, py, panelW, panelH, Theme.color("obsidianBg", 235), 6, 0)
                ImGui.DrawRect(px, py, panelW, panelH, Theme.color("obsidianBorder", 255), 6, 1)
                Theme.text(px + 8, py + 6, string.format("%s (#%d)", a.name ~= "" and a.name or "Actor", a.handle), Theme.color("obsidianText", 255), 12)
                Theme.text(px + 8, py + 22, string.format("Type: %s | Spd: %.2f m/s", a.typeName ~= "" and a.typeName or "?", a.speed), Theme.color("obsidianMuted", 255), 11)
                Theme.text(px + 8, py + 37, string.format("HP: %.0f / %.0f | Scale: %.2fx", a.hp, a.maxHp, a.sx), Theme.color(a.alive and "green" or "red", 240), 11)
                Theme.text(px + 8, py + 53, string.format("State: %s", a.states), Theme.color("gold", 230), 11)
            end
        end
    end

    -- 5. 3D Animation Rig / Locators Skeleton
    if State.show3DAnimRig and frame.rig and frame.rig.joints then
        local joints = frame.rig.joints
        for i, j in ipairs(joints) do
            if j.parent >= 0 and joints[j.parent + 1] then
                local p = joints[j.parent + 1]
                draw3DLine({ p.x, p.y, p.z }, { j.x, j.y, j.z },
                           cam, screenW, screenH, tanHalfFov, Theme.color("cyan", 220), 2)
            end
            draw3DCross({ j.x, j.y, j.z }, 0.06, cam, screenW, screenH, tanHalfFov, Theme.color("gold", 240), 2)
            if i <= 10 and Theme.text then
                local sx, sy = worldToScreen(j.x, j.y + 0.08, j.z,
                                             cam.x, cam.y, cam.z, cam.fx, cam.fy, cam.fz,
                                             cam.rx, cam.ry, cam.rz, cam.ux, cam.uy, cam.uz,
                                             screenW, screenH, tanHalfFov)
                if sx and sy then
                    Theme.text(sx, sy, j.name, Theme.color("obsidianText", 220), 10)
                end
            end
        end
    end
end

return Debug3D
