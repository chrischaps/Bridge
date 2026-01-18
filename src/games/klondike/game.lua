-- Klondike Solitaire Game Controller
-- Manages all game state, input handling, and win condition checking

local Card = require("src.cards.card")
local Deck = require("src.cards.deck")
local Tableau = require("src.games.klondike.tableau")
local Foundation = require("src.games.klondike.foundation")
local Stock = require("src.games.klondike.stock")
local Waste = require("src.games.klondike.waste")
local Scoring = require("src.games.klondike.scoring")

local KlondikeGame = {}
KlondikeGame.__index = KlondikeGame

-- Layout constants
KlondikeGame.LAYOUT = {
    MARGIN_TOP = 30,
    MARGIN_LEFT = 40,
    CARD_GAP = 15,
    TABLEAU_TOP = 150,
    FOUNDATION_OFFSET = 3,  -- Gap between waste and foundations
}

-- Create a new Klondike game
function KlondikeGame.new(screenWidth, screenHeight)
    local self = setmetatable({}, KlondikeGame)

    self.screenWidth = screenWidth or 960
    self.screenHeight = screenHeight or 540

    -- Game settings
    self.drawCount = 1  -- 1 or 3 cards from stock

    -- Game state
    self.state = "playing"  -- playing, won
    self.scoring = Scoring.new()

    -- Piles
    self.stock = nil
    self.waste = nil
    self.foundations = {}
    self.tableaus = {}

    -- Drag state
    self.dragging = false
    self.dragCards = {}
    self.dragSource = nil
    self.dragSourceIndex = nil
    self.dragOffsetX = 0
    self.dragOffsetY = 0
    self.dragX = 0
    self.dragY = 0

    -- Double-click detection
    self.lastClickTime = 0
    self.lastClickCard = nil
    self.doubleClickThreshold = 0.3

    -- Win animation state
    self.winParticles = {}

    return self
end

-- Initialize/reset the game
function KlondikeGame:init(drawCount)
    self.drawCount = drawCount or self.drawCount
    self.state = "playing"

    -- Calculate layout
    local layout = KlondikeGame.LAYOUT
    local cardW = Card.WIDTH
    local cardH = Card.HEIGHT
    local gap = layout.CARD_GAP

    -- Top row: Stock, Waste, [gap], 4 Foundations
    local topY = layout.MARGIN_TOP

    -- Stock position
    local stockX = layout.MARGIN_LEFT
    self.stock = Stock.new(stockX, topY)

    -- Waste position (next to stock)
    local wasteX = stockX + cardW + gap
    self.waste = Waste.new(wasteX, topY)
    self.waste:setVisibleCount(self.drawCount)

    -- Foundation positions (right side)
    self.foundations = {}
    local foundationStartX = self.screenWidth - layout.MARGIN_LEFT - (4 * cardW + 3 * gap)
    for i = 1, 4 do
        local fx = foundationStartX + (i - 1) * (cardW + gap)
        local foundation = Foundation.new(fx, topY)
        table.insert(self.foundations, foundation)
    end

    -- Tableau piles (7 columns)
    self.tableaus = {}
    local tableauY = layout.TABLEAU_TOP
    local totalTableauWidth = 7 * cardW + 6 * gap
    local tableauStartX = (self.screenWidth - totalTableauWidth) / 2

    for i = 1, 7 do
        local tx = tableauStartX + (i - 1) * (cardW + gap)
        local tableau = Tableau.new(tx, tableauY)
        table.insert(self.tableaus, tableau)
    end

    -- Create and shuffle deck
    local deck = Deck.new()
    deck:create()
    deck:shuffle()

    -- Deal to tableaus (1 card to first pile, 2 to second, etc.)
    for i = 1, 7 do
        for j = i, 7 do
            local card = deck:deal()
            if card then
                -- Only the top card of each pile is face up
                card:setFaceUp(j == i, true)
                self.tableaus[j]:addCard(card, true)
            end
        end
    end

    -- Remaining cards go to stock
    while not deck:isEmpty() do
        local card = deck:deal()
        card:setFaceUp(false, true)
        self.stock:addCard(card, true)
    end

    -- Reset scoring
    self.scoring:start(self.drawCount)

    -- Reset drag state
    self:cancelDrag()
end

-- Set draw count (1 or 3)
function KlondikeGame:setDrawCount(count)
    self.drawCount = count
    if self.waste then
        self.waste:setVisibleCount(count)
    end
end

-- Get all piles for iteration
function KlondikeGame:getAllPiles()
    local piles = {self.stock, self.waste}
    for _, f in ipairs(self.foundations) do
        table.insert(piles, f)
    end
    for _, t in ipairs(self.tableaus) do
        table.insert(piles, t)
    end
    return piles
