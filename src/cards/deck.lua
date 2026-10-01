-- Deck management for a standard 52-card deck
-- Handles creation, shuffling, and dealing

local Card = require("src.cards.card")

local Deck = {}
Deck.__index = Deck

-- Create a new standard 52-card deck
function Deck.new()
    local self = setmetatable({}, Deck)
    self.cards = {}
    return self
end

-- Create all 52 cards
function Deck:create()
    self.cards = {}

    for _, suit in ipairs(Card.SUITS) do
        for _, rank in ipairs(Card.RANKS) do
            local card = Card.new(suit, rank)
            table.insert(self.cards, card)
        end
    end

    return self
end

-- Fisher-Yates shuffle algorithm
-- rng: optional love.math RandomGenerator so a deal can be replayed from its seed
function Deck:shuffle(rng)
    local random = rng and function(a, b) return rng:random(a, b) end or math.random
    local n = #self.cards
    for i = n, 2, -1 do
        local j = random(1, i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
    return self
end

-- Deal a card from the top of the deck
function Deck:deal()
    if #self.cards == 0 then
        return nil
    end
    return table.remove(self.cards)
end

-- Deal multiple cards
function Deck:dealMultiple(count)
    local cards = {}
    for i = 1, count do
        local card = self:deal()
        if card then
            table.insert(cards, card)
        else
            break
        end
    end
    return cards
end

-- Peek at the top card without removing it
function Deck:peek()
    return self.cards[#self.cards]
end

-- Add a card to the bottom of the deck
function Deck:addToBottom(card)
    table.insert(self.cards, 1, card)
end

-- Add a card to the top of the deck
function Deck:addToTop(card)
    table.insert(self.cards, card)
end

-- Check if deck is empty
function Deck:isEmpty()
    return #self.cards == 0
end

-- Get number of cards remaining
function Deck:count()
    return #self.cards
end

-- Get all cards (for iteration)
function Deck:getCards()
    return self.cards
end

-- Reset deck to empty
function Deck:clear()
    self.cards = {}
end

return Deck
