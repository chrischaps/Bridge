-- Waste pile for Klondike Solitaire
-- Cards drawn from stock are placed here
-- Only the top card can be moved to tableau or foundation

local Pile = require("src.cards.pile")

local Waste = setmetatable({}, {__index = Pile})
Waste.__index = Waste

-- Spread for showing multiple drawn cards (draw 3 mode)
Waste.SPREAD_X = 22

-- Create a new waste pile
function Waste.new(x, y)
    local self = setmetatable(Pile.new(x, y, "waste"), Waste)
    -- How many of the top cards are fanned out. Set by each draw and
    -- shrinks as fanned cards are played, so buried cards never slide
    -- into the fan (classic Draw 3 behaviour).
    self.fanCount = 0
    return self
end

-- Waste doesn't accept cards from drag/drop
function Waste:canAccept(cards)
    return false
end

-- Only the top card can be picked up
function Waste:canPickUp(index)
    return index == #self.cards and #self.cards > 0
end

-- Add cards drawn from stock
function Waste:addFromStock(cards)
    for _, card in ipairs(cards) do
        card:setFaceUp(true, false)
        table.insert(self.cards, card)
    end
    self.fanCount = #cards
    self:updateCardPositions()
end

-- The top card was taken: the fan shrinks by one
function Waste:onTopTaken()
    self.fanCount = math.max(0, self.fanCount - 1)
    self:updateCardPositions()
end

-- Index of the first fanned card
function Waste:fanStart()
    local fan = math.max(1, math.min(self.fanCount, #self.cards))
    return #self.cards - fan + 1
end

function Waste:cardPosition(i)
    local start = self:fanStart()
    if i >= start then
        return self.x + (i - start) * Waste.SPREAD_X, self.y
    end
    return self.x, self.y
end

-- Only the top card can be selected
function Waste:findCardAtPoint(px, py)
    if #self.cards == 0 then
        return nil, nil
    end
    local Card = require("src.cards.card")
    local cx, cy = self:cardPosition(#self.cards)
    if px >= cx and px <= cx + Card.WIDTH and py >= cy and py <= cy + Card.HEIGHT then
        return #self.cards, self.cards[#self.cards]
    end
    return nil, nil
end

-- Draw the waste: only the card under the fan and the fan itself show
function Waste:draw()
    if #self.cards == 0 then return end
    local first = self:fanStart()
    -- the card beneath the fan peeks out while the fan's base card is lifted away
    local base = first
    while base > 1 and not Pile.isResting(self.cards[base]) do
        base = base - 1
    end
    if base < first and Pile.isResting(self.cards[base]) then
        self.cards[base]:draw()
    end
    self:drawCards(first)
    love.graphics.setColor(1, 1, 1)
end

return Waste
