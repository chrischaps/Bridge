-- Things drawn on the cloth around the cards: empty-pile frames, the gold
-- glow on valid drop targets, and hint pulses

local Card = require("src.cards.card")
local Theme = require("src.ui.theme")

local Decor = {}

-- A soft glow: stacked strokes fading outward
local function glow(x, y, w, h, strength, color)
    color = color or Theme.colors.brassLight
    local r = Card.CORNER_RADIUS
    for i = 6, 1, -1 do
        local a = strength * (0.05 + 0.6 * (1 - i / 6) ^ 2)
        love.graphics.setColor(color[1], color[2], color[3], a)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - i, y - i, w + i * 2, h + i * 2, r + i, r + i)
    end
end
Decor.glow = glow

-- Engraved brass frame where a pile sits empty
local function slot(x, y, letter, alpha)
    local C = Theme.colors
    local w, h, r = Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS
    alpha = alpha or 1
    love.graphics.setColor(0, 0, 0, 0.16 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, r, r)
    -- inset shading: dark top-left, light bottom-right
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0, 0, 0.25 * alpha)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r)
    Theme.setColor(C.brass, 0.38 * alpha)
    love.graphics.rectangle("line", x + 1.5, y + 1.5, w - 3, h - 3, r - 1, r - 1)
    Theme.setColor(C.brass, 0.16 * alpha)
    love.graphics.rectangle("line", x + 5, y + 5, w - 10, h - 10, r - 3, r - 3)
    -- tiny corner diamonds
    Theme.setColor(C.brass, 0.3 * alpha)
    for _, p in ipairs({{x + 9, y + 9}, {x + w - 9, y + 9}, {x + 9, y + h - 9}, {x + w - 9, y + h - 9}}) do
        love.graphics.polygon("fill", p[1], p[2] - 2, p[1] + 1.4, p[2], p[1], p[2] + 2, p[1] - 1.4, p[2])
    end
    if letter then
        local font = Theme.font("slot")
        love.graphics.setFont(font)
        Theme.setColor(C.brass, 0.26 * alpha)
        love.graphics.print(letter, math.floor(x + (w - font:getWidth(letter)) / 2),
            math.floor(y + (h - font:getHeight()) / 2))
    end
end
Decor.slot = slot

-- The recycle mark on an empty stock
local function recycleMark(x, y, active)
    local C = Theme.colors
    local cx, cy, r = x + Card.WIDTH / 2, y + Card.HEIGHT / 2, 14
    Theme.setColor(C.brass, active and 0.6 or 0.2)
    love.graphics.setLineWidth(2.5)
    if active then
        love.graphics.arc("line", "open", cx, cy, r, -math.pi * 0.55, math.pi * 1.2, 32)
        local a = -math.pi * 0.55
        local ax, ay = cx + math.cos(a) * r, cy + math.sin(a) * r
        love.graphics.polygon("fill", ax + 6, ay, ax - 3, ay - 5.5, ax - 3, ay + 5.5)
    else
        love.graphics.line(cx - 7, cy - 7, cx + 7, cy + 7)
        love.graphics.line(cx + 7, cy - 7, cx - 7, cy + 7)
    end
end

-- Frames under every pile (cards cover them when present)
function Decor.drawSlots(game)
    slot(game.stock.x, game.stock.y, nil, 1)
    if game.stock:isEmpty() then
        recycleMark(game.stock.x, game.stock.y, not game.waste:isEmpty())
    end
    slot(game.waste.x, game.waste.y, nil, 0.6)
    for _, f in ipairs(game.foundations) do slot(f.x, f.y, "A") end
    for _, t in ipairs(game.tableaus) do slot(t.x, t.y, "K", 0.8) end
end

-- Landing spot of a pile (its top card, or the empty frame)
local function landing(pile)
    if pile.kind == "tableau" and not pile:isEmpty() then
        local x, y = pile:cardPosition(pile:count())
        return x, y, Card.WIDTH, Card.HEIGHT
    end
    return pile.x, pile.y, Card.WIDTH, Card.HEIGHT
end

-- Gold glow on every valid target while dragging; the one the cards would
-- land on burns brighter
function Decor.drawDropGlows(game, time)
    if not game.drag then return end
    local best = game:findDropTarget()
    for _, pile in ipairs(game:dropTargets()) do
        local x, y, w, h = landing(pile)
        local s = pile == best and (0.9 + 0.1 * math.sin(time * 6)) or 0.38
        glow(x, y, w, h, s)
    end
end

-- Pulse the hinted card(s) and where they should go
function Decor.drawHint(game)
    local hint = game.hint
    if not hint then return end
    local t = hint.time
    local s = math.max(0, math.sin(t * math.pi * 1.6)) * math.min(1, (2.4 - t) * 2)
    local m = hint.move
    if m.draw then
        glow(game.stock.x, game.stock.y, Card.WIDTH, Card.HEIGHT, s)
        return
    end
    local first = m.from:getCardAt(m.index)
    local last = m.from:getTopCard()
    if first and last then
        glow(first.x, first.y, Card.WIDTH, (last.y - first.y) + Card.HEIGHT, s)
    end
    local x, y, w, h = landing(m.to)
    glow(x, y, w, h, s * 0.8)
end

return Decor
