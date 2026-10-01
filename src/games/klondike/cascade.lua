-- The win cascade: cards leap off the foundations one by one and bounce
-- along the rail, leaving trails, after the old Windows Solitaire.
-- The trails fade slowly so the cloth shows through again.

local Card = require("src.cards.card")

local Cascade = {}
Cascade.__index = Cascade

Cascade.INTERVAL = 0.11   -- seconds between launches
Cascade.GRAVITY = 1500
Cascade.BOUNCE = 0.72

function Cascade.new(foundations, screenW, floorY, scale, seed)
    local self = setmetatable({}, Cascade)
    self.screenW = screenW
    self.floorY = floorY - Card.HEIGHT
    self.scale = scale
    self.rng = love.math.newRandomGenerator(seed or os.time())
    self.queue = {}
    self.active = {}
    self.timer = 0.35
    self.trail = nil
    self.trailClear = true

    -- Kings first, round-robin across the four foundations
    for depth = 13, 1, -1 do
        for _, f in ipairs(foundations) do
            local card = f.cards[depth]
            if card then self.queue[#self.queue + 1] = {card = card, pile = f} end
        end
    end
    self.total = #self.queue
    return self
end

function Cascade:isDone()
    return #self.queue == 0 and #self.active == 0
end

function Cascade:launch(item)
    local card = item.card
    card.hidden = true
    local dir = self.rng:random() < 0.5 and -1 or 1
    -- cards near an edge head back across the table
    if item.pile.x < self.screenW * 0.3 then dir = 1 elseif item.pile.x > self.screenW * 0.7 then dir = -1 end
    self.active[#self.active + 1] = {
        card = card,
        x = item.pile.x, y = item.pile.y,
        vx = dir * (140 + self.rng:random() * 260),
        vy = -(80 + self.rng:random() * 320),
    }
end

function Cascade:update(dt)
    self.timer = self.timer - dt
    while self.timer <= 0 and #self.queue > 0 do
        self:launch(table.remove(self.queue, 1))
        self.timer = self.timer + Cascade.INTERVAL
    end
    for i = #self.active, 1, -1 do
        local p = self.active[i]
        p.vy = p.vy + Cascade.GRAVITY * dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        if p.y > self.floorY then
            p.y = self.floorY
            p.vy = -p.vy * Cascade.BOUNCE
            if math.abs(p.vy) < 60 then p.vy = -260 end
        end
        if p.x < -Card.WIDTH - 4 or p.x > self.screenW + 4 then
            table.remove(self.active, i)
        end
    end
end

-- Stamp the moving cards into the trail, then show it
function Cascade:draw(w, h)
    if not self.trail then
        self.trail = love.graphics.newCanvas(w, h, {dpiscale = self.scale})
    end
    love.graphics.push("all")
    love.graphics.setCanvas(self.trail)
    love.graphics.setScissor()
    love.graphics.origin()
    if self.trailClear then
        love.graphics.clear(0, 0, 0, 0)
        self.trailClear = false
    end
    -- fade what's already there
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(0.975, 0.975, 0.975, 0.975)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setBlendMode("alpha")
    for _, p in ipairs(self.active) do
        p.card:drawAt(p.x, p.y, 1, true)
    end
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.draw(self.trail, 0, 0)
    love.graphics.setBlendMode("alpha")
end

function Cascade:release()
    if self.trail then self.trail:release() self.trail = nil end
end

return Cascade
