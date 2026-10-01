-- The card table: burgundy baize under a warm lamp.
-- Painted once into a canvas at the window's real scale.

local Theme = require("src.ui.theme")

local Table = {}

local canvas, canvasScale = nil, nil
local grain = nil

-- Fibrous noise: mostly fine speckle, with short horizontal strands
local function makeGrain()
    local size = 256
    local data = love.image.newImageData(size, size)
    local rng = love.math.newRandomGenerator(1911)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local n = rng:random()
            local v = n > 0.5 and 1 or 0
            data:setPixel(x, y, v, v, v, math.abs(n - 0.5) * 0.16)
        end
    end
    for _ = 1, 900 do
        local x, y = rng:random(0, size - 1), rng:random(0, size - 1)
        local len = rng:random(3, 9)
        local v = rng:random() > 0.5 and 1 or 0
        for i = 0, len - 1 do
            local px = (x + i) % size
            local py = (y + math.floor(i * (rng:random() - 0.5) * 0.6)) % size
            data:setPixel(px, py, v, v, v, 0.10)
        end
    end
    local img = love.graphics.newImage(data)
    img:setWrap("repeat", "repeat")
    return img
end

-- Radial gradient mesh: colour stops {radius 0..1, {r,g,b,a}}
local function radial(cx, cy, rx, ry, stops, segments)
    segments = segments or 64
    local verts = {}
    for s = 1, #stops - 1 do
        local r1, c1 = stops[s][1], stops[s][2]
        local r2, c2 = stops[s + 1][1], stops[s + 1][2]
        for i = 0, segments - 1 do
            local a1 = i / segments * math.pi * 2
            local a2 = (i + 1) / segments * math.pi * 2
            local function v(r, a, c)
                return {cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r, 0, 0, c[1], c[2], c[3], c[4] or 1}
            end
            verts[#verts + 1] = v(r1, a1, c1)
            verts[#verts + 1] = v(r2, a1, c2)
            verts[#verts + 1] = v(r2, a2, c2)
            verts[#verts + 1] = v(r1, a1, c1)
            verts[#verts + 1] = v(r2, a2, c2)
            verts[#verts + 1] = v(r1, a2, c1)
        end
    end
    return love.graphics.newMesh(verts, "triangles", "static")
end

local function paint(w, h)
    local C = Theme.colors
    Theme.setColor(C.feltEdge)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- the lamp pool: lighter in the middle, falling off to the edges
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(radial(w / 2, h * 0.42, w * 0.78, h * 1.05, {
        {0, C.feltCenter}, {0.45, C.feltMid}, {1, C.feltEdge},
    }))

    -- baize grain
    grain = grain or makeGrain()
    local quad = love.graphics.newQuad(0, 0, w * 2, h * 2, 256, 256)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.draw(grain, quad, 0, 0, 0, 0.5, 0.5)

    -- warm light from above
    love.graphics.setBlendMode("add")
    love.graphics.draw(radial(w / 2, h * 0.3, w * 0.45, h * 0.55, {
        {0, {0.22, 0.12, 0.05, 1}}, {0.6, {0.07, 0.03, 0.01, 1}}, {1, {0, 0, 0, 1}},
    }))
    love.graphics.setBlendMode("alpha")

    -- vignette
    love.graphics.draw(radial(w / 2, h / 2, w * 0.75, h * 0.85, {
        {0, {0, 0, 0, 0}}, {0.7, {0, 0, 0, 0.12}}, {1, {0.02, 0, 0, 0.55}},
    }))
end

-- Draw the table, repainting if the scale changed
function Table.draw(w, h, scale)
    if not canvas or canvasScale ~= scale then
        if canvas then canvas:release() end
        canvas = love.graphics.newCanvas(w, h, {dpiscale = scale})
        canvasScale = scale
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.setScissor()
        love.graphics.origin()
        paint(w, h)
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
end

return Table
