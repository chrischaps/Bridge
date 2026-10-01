-- Base Pile class for card collections
-- Provides common functionality for tableau, foundation, stock, waste piles

local Card = require("src.cards.card")

local Pile = {}
Pile.__index = Pile

-- Create a new pile
-- kind: "stock" | "waste" | "foundation" | "tableau" (used by move rules)
function Pile.new(x, y, kind, index)
    local self = setmetatable({}, Pile)

    self.cards = {}
    self.x = x or 0
    self.y = y or 0
    self.kind = kind or "pile"
    self.index = index or 1

    -- Card spread (for fanned piles)
    self.spreadX = 0
    self.spreadY = 0

    -- Visual properties
    self.highlighted = false
    self.highlightStrength = 0

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

-- Remove cards from a specific index to the end
function Pile:removeCardsFrom(index)
    local removed = {}
    while #self.cards >= index do
        table.insert(removed, 1, table.remove(self.cards))
    end
    self:updateCardPositions()
    return removed
end

-- Copy of the cards from index to the top (without removing them)
function Pile:slice(index)
    local cards = {}
    for i = index, #self.cards do
        cards[#cards + 1] = self.cards[i]
    end
    return cards
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

-- Replace the pile's contents (used by undo); positions are not touched
function Pile:setCards(cards)
    self.cards = cards
end

-- Clear all cards from pile
function Pile:clear()
    self.cards = {}
end

-- Where the card at index i rests
function Pile:cardPosition(i)
    return self.x + (i - 1) * self.spreadX, self.y + (i - 1) * self.spreadY
end

-- Update card positions based on pile position and spread
function Pile:updateCardPositions(immediate)
    for i, card in ipairs(self.cards) do
        local tx, ty = self:cardPosition(i)
        card.zIndex = i
        card:moveTo(tx, ty, immediate)
    end
end

-- Set pile position
function Pile:setPosition(x, y)
    self.x = x
    self.y = y
    self:updateCardPositions(true)
end

-- Pile bounds (x, y, w, h) from the resting positions of its cards
function Pile:getBounds()
    local w, h = Card.WIDTH, Card.HEIGHT
    if #self.cards > 1 then
        local lx, ly = self:cardPosition(#self.cards)
        w = (lx - self.x) + Card.WIDTH
        h = (ly - self.y) + Card.HEIGHT
    end
    return self.x, self.y, w, h
end

-- Check if point is inside pile bounds
function Pile:containsPoint(px, py)
    local x, y, w, h = self:getBounds()
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Find which card in the pile contains a point (returns index and card)
function Pile:findCardAtPoint(px, py)
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

-- True when the card is resting in this pile (not in flight or held)
function Pile.isResting(card)
    return not card.flying and not card.dragging
end

-- Draw resting cards from index `first` to the top
function Pile:drawCards(first)
    for i = first or 1, #self.cards do
        local card = self.cards[i]
        if Pile.isResting(card) then
            card:draw()
        end
    end
end

-- Draw the pile
function Pile:draw()
    self:drawCards(1)
    love.graphics.setColor(1, 1, 1)
end

return Pile
