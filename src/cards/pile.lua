-- Base Pile class for card collections
-- Provides common functionality for tableau, foundation, stock, waste piles

local Card = require("src.cards.card")

local Pile = {}
Pile.__index = Pile

-- Create a new pile
function Pile.new(x, y)
    local self = setmetatable({}, Pile)

    self.cards = {}
    self.x = x or 0
    self.y = y or 0

    -- Card spread (for fanned piles)
    self.spreadX = 0
    self.spreadY = 0

    -- Visual properties
    self.highlighted = false
    self.highlightColor = {0.3, 0.7, 0.4, 0.4}

    return self
end

-- Add a card to the top of the pile
function Pile:addCard(card, immediate)
    table.insert(self.cards, card)
    self:updateCardPositions(immediate)
end

-- Add multiple cards to the pile
function Pile:addCards(cards, immediate)
    for _, card in ipairs(cards) do
        table.insert(self.cards, card)
    end
    self:updateCardPositions(immediate)
end

-- Remove and return the top card
function Pile:removeCard()
    if #self.cards == 0 then
        return nil
    end
    local card = table.remove(self.cards)
    self:updateCardPositions()
    return card
end

-- Remove and return multiple cards from the top
function Pile:removeCards(count)
    local removed = {}
    for i = 1, count do
        if #self.cards > 0 then
            table.insert(removed, 1, table.remove(self.cards))
        end
    end
    self:updateCardPositions()
    return removed
end

-- Remove cards from a specific index to the end
function Pile:removeCardsFrom(index)
    local removed = {}
    while #self.cards >= index do
        table.insert(removed, 1, table.remove(self.cards))
    end
    self:updateCardPositions()
    return removed
end

-- Get the top card without removing it
function Pile:getTopCard()
    return self.cards[#self.cards]
end

-- Get card at specific index
function Pile:getCardAt(index)
    return self.cards[index]
end

-- Check if pile is empty
function Pile:isEmpty()
    return #self.cards == 0
end

-- Get number of cards
function Pile:count()
    return #self.cards
end

-- Get all cards
function Pile:getCards()
    return self.cards
end

-- Clear all cards from pile
function Pile:clear()
    self.cards = {}
end

-- Update card positions based on pile position and spread
function Pile:updateCardPositions(immediate)
    for i, card in ipairs(self.cards) do
        local targetX = self.x + (i - 1) * self.spreadX
        local targetY = self.y + (i - 1) * self.spreadY
        card.zIndex = i
        card:moveTo(targetX, targetY, immediate)
    end
end

-- Set pile position
function Pile:setPosition(x, y)
    self.x = x
    self.y = y
    self:updateCardPositions(true)
end

-- Set card spread
function Pile:setSpread(spreadX, spreadY)
    self.spreadX = spreadX or 0
    self.spreadY = spreadY or 0
    self:updateCardPositions(true)
end

-- Check if point is inside pile bounds
function Pile:containsPoint(px, py)
    -- Get pile bounds
    local left = self.x
    local top = self.y
    local right = self.x + Card.WIDTH + math.abs(self.spreadX) * math.max(0, #self.cards - 1)
    local bottom = self.y + Card.HEIGHT + math.abs(self.spreadY) * math.max(0, #self.cards - 1)

    return px >= left and px <= right and py >= top and py <= bottom
end

-- Find which card in the pile contains a point (returns index and card)
function Pile:findCardAtPoint(px, py)
    -- Check from top to bottom (reverse order)
    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        if card:containsPoint(px, py) then
            return i, card
        end
    end
    return nil, nil
end

-- Check if a move can be accepted (override in subclasses)
function Pile:canAccept(cards)
    return false
end

-- Check if cards can be picked up from this pile at given index (override in subclasses)
function Pile:canPickUp(index)
    return false
end

-- Highlight the pile (for valid drop targets)
function Pile:setHighlight(highlighted)
    self.highlighted = highlighted
end

-- Update all cards in the pile
function Pile:update(dt)
    for _, card in ipairs(self.cards) do
        card:update(dt)
    end
end

-- Draw empty pile placeholder
function Pile:drawPlaceholder()
    love.graphics.setColor(0.2, 0.35, 0.2, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)

    if self.highlighted then
        love.graphics.setColor(self.highlightColor)
        love.graphics.rectangle("fill", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)
    end
end

-- Draw the pile
function Pile:draw(excludeFromIndex)
    -- Draw placeholder if empty
    if #self.cards == 0 then
        self:drawPlaceholder()
        return
    end

    -- Draw highlight behind cards
    if self.highlighted then
        local right = self.x + Card.WIDTH + self.spreadX * math.max(0, #self.cards - 1)
        local bottom = self.y + Card.HEIGHT + self.spreadY * math.max(0, #self.cards - 1)
        love.graphics.setColor(self.highlightColor)
        love.graphics.rectangle("fill", self.x - 2, self.y - 2,
            right - self.x + 4, bottom - self.y + 4, Card.CORNER_RADIUS + 2)
    end

    -- Draw cards
    local endIndex = excludeFromIndex and (excludeFromIndex - 1) or #self.cards
    for i = 1, endIndex do
        local card = self.cards[i]
        card:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

-- Get pile bounds for collision detection
function Pile:getBounds()
    local width = Card.WIDTH + math.abs(self.spreadX) * math.max(0, #self.cards - 1)
    local height = Card.HEIGHT + math.abs(self.spreadY) * math.max(0, #self.cards - 1)
    return self.x, self.y, width, height
end

return Pile