end

-- Find pile at screen position
function KlondikeGame:findPileAt(x, y)
    -- Check tableaus first (they can overlap)
    for i, tableau in ipairs(self.tableaus) do
        if tableau:containsPoint(x, y) then
            return tableau, "tableau", i
        end
    end

    -- Check foundations
    for i, foundation in ipairs(self.foundations) do
        if foundation:containsPoint(x, y) then
            return foundation, "foundation", i
        end
    end

    -- Check waste
    if self.waste:containsPoint(x, y) then
        return self.waste, "waste", 1
    end

    -- Check stock
    if self.stock:containsPoint(x, y) then
        return self.stock, "stock", 1
    end

    return nil, nil, nil
end

-- Handle stock click
function KlondikeGame:clickStock()
    if self.stock:isEmpty() then
        -- Reset stock from waste
        if not self.waste:isEmpty() then
            local wasteCards = self.waste:getAllCards()
            self.waste:clear()
            self.stock:reset(wasteCards)
            self.scoring:recycleWaste()
        end
    else
        -- Draw cards from stock to waste
        local drawn = {}
        for i = 1, self.drawCount do
            if not self.stock:isEmpty() then
                local card = self.stock:removeCard()
                table.insert(drawn, card)
            end
        end
        self.waste:addFromStock(drawn)
    end
end

-- Try to auto-move a card to foundation
function KlondikeGame:tryAutoMove(card, sourcePile, sourceIndex)
    -- Try each foundation
    for _, foundation in ipairs(self.foundations) do
        if foundation:canAccept({card}) then
            -- Remove card from source
            if sourcePile == self.waste then
                sourcePile:removeCard()
                self.scoring:cardToFoundation()
            else
                sourcePile:removeCardsFrom(sourceIndex)
                self.scoring:cardToFoundation()

                -- Flip next card if tableau
                if sourcePile.flipTopCard then
                    if sourcePile:flipTopCard() then
                        self.scoring:tableauFlipped()
                    end
                end
            end

            -- Add to foundation
            foundation:addCard(card)

            -- Check for win
            self:checkWin()
            return true
        end
    end
    return false
end

-- Start dragging cards
function KlondikeGame:startDrag(pile, cardIndex, x, y)
    if not pile:canPickUp(cardIndex) then
        return false
    end

    local card = pile:getCardAt(cardIndex)
    if not card then
        return false
    end

    self.dragging = true
    self.dragSource = pile
    self.dragSourceIndex = cardIndex
    self.dragOffsetX = x - card.x
    self.dragOffsetY = y - card.y
    self.dragX = x
    self.dragY = y

    -- Collect all cards being dragged
    self.dragCards = {}
    for i = cardIndex, pile:count() do
        table.insert(self.dragCards, pile:getCardAt(i))
    end

    -- Highlight valid drop targets
    self:updateDropHighlights()

    return true
end

-- Update drag position
function KlondikeGame:updateDrag(x, y)
    if not self.dragging then return end

    self.dragX = x
    self.dragY = y
end

-- Update drop target highlighting
function KlondikeGame:updateDropHighlights()
    -- Clear all highlights
    for _, pile in ipairs(self:getAllPiles()) do
        pile:setHighlight(false)
    end

    if not self.dragging or #self.dragCards == 0 then
        return
    end

    -- Highlight valid drop targets
    for _, tableau in ipairs(self.tableaus) do
        if tableau ~= self.dragSource and tableau:canAccept(self.dragCards) then
            tableau:setHighlight(true)
        end
    end

    -- Only single cards can go to foundation
    if #self.dragCards == 1 then
        for _, foundation in ipairs(self.foundations) do
            if foundation:canAccept(self.dragCards) then
                foundation:setHighlight(true)
            end
        end
    end
end

-- End drag (drop cards)
function KlondikeGame:endDrag(x, y)
    if not self.dragging then return end

    local dropped = false
    local pile, pileType = self:findPileAt(x, y)

    if pile and pile ~= self.dragSource then
        if pile:canAccept(self.dragCards) then
            -- Remove cards from source
            self.dragSource:removeCardsFrom(self.dragSourceIndex)

            -- Track if source was waste
            local fromWaste = self.dragSource == self.waste

            -- Add to destination
            for _, card in ipairs(self.dragCards) do
                pile:addCard(card)
            end

            -- Update scoring
            if pileType == "foundation" then
                self.scoring:cardToFoundation()
            elseif pileType == "tableau" and fromWaste then
                self.scoring:wasteToTableau()
            else
                self.scoring:generalMove()
            end

            -- Flip tableau card if needed
            if self.dragSource.flipTopCard then
                if self.dragSource:flipTopCard() then
                    self.scoring:tableauFlipped()
                end
            end

            dropped = true

            -- Check for win
            self:checkWin()
        end
    end

    -- If not dropped, cards will animate back (handled by card:update)
    if not dropped then
        -- Cards are still in source pile, just need to update positions
        self.dragSource:updateCardPositions(false)
    end

    self:cancelDrag()
