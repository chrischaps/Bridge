-- Tableau pile for Klondike Solitaire
-- Cards are stacked in descending order with alternating colors
-- Only Kings can be placed on empty tableau piles

local Pile = require("src.cards.pile")

local Tableau = setmetatable({}, {__index = Pile})
Tableau.__index = Tableau

-- Spread constants (compressed when a column would run past maxBottom)
Tableau.FACE_DOWN_SPREAD = 8
Tableau.FACE_UP_SPREAD = 26
Tableau.MIN_FACE_DOWN_SPREAD = 4
Tableau.MIN_FACE_UP_SPREAD = 13

-- Create a new tableau pile
function Tableau.new(x, y, index)
    local self = setmetatable(Pile.new(x, y, "tableau", index), Tableau)
    self.maxBottom = math.huge  -- lowest y the last card may reach
    self.offsets = {}
    return self
end

-- Work out each card's y offset, squeezing spreads to fit above maxBottom
function Tableau:computeOffsets()
    local Card = require("src.cards.card")
    local n = #self.cards
    local down, up = 0, 0
    for i = 1, n - 1 do
        if self.cards[i].faceUp then up = up + 1 else down = down + 1 end
    end

    local fd, fu = Tableau.FACE_DOWN_SPREAD, Tableau.FACE_UP_SPREAD
    local available = self.maxBottom - self.y - Card.HEIGHT
    if down * fd + up * fu > available then
        if up > 0 then
            fu = math.max(Tableau.MIN_FACE_UP_SPREAD, (available - down * fd) / up)
        end
        if down > 0 and down * fd + up * fu > available then
            fd = math.max(Tableau.MIN_FACE_DOWN_SPREAD, (available - up * fu) / down)
        end
    end

    local offsets, y = {}, 0
    for i = 1, n do
        offsets[i] = y
        y = y + (self.cards[i].faceUp and fu or fd)
    end
    self.offsets = offsets
end

function Tableau:cardPosition(i)
    return self.x, self.y + (self.offsets[i] or 0)
end

-- Update card positions with variable spread for face-up/face-down
function Tableau:updateCardPositions(immediate)
    self:computeOffsets()
    Pile.updateCardPositions(self, immediate)
end

-- Check if cards can be accepted (Klondike rules)
function Tableau:canAccept(cards)
    if #cards == 0 then
        return false
    end

    local bottomCard = cards[1]

    -- Empty tableau: only Kings allowed
    if self:isEmpty() then
        return bottomCard.value == 13
    end

    local topCard = self:getTopCard()
    return topCard.faceUp
        and topCard.red ~= bottomCard.red
        and bottomCard.value == topCard.value - 1
end

-- Check if cards can be picked up from given index
function Tableau:canPickUp(index)
    if index < 1 or index > #self.cards then
        return false
    end

    -- Can only pick up face-up cards
    if not self.cards[index].faceUp then
        return false
    end

    -- All cards from index to top must form valid descending sequence
    for i = index, #self.cards - 1 do
        local current = self.cards[i]
        local nextCard = self.cards[i + 1]
        if current.red == nextCard.red or nextCard.value ~= current.value - 1 then
            return false
        end
    end

    return true
end

-- Hit-test against resting positions so moving cards don't shift targets
function Tableau:findCardAtPoint(px, py)
    local Card = require("src.cards.card")
    for i = #self.cards, 1, -1 do
        local cx, cy = self:cardPosition(i)
        if px >= cx and px <= cx + Card.WIDTH and py >= cy and py <= cy + Card.HEIGHT then
            return i, self.cards[i]
        end
    end
    return nil, nil
end

-- Flip the top card face up if it's face down
function Tableau:flipTopCard()
    local topCard = self:getTopCard()
    if topCard and not topCard.faceUp then
        topCard:setFaceUp(true, false)
        self:updateCardPositions()
        return true
    end
    return false
end

-- Number of face-down cards
function Tableau:hiddenCount()
    local n = 0
    for _, card in ipairs(self.cards) do
        if not card.faceUp then n = n + 1 end
    end
    return n
end

return Tableau
