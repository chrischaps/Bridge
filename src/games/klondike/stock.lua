-- Stock pile for Klondike Solitaire
-- The draw pile - click to deal cards to waste

local Pile = require("src.cards.pile")
local Card = require("src.cards.card")

local Stock = setmetatable({}, {__index = Pile})
Stock.__index = Stock

-- Create a new stock pile
function Stock.new(x, y)
    local self = setmetatable(Pile.new(x, y), Stock)
    self.spreadX = 0
    self.spreadY = 0
    return self
end

-- Stock doesn't accept any cards from drag/drop
function Stock:canAccept(cards)
    return false
end

-- Can't pick up cards from stock (must click to draw)
function Stock:canPickUp(index)
    return false
end

-- Reset stock from waste cards (for cycling)
function Stock:reset(wasteCards)
    -- Add waste cards back to stock in reverse order, face down
    for i = #wasteCards, 1, -1 do
        local card = wasteCards[i]
        card:setFaceUp(false, true)
        table.insert(self.cards, card)
    end
    self:updateCardPositions(true)
end

-- Override draw to show card back or empty indicator
function Stock:draw()
    -- Draw placeholder/empty indicator
    if #self.cards == 0 then
        -- Draw refresh indicator (circle with arrow) when empty
        love.graphics.setColor(0.2, 0.35, 0.2, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)

        -- Draw circular arrow to indicate click to reset
        local cx = self.x + Card.WIDTH / 2
        local cy = self.y + Card.HEIGHT / 2
        local r = 15

        love.graphics.setColor(0.3, 0.5, 0.3, 0.6)
        love.graphics.setLineWidth(3)
        love.graphics.arc("line", "open", cx, cy, r, -math.pi * 0.7, math.pi * 0.5)

        -- Arrow head
        local ax = cx + r * math.cos(math.pi * 0.5)
        local ay = cy + r * math.sin(math.pi * 0.5)
        love.graphics.polygon("fill",
            ax, ay,
            ax - 6, ay - 8,
            ax + 6, ay - 8)

        if self.highlighted then
            love.graphics.setColor(self.highlightColor)
            love.graphics.rectangle("fill", self.x, self.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)
        end
    else
        -- Draw the top card (face down) with slight offset to show depth
        local showDepth = math.min(#self.cards, 3)

        for i = 1, showDepth do
            local offset = (showDepth - i) * 1
            local card = self.cards[#self.cards - showDepth + i]
            if card then
                -- Draw card at slight offset to show stack depth
                love.graphics.push()
                love.graphics.translate(offset, offset)
                card:draw()
                love.graphics.pop()
            end
        end
    end

    love.graphics.setColor(1, 1, 1)
end

-- Update card positions (all stacked)
function Stock:updateCardPositions(immediate)
    for i, card in ipairs(self.cards) do
        card.zIndex = i
        card:moveTo(self.x, self.y, immediate)
    end
end

return Stock
