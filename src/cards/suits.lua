-- Suit shapes built from smooth Bezier outlines.
--
-- LOVE's polygon fill only handles convex shapes, which is why the old hearts
-- and spades came out as crowns. Here each outline is traced with Bezier
-- curves, triangulated once, and kept as a Mesh in a -1..1 box (y down).

local Suits = {}

local meshes = {}

-- Sample a chain of cubic segments into a flat point list.
-- segs: { {x0,y0, c1x,c1y, c2x,c2y, x1,y1}, ... } joined end to start
local function trace(segs, depth)
    local pts = {}
    for _, s in ipairs(segs) do
        local curve = love.math.newBezierCurve(s)
        local r = curve:render(depth or 4)
        -- skip each segment's first point; it repeats the previous end
        local start = 1
        for i = start, #r, 2 do
            local n = #pts
            if n < 2 or math.abs(pts[n - 1] - r[i]) > 1e-6 or math.abs(pts[n] - r[i + 1]) > 1e-6 then
                pts[n + 1], pts[n + 2] = r[i], r[i + 1]
            end
        end
    end
    -- closed shapes end where they start
    local n = #pts
    if n > 4 and math.abs(pts[1] - pts[n - 1]) < 1e-6 and math.abs(pts[2] - pts[n]) < 1e-6 then
        pts[n], pts[n - 1] = nil, nil
    end
    return pts
end

-- Mirror a right-half chain (running from bottom centre to top centre)
-- into a closed, symmetric outline
local function mirrored(rightSegs)
    local segs = {}
    for _, s in ipairs(rightSegs) do segs[#segs + 1] = s end
    for i = #rightSegs, 1, -1 do
        local s = rightSegs[i]
        segs[#segs + 1] = {-s[7], s[8], -s[5], s[6], -s[3], s[4], -s[1], s[2]}
    end
    return segs
end

local function addPolygon(tris, pts)
    local ok, result = pcall(love.math.triangulate, pts)
    if not ok then
        print("suits: triangulation failed: " .. tostring(result))
        return
    end
    for _, t in ipairs(result) do tris[#tris + 1] = t end
end

local function addCircle(tris, cx, cy, r, segments)
    segments = segments or 28
    for i = 0, segments - 1 do
        local a1 = i / segments * math.pi * 2
        local a2 = (i + 1) / segments * math.pi * 2
        tris[#tris + 1] = {cx, cy, cx + math.cos(a1) * r, cy + math.sin(a1) * r,
                           cx + math.cos(a2) * r, cy + math.sin(a2) * r}
    end
end

-- A slender stem flaring out into a foot (spades and clubs): concave sides
-- traced as quadratic curves from the neck down to the foot corners
local function stem(tris, topY, footY, footHalf)
    local right = love.math.newBezierCurve(0.06, topY, 0.09, footY - 0.12, footHalf, footY):render(4)
    local pts = {}
    for i = 1, #right, 2 do pts[#pts + 1] = right[i]; pts[#pts + 1] = right[i + 1] end
    for i = #right - 1, 1, -2 do pts[#pts + 1] = -right[i]; pts[#pts + 1] = right[i + 1] end
    addPolygon(tris, pts)
end

local builders = {}

function builders.hearts(tris)
    addPolygon(tris, trace(mirrored({
        {0, 0.92, 0.32, 0.58, 0.98, 0.12, 0.96, -0.36},
        {0.96, -0.36, 0.94, -0.86, 0.3, -1.02, 0, -0.56},
    })))
end

function builders.diamonds(tris)
    local k = 0.12 -- how far the sides bow inward
    addPolygon(tris, trace({
        {0, -1, 0.24 - k, -0.62, 0.48 - k * 0.6, -0.3, 0.74, 0},
        {0.74, 0, 0.48 - k * 0.6, 0.3, 0.24 - k, 0.62, 0, 1},
        {0, 1, -0.24 + k, 0.62, -0.48 + k * 0.6, 0.3, -0.74, 0},
        {-0.74, 0, -0.48 + k * 0.6, -0.3, -0.24 + k, -0.62, 0, -1},
    }))
end

function builders.spades(tris)
    -- an upturned heart for the blade
    addPolygon(tris, trace(mirrored({
        {0, 0.4, 0.3, 0.86, 1.0, 0.68, 0.96, 0.18},
        {0.96, 0.18, 0.92, -0.26, 0.36, -0.52, 0, -1},
    })))
    stem(tris, 0.3, 0.98, 0.42)
end

function builders.clubs(tris)
    addCircle(tris, 0, -0.5, 0.36)
    addCircle(tris, -0.46, 0.1, 0.36)
    addCircle(tris, 0.46, 0.1, 0.36)
    addCircle(tris, 0, 0.0, 0.24)
    stem(tris, 0.05, 0.98, 0.4)
end

local function build(suit)
    local tris = {}
    builders[suit](tris)
    local verts = {}
    for _, t in ipairs(tris) do
        for i = 1, 6, 2 do verts[#verts + 1] = {t[i], t[i + 1]} end
    end
    return love.graphics.newMesh({{"VertexPosition", "float", 2}}, verts, "triangles", "static")
end

-- Draw a suit centred at (x, y), `size` virtual px tall, in the current colour
function Suits.draw(suit, x, y, size, rotation)
    local mesh = meshes[suit]
    if not mesh then
        mesh = build(suit)
        meshes[suit] = mesh
    end
    local s = size / 2
    love.graphics.draw(mesh, x, y, rotation or 0, s, s)
end

return Suits
