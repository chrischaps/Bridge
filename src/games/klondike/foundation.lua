-- Foundation pile for Klondike Solitaire
-- Cards are stacked by suit from Ace to King
-- Only accepts single cards in ascending order of the same suit

local Pile = require("src.cards.pile")
local Card = require("src.cards.card")

local Foundation = setmetatable({}, {__index = Pile})
Foundation.__index = Foundation

-- Create a new foundation pile
function Foundation.new(x, y, suit)
    local self = setmetatable(Pile.new(x, y), Foundation)
    self.suit = suit  -- Optional: assign a suit to this foundation
    self.spreadX = 0
    self.spreadY = 0
    return self
end

-- Check if a card (or cards) can be accepted
function Foundation:canAccept(cards)
    -- Only accepts single cards
    if #cards ~= 1 then
        return false
    end

    local card = cards[1]

    -- If foundation has an assigned suit, card must match
    if self.suit and card.suit ~= self.suit then
        return false
    end

    -- Empty foundation: only Aces allowed
    if self:isEmpty() then
        if card:getValue() == 1 then
            -- If we don't have an assigned suit, accept any Ace
            -- and assign that suit to this foundation
            return true
        end
        return false
    end

    local topCard = self:getTopCard()

    -- Must be same suit and one rank higher
    local sameSuit = card.suit == topCard.suit
    local oneRankHigher = card:getValue() == topCard:getValue() + 1

    return sameSuit and oneRankHigher
end

-- Override addCard to potentially set suit
function Foundation:addCard(card, immediate)
    -- Set the foundation's suit when first card is added
    if self:isEmpty() and not self.suit then
        self.suit = card.suit
    end

    -- Ensure card is face up
    card:setFaceUp(true, true)

    Pile.addCard(self, card, immediate)
end

-- Check if cards can be picked up (allow taking cards back)
function Foundation:canPickUp(index)
    -- Only the top card can be picked up
    return index == #self.cards and #self.cards > 0
end

-- Check if foundation is complete (has all 13 cards)
function Foundation:isComplete()
    return #self.cards == 13
end

-- Get the current rank value (0 if empty, 1-13 otherwise)
function Foundation:getCurrentValue()
    if self:isEmpty() then
        return 0
    end
    return self:getTopCard():getValue()
end

-- Draw the foundation pile
function Foundation:draw(excludeFromIndex)
    -- Draw placeholder with suit indicator
    love.graphics.setColor(0.2, 0.35, 0.2, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)

    -- Draw suit symbol in center of empty foundation
    if self:isEmpty() then
        if self.highlighted then
            love.graphics.setColor(self.highlightColor)
            love.graphics.rectangle("fill", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)
        end

        -- Draw "A" to indicate Ace goes here
        love.graphics.setColor(0.3, 0.4, 0.3, 0.4)
        local font = love.graphics.getFont()
        local text = "A"
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text,
            self.x + (Card.WIDTH - textWidth) / 2,
            self.y + (Card.HEIGHT - textHeight) / 2)
    else
        -- Draw highlight behind card
        if self.highlighted then
            love.graphics.setColor(self.highlightColor)
            love.graphics.rectangle("fill", self.x - 2, self.y - 2,
                Card.WIDTH + 4, Card.HEIGHT + 4, Card.CORNER_RADIUS + 2)
        end

        -- Only draw the top card (no spread)
        local endIndex = excludeFromIndex and (excludeFromIndex - 1) or #self.cards
        if endIndex >= 1 then
            self.cards[endIndex]:draw()
        end
    end

    love.graphics.setColor(1, 1, 1)
end

return Foundation
