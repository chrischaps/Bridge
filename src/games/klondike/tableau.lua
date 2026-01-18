-- Tableau pile for Klondike Solitaire
-- Cards are stacked in descending order with alternating colors
-- Only Kings can be placed on empty tableau piles

local Pile = require("src.cards.pile")
local Card = require("src.cards.card")

local Tableau = setmetatable({}, {__index = Pile})
Tableau.__index = Tableau

-- Spread constants
Tableau.FACE_DOWN_SPREAD = 4
Tableau.FACE_UP_SPREAD = 20

-- Create a new tableau pile
function Tableau.new(x, y)
    local self = setmetatable(Pile.new(x, y), Tableau)
    self.spreadY = Tableau.FACE_UP_SPREAD
    return self
end

-- Update card positions with variable spread for face-up/face-down
function Tableau:updateCardPositions(immediate)
    local yOffset = 0
    for i, card in ipairs(self.cards) do
        local targetX = self.x
        local targetY = self.y + yOffset
        card.zIndex = i
        card:moveTo(targetX, targetY, immediate)

        -- Use smaller spread for face-down cards
        if card.faceUp then
            yOffset = yOffset + Tableau.FACE_UP_SPREAD
        else
            yOffset = yOffset + Tableau.FACE_DOWN_SPREAD
        end
    end
end

-- Check if cards can be accepted (Klondike rules)
function Tableau:canAccept(cards)
    if #cards == 0 then
        return false
    end

    local bottomCard = cards[1]

    -- Empty tableau: only Kings allowed
    if self:isEmpty() then
        return bottomCard:getValue() == 13  -- King
    end

    local topCard = self:getTopCard()

    -- Must be opposite color and one rank lower
    local oppositeColor = topCard:isRed() ~= bottomCard:isRed()
    local oneRankLower = bottomCard:getValue() == topCard:getValue() - 1

    return oppositeColor and oneRankLower
end

-- Check if cards can be picked up from given index
function Tableau:canPickUp(index)
    if index < 1 or index > #self.cards then
        return false
    end

    -- Can only pick up face-up cards
    local card = self.cards[index]
    if not card.faceUp then
        return false
    end

    -- All cards from index to top must form valid descending sequence
    for i = index, #self.cards - 1 do
        local current = self.cards[i]
        local next = self.cards[i + 1]

        -- Must alternate colors and descend by one
        if current:isRed() == next:isRed() then
            return false
        end
        if next:getValue() ~= current:getValue() - 1 then
            return false
        end
    end

    return true
end

-- Override findCardAtPoint to account for variable spread
function Tableau:findCardAtPoint(px, py)
    -- Check from top to bottom (reverse order)
    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        -- Use actual card position for hit testing
        if px >= card.x and px <= card.x + Card.WIDTH and
           py >= card.y and py <= card.y + Card.HEIGHT then
            return i, card
        end
    end
    return nil, nil
end

-- Flip the top card face up if it's face down
function Tableau:flipTopCard()
    local topCard = self:getTopCard()
    if topCard and not topCard.faceUp then
        topCard:setFaceUp(true, false)
        return true
    end
    return false
end

-- Check if pile contains point (override for variable height)
function Tableau:containsPoint(px, py)
    if #self.cards == 0 then
        return px >= self.x and px <= self.x + Card.WIDTH and
               py >= self.y and py <= self.y + Card.HEIGHT
    end

    -- Calculate actual pile height
    local lastCard = self.cards[#self.cards]
    local bottom = lastCard.y + Card.HEIGHT

    return px >= self.x and px <= self.x + Card.WIDTH and
           py >= self.y and py <= bottom
end

-- Get pile bounds (override for variable height)
function Tableau:getBounds()
    local height = Card.HEIGHT
    if #self.cards > 0 then
        local lastCard = self.cards[#self.cards]
        height = (lastCard.y - self.y) + Card.HEIGHT
    end
    return self.x, self.y, Card.WIDTH, height
end

-- Draw the tableau pile
function Tableau:draw(excludeFromIndex)
    -- Draw placeholder if empty
    if #self.cards == 0 then
        -- Draw a subtle outline for empty tableau
        love.graphics.setColor(0.2, 0.35, 0.2, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)

        if self.highlighted then
            love.graphics.setColor(self.highlightColor)
            love.graphics.rectangle("fill", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)
        end
        return
    end

    -- Draw highlight behind cards if highlighted
    if self.highlighted then
        local _, _, w, h = self:getBounds()
        love.graphics.setColor(self.highlightColor)
        love.graphics.rectangle("fill", self.x - 2, self.y - 2, w + 4, h + 4, Card.CORNER_RADIUS + 2)
    end

    -- Draw cards
    local endIndex = excludeFromIndex and (excludeFromIndex - 1) or #self.cards
    for i = 1, endIndex do
        local card = self.cards[i]
        card:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

return Tableau
