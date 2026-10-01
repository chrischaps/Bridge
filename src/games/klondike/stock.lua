-- Stock pile for Klondike Solitaire
-- The draw pile - click to deal cards to waste

local Pile = require("src.cards.pile")

local Stock = setmetatable({}, {__index = Pile})
Stock.__index = Stock

-- Create a new stock pile
function Stock.new(x, y)
    return setmetatable(Pile.new(x, y, "stock"), Stock)
end

-- Stock doesn't accept any cards from drag/drop
function Stock:canAccept(cards)
    return false
end

-- Can't pick up cards from stock (must click to draw)
function Stock:canPickUp(index)
    return false
end

-- Reset stock from waste cards (for cycling): reversed and face down
function Stock:reset(wasteCards)
    for i = #wasteCards, 1, -1 do
        local card = wasteCards[i]
        card:setFaceUp(false, true)
        table.insert(self.cards, card)
    end
    self:updateCardPositions()
end

-- Stack depth: a pixel per few cards, up to three steps
function Stock:cardPosition(i)
    local depth = math.min(3, math.floor((i - 1) / 8))
    return self.x - depth, self.y - depth
end

function Stock:getBounds()
    local Card = require("src.cards.card")
    return self.x - 3, self.y - 3, Card.WIDTH + 3, Card.HEIGHT + 3
end

-- Draw the stack (lower cards show only as edges)
function Stock:draw()
    self:drawCards(1)
    love.graphics.setColor(1, 1, 1)
end

return Stock
