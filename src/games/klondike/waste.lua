-- Waste pile for Klondike Solitaire
-- Cards drawn from stock are placed here
-- Only the top card can be moved to tableau or foundation

local Pile = require("src.cards.pile")
local Card = require("src.cards.card")

local Waste = setmetatable({}, {__index = Pile})
Waste.__index = Waste

-- Spread for showing multiple drawn cards (draw 3 mode)
Waste.SPREAD_X = 20

-- Create a new waste pile
function Waste.new(x, y)
    local self = setmetatable(Pile.new(x, y), Waste)
    self.spreadX = 0
    self.spreadY = 0
    self.visibleCount = 1  -- How many cards are visible (1 or 3)
    return self
end

-- Set how many cards are visible (for draw 1 vs draw 3)
function Waste:setVisibleCount(count)
    self.visibleCount = count
    self:updateCardPositions()
end

-- Waste doesn't accept cards from drag/drop
function Waste:canAccept(cards)
    return false
end

-- Only the top card can be picked up
function Waste:canPickUp(index)
    return index == #self.cards and #self.cards > 0
end

-- Add cards from stock
function Waste:addFromStock(cards)
    for _, card in ipairs(cards) do
        card:setFaceUp(true, false)
        table.insert(self.cards, card)
    end
    self:updateCardPositions()
end

-- Get all cards (for resetting stock)
function Waste:getAllCards()
    local cards = {}
    for _, card in ipairs(self.cards) do
        table.insert(cards, card)
    end
    return cards
end

-- Update card positions with spread for visible cards
function Waste:updateCardPositions(immediate)
    local visibleStart = math.max(1, #self.cards - self.visibleCount + 1)

    for i, card in ipairs(self.cards) do
        local targetX = self.x
        local targetY = self.y
        card.zIndex = i

        -- Spread visible cards
        if i >= visibleStart then
            local visibleIndex = i - visibleStart
            targetX = self.x + visibleIndex * Waste.SPREAD_X
        end

        card:moveTo(targetX, targetY, immediate)
    end
end

-- Draw the waste pile
function Waste:draw(excludeFromIndex)
    -- Draw placeholder when empty
    if #self.cards == 0 then
        love.graphics.setColor(0.2, 0.35, 0.2, 0.3)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)

        if self.highlighted then
            love.graphics.setColor(self.highlightColor)
            love.graphics.rectangle("fill", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)
        end
        return
    end

    -- Draw highlight if highlighted
    if self.highlighted then
        local width = Card.WIDTH + (self.visibleCount - 1) * Waste.SPREAD_X
        love.graphics.setColor(self.highlightColor)
        love.graphics.rectangle("fill", self.x - 2, self.y - 2,
            width + 4, Card.HEIGHT + 4, Card.CORNER_RADIUS + 2)
    end

    -- Only draw visible cards (or up to excludeFromIndex)
    local visibleStart = math.max(1, #self.cards - self.visibleCount + 1)
    local endIndex = excludeFromIndex and (excludeFromIndex - 1) or #self.cards

    for i = visibleStart, endIndex do
        local card = self.cards[i]
        card:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

-- Override containsPoint for spread cards
function Waste:containsPoint(px, py)
    if #self.cards == 0 then
        return px >= self.x and px <= self.x + Card.WIDTH and
               py >= self.y and py <= self.y + Card.HEIGHT
    end

    -- Check the spread area
    local width = Card.WIDTH + (math.min(#self.cards, self.visibleCount) - 1) * Waste.SPREAD_X
    return px >= self.x and px <= self.x + width and
           py >= self.y and py <= self.y + Card.HEIGHT
end

-- Find card at point (for drag detection)
function Waste:findCardAtPoint(px, py)
    if #self.cards == 0 then
        return nil, nil
    end

    -- Only the top card can be selected
    local topCard = self.cards[#self.cards]
    if topCard:containsPoint(px, py) then
        return #self.cards, topCard
    end

    return nil, nil
end

return Waste
