-- Foundation pile for Klondike Solitaire
-- Cards are stacked by suit from Ace to King
-- Only accepts single cards in ascending order of the same suit

local Pile = require("src.cards.pile")

local Foundation = setmetatable({}, {__index = Pile})
Foundation.__index = Foundation

-- Create a new foundation pile
function Foundation.new(x, y, index)
    return setmetatable(Pile.new(x, y, "foundation", index), Foundation)
end

-- The suit is whatever the Ace on the bottom says; an empty foundation
-- takes any Ace (nothing sticks after its cards leave)
function Foundation:getSuit()
    local ace = self.cards[1]
    return ace and ace.suit or nil
end

-- Check if a card (or cards) can be accepted
function Foundation:canAccept(cards)
    if #cards ~= 1 then
        return false
    end

    local card = cards[1]
    local top = self:getTopCard()
    if not top then
        return card.value == 1
    end
    return card.suit == top.suit and card.value == top.value + 1
end

-- Only the top card can be picked up (taking cards back costs points)
function Foundation:canPickUp(index)
    return index == #self.cards and #self.cards > 0
end

-- Check if foundation is complete (has all 13 cards)
function Foundation:isComplete()
    return #self.cards == 13
end

-- Draw only the highest resting card (cards arriving fly above)
function Foundation:draw()
    for i = #self.cards, 1, -1 do
        if Pile.isResting(self.cards[i]) then
            self.cards[i]:draw()
            break
        end
    end
    love.graphics.setColor(1, 1, 1)
end

return Foundation