end

-- Cancel drag
function KlondikeGame:cancelDrag()
    self.dragging = false
    self.dragCards = {}
    self.dragSource = nil
    self.dragSourceIndex = nil

    -- Clear highlights
    for _, pile in ipairs(self:getAllPiles()) do
        pile:setHighlight(false)
    end
end

-- Check for win condition
function KlondikeGame:checkWin()
    for _, foundation in ipairs(self.foundations) do
        if not foundation:isComplete() then
            return false
        end
    end

    self.state = "won"
    self.scoring:stop()
    return true
end

-- Handle mouse press
function KlondikeGame:mousepressed(x, y, button)
    if self.state ~= "playing" then return end
    if button ~= 1 then return end

    local pile, pileType, pileIndex = self:findPileAt(x, y)

    if not pile then
        return
    end

    -- Handle stock click
    if pileType == "stock" then
        self:clickStock()
        return
    end

    -- Find card at click position
    local cardIndex, card = pile:findCardAtPoint(x, y)

    if not card then
        return
    end

    -- Check for double-click (auto-move to foundation)
    local currentTime = love.timer.getTime()
    if card == self.lastClickCard and
       (currentTime - self.lastClickTime) < self.doubleClickThreshold then
        -- Double-click: try auto-move
        if card.faceUp then
            self:tryAutoMove(card, pile, cardIndex)
        end
        self.lastClickCard = nil
        return
    end

    self.lastClickTime = currentTime
    self.lastClickCard = card

    -- Start drag if card is face up
    if card.faceUp then
        self:startDrag(pile, cardIndex, x, y)
    end
end

-- Handle mouse release
function KlondikeGame:mousereleased(x, y, button)
    if button ~= 1 then return end

    if self.dragging then
        self:endDrag(x, y)
    end
end

-- Handle mouse move
function KlondikeGame:mousemoved(x, y, dx, dy)
    if self.dragging then
        self:updateDrag(x, y)
    end
end

-- Update game state
function KlondikeGame:update(dt)
    -- Update scoring/timer
    self.scoring:update(dt)

    -- Update all card animations
    for _, pile in ipairs(self:getAllPiles()) do
        pile:update(dt)
    end

    -- Update drag highlights
    if self.dragging then
        self:updateDropHighlights()
    end
end

-- Draw the game
function KlondikeGame:draw()
    -- Draw felt background
    love.graphics.setColor(0.15, 0.4, 0.2)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Subtle texture pattern
    love.graphics.setColor(0.12, 0.35, 0.18, 0.3)
    for i = 0, self.screenWidth, 20 do
        for j = 0, self.screenHeight, 20 do
            if (i + j) % 40 == 0 then
                love.graphics.rectangle("fill", i, j, 10, 10)
            end
        end
    end

    -- Draw stock
    self.stock:draw()

    -- Draw waste
    self.waste:draw(self.dragging and self.dragSource == self.waste and self.dragSourceIndex)

    -- Draw foundations
    for i, foundation in ipairs(self.foundations) do
        local excludeIndex = nil
        if self.dragging and self.dragSource == foundation then
            excludeIndex = self.dragSourceIndex
        end
        foundation:draw(excludeIndex)
    end

    -- Draw tableaus
    for i, tableau in ipairs(self.tableaus) do
        local excludeIndex = nil
        if self.dragging and self.dragSource == tableau then
            excludeIndex = self.dragSourceIndex
        end
        tableau:draw(excludeIndex)
    end

    -- Draw dragged cards
    if self.dragging and #self.dragCards > 0 then
        local baseX = self.dragX - self.dragOffsetX
        local baseY = self.dragY - self.dragOffsetY

        for i, card in ipairs(self.dragCards) do
            local cardY = baseY + (i - 1) * Tableau.FACE_UP_SPREAD
            love.graphics.push()
            love.graphics.translate(baseX - card.x, cardY - card.y)
            card:draw({x = 0, y = 0})
            love.graphics.pop()
        end
    end

    love.graphics.setColor(1, 1, 1)
end

-- Get scoring for HUD
function KlondikeGame:getScoring()
    return self.scoring
end

-- Check if game is won
function KlondikeGame:isWon()
    return self.state == "won"
end

-- New game
function KlondikeGame:newGame()
    self:init(self.drawCount)
end

return KlondikeGame
