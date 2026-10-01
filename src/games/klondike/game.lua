-- Klondike Solitaire Game Controller
-- Owns the piles and the rules. Every change to the cards goes through one
-- pipeline (canMove/applyMove, drawStock, undo), which keeps scoring, flips,
-- undo history and win detection in one place.

local Card = require("src.cards.card")
local Deck = require("src.cards.deck")
local Pile = require("src.cards.pile")
local Tableau = require("src.games.klondike.tableau")
local Foundation = require("src.games.klondike.foundation")
local Stock = require("src.games.klondike.stock")
local Waste = require("src.games.klondike.waste")
local Scoring = require("src.games.klondike.scoring")

local KlondikeGame = {}
KlondikeGame.__index = KlondikeGame

-- Layout constants (virtual pixels)
KlondikeGame.LAYOUT = {
    MARGIN_TOP = 22,
    CARD_GAP = 18,
    ROW_GAP = 26,        -- between the top row and the tableau
    BOTTOM_RESERVE = 54, -- room kept free for the rail at the bottom
}

-- Pointer travel (virtual px) before a press becomes a drag
KlondikeGame.DRAG_THRESHOLD = 4
-- Seconds between cards when auto-completing
KlondikeGame.AUTO_STEP = 0.08
-- Deal animation: seconds between cards
KlondikeGame.DEAL_STAGGER = 0.035

-- Create a new Klondike game
function KlondikeGame.new(screenWidth, screenHeight)
    local self = setmetatable({}, KlondikeGame)

    self.screenWidth = screenWidth or 960
    self.screenHeight = screenHeight or 540
    self.drawCount = 1
    self.state = "playing"  -- playing, won
    self.scoring = Scoring.new()
    self.listener = nil      -- function(event, data) for sound and effects

    self.cards = {}
    self.history = {}
    self.flyLayer = {}

    self.press = nil         -- pointer pressed on a card, not yet a drag
    self.drag = nil          -- active drag
    self.hint = nil          -- {move=..., time=...}
    self.autoCompleting = false
    self.dealing = 0         -- seconds of deal animation left
    self.mouseX, self.mouseY = -1000, -1000

    self:createPiles()
    return self
end

--------------------------------------------------
-- SETUP
--------------------------------------------------

function KlondikeGame:createPiles()
    self.stock = Stock.new(0, 0)
    self.waste = Waste.new(0, 0)
    self.foundations, self.tableaus = {}, {}
    for i = 1, 4 do self.foundations[i] = Foundation.new(0, 0, i) end
    for i = 1, 7 do self.tableaus[i] = Tableau.new(0, 0, i) end

    self.piles = {self.stock, self.waste}
    for _, f in ipairs(self.foundations) do self.piles[#self.piles + 1] = f end
    for _, t in ipairs(self.tableaus) do self.piles[#self.piles + 1] = t end

    -- Destinations in preference order: foundations, then tableaus
    self.targets = {}
    for _, f in ipairs(self.foundations) do self.targets[#self.targets + 1] = f end
    for _, t in ipairs(self.tableaus) do self.targets[#self.targets + 1] = t end

    self:layout()
end

-- Position the piles for the current card size and screen
function KlondikeGame:layout()
    local L = KlondikeGame.LAYOUT
    local w, gap = Card.WIDTH, L.CARD_GAP
    local rowWidth = 7 * w + 6 * gap
    local left = math.floor((self.screenWidth - rowWidth) / 2)
    local col = function(i) return left + (i - 1) * (w + gap) end

    local topY = L.MARGIN_TOP
    self.stock.x, self.stock.y = col(1), topY
    self.waste.x, self.waste.y = col(2), topY
    for i, f in ipairs(self.foundations) do
        f.x, f.y = col(i + 3), topY
    end
    local tableauY = topY + Card.HEIGHT + L.ROW_GAP
    for i, t in ipairs(self.tableaus) do
        t.x, t.y = col(i), tableauY
        t.maxBottom = self.screenHeight - L.BOTTOM_RESERVE
    end
    for _, p in ipairs(self.piles) do
        p:updateCardPositions(true)
    end
end

-- Deal a new game. seed picks the shuffle (a "deal number"); animate flies
-- the cards out of the stock.
function KlondikeGame:deal(drawCount, seed, animate)
    self.drawCount = drawCount or self.drawCount
    self.seed = seed or love.math.random(1, 99999)
    self.state = "playing"
    self.history = {}
    self.flyLayer = {}
    self.press, self.drag, self.hint = nil, nil, nil
    self.autoCompleting = false
    self.scoring:start(self.drawCount)

    for _, p in ipairs(self.piles) do p:clear() end
    self.waste.fanCount = 0

    local deck = Deck.new():create()
    deck:shuffle(love.math.newRandomGenerator(self.seed))
    self.cards = {}
    for _, card in ipairs(deck:getCards()) do self.cards[#self.cards + 1] = card end

    -- Everything starts face down in the stock position
    for _, card in ipairs(self.cards) do
        card:setFaceUp(false, true)
        card:setPosition(self.stock.x, self.stock.y)
        card.flying, card.dragging, card.delay = false, false, 0
        card.hidden, card.shake, card.lift = false, 0, 0
    end

    -- Deal row by row like a real dealer: 1st row across 7 piles, then 6 ...
    local order = 0
    for row = 1, 7 do
        for j = row, 7 do
            local card = deck:deal()
            local t = self.tableaus[j]
            table.insert(t.cards, card)
            card:setFaceUp(j == row, not animate)
            if animate then
                order = order + 1
                card.delay = order * KlondikeGame.DEAL_STAGGER
                self:launch(card)
            end
        end
    end
    while not deck:isEmpty() do
        local card = deck:deal()
        table.insert(self.stock.cards, card)
    end

    for _, p in ipairs(self.piles) do p:updateCardPositions(not animate) end
    self.dealing = animate and (order * KlondikeGame.DEAL_STAGGER + 0.35) or 0
    self:emit("deal")
end

-- Restart the current deal from scratch
function KlondikeGame:restartDeal(animate)
    self:deal(self.drawCount, self.seed, animate)
end

--------------------------------------------------
-- QUERIES
--------------------------------------------------

function KlondikeGame:isWon()
    return self.state == "won"
end

function KlondikeGame:getScoring()
    return self.scoring
end

function KlondikeGame:hasProgress()
    return self.scoring:getMoves() > 0 or #self.history > 0
end

-- True while input should be ignored (deal or auto-complete running)
function KlondikeGame:isBusy()
    return self.dealing > 0 or self.autoCompleting
end

function KlondikeGame:emit(event, data)
    if self.listener then self.listener(event, data) end
end

-- Can the cards from `index` up on `from` legally go onto `to`?
function KlondikeGame:canMove(from, index, to)
    if not from or not to or from == to then return false end
    if not from:canPickUp(index) then return false end
    if to.kind == "foundation" then
        -- one card at a time, and shuffling between foundations is pointless
        if from.kind == "foundation" or index ~= from:count() then return false end
    elseif to.kind ~= "tableau" then
        return false
    end
    return to:canAccept(from:slice(index))
end

-- Every legal card move right now (draws not included)
function KlondikeGame:legalMoves()
    local moves = {}
    local function try(from, index)
        for _, to in ipairs(self.targets) do
            if self:canMove(from, index, to) then
                moves[#moves + 1] = {from = from, index = index, to = to}
            end
        end
    end
    if not self.waste:isEmpty() then try(self.waste, self.waste:count()) end
    for _, f in ipairs(self.foundations) do
        if not f:isEmpty() then try(f, f:count()) end
    end
    for _, t in ipairs(self.tableaus) do
        for i = 1, t:count() do
            if t.cards[i].faceUp and t:canPickUp(i) then try(t, i) end
        end
    end
    return moves
end

-- How useful a move is, for hints. nil = not worth suggesting.
function KlondikeGame:rankMove(m)
    local from, to, index = m.from, m.to, m.index
    if from.kind == "foundation" then return nil end

    local revealsHidden = from.kind == "tableau" and index > 1 and not from.cards[index - 1].faceUp

    if to.kind == "foundation" then
        return revealsHidden and 120 or 100
    end
    if from.kind == "waste" then
        return 60
    end
    -- tableau to tableau
    if index == 1 then
        -- emptying a column helps, unless it's a King hopping between columns
        if to:isEmpty() then return nil end
        return 70
    end
    if revealsHidden then
        return 80 + from:hiddenCount()
    end
    -- splitting a face-up run only helps if it frees a card for a foundation
    local freed = from.cards[index - 1]
    for _, f in ipairs(self.foundations) do
        if f:canAccept({freed}) then return 40 end
    end
    return nil
end

-- Best hint: a ranked card move, else {draw=true}, else nil (stuck)
function KlondikeGame:findHint()
    local best, bestScore = nil, -1
    for _, m in ipairs(self:legalMoves()) do
        local score = self:rankMove(m)
        if score and score > bestScore then
            best, bestScore = m, score
        end
    end
    if best then return best end
    if self:stockHasPlayableCard() then
        return {draw = true}
    end
    return nil
end

-- Could any card still in the stock or waste be played somewhere?
function KlondikeGame:stockHasPlayableCard()
    local function playable(card)
        for _, to in ipairs(self.targets) do
            if to:canAccept({card}) then return true end
        end
        return false
    end
    for _, c in ipairs(self.stock.cards) do if playable(c) then return true end end
    for _, c in ipairs(self.waste.cards) do if playable(c) then return true end end
    return false
end

-- Where a click on this card should send it: foundation first, then a
-- tableau that already has cards, then an empty one
function KlondikeGame:findSmartTarget(from, index)
    if from.kind == "foundation" then return nil end
    local emptyTarget = nil
    for _, to in ipairs(self.targets) do
        if self:canMove(from, index, to) then
            if to.kind == "tableau" and to:isEmpty() then
                -- a King already at the bottom of a column has nowhere better to go
                if not (from.kind == "tableau" and index == 1) then
                    emptyTarget = emptyTarget or to
                end
            else
                return to
            end
        end
    end
    return emptyTarget
end

-- All cards face up and nothing left in stock/waste: the rest is mechanical
function KlondikeGame:canAutoComplete()
    if self.state ~= "playing" then return false end
    if not self.stock:isEmpty() or not self.waste:isEmpty() then return false end
    for _, t in ipairs(self.tableaus) do
        for _, c in ipairs(t.cards) do
            if not c.faceUp then return false end
        end
    end
    return true
end

--------------------------------------------------
-- ACTIONS (the only code that changes the piles)
--------------------------------------------------

-- Remember the whole layout so it can be restored exactly
function KlondikeGame:snapshot()
    local snap = {piles = {}, faceUp = {}, fan = self.waste.fanCount, scoring = self.scoring:snapshot()}
    for i, p in ipairs(self.piles) do
        local copy = {}
        for j, c in ipairs(p.cards) do copy[j] = c end
        snap.piles[i] = copy
    end
    for _, c in ipairs(self.cards) do snap.faceUp[c] = c.faceUp end
    return snap
end

function KlondikeGame:pushHistory()
    self.history[#self.history + 1] = self:snapshot()
end

-- Mark a card as travelling between piles so it draws above the table
function KlondikeGame:launch(card)
    if not card.flying then
        card.flying = true
        self.flyLayer[#self.flyLayer + 1] = card
    end
end

-- Move cards; returns true on success. Validates first.
function KlondikeGame:moveCards(from, index, to)
    if self.state ~= "playing" or not self:canMove(from, index, to) then
        return false
    end
    self.scoring:begin()
    self:pushHistory()
    self.hint = nil

    local moved = from:removeCardsFrom(index)
    for _, card in ipairs(moved) do
        card.dragging = false
        self:launch(card)
    end
    to:addCards(moved)
    self.scoring:onMove(from.kind, to.kind)

    if from.kind == "waste" then
        self.waste:onTopTaken()
    elseif from.kind == "tableau" and from:flipTopCard() then
        self.scoring:onFlip()
        self:emit("flip", from:getTopCard())
    end

    self:emit("move", {from = from, to = to, cards = moved})
    if to.kind == "foundation" and to:isComplete() then
        self:emit("foundationComplete", to)
    end
    self:checkWin()
    return true
end

-- Click on the stock: draw, or turn the waste back over
function KlondikeGame:drawStock()
    if self.state ~= "playing" then return false end
    if self.stock:isEmpty() then
        if self.waste:isEmpty() then
            self:emit("invalid")
            return false
        end
        self.scoring:begin()
        self:pushHistory()
        local cards = self.waste.cards
        self.waste:clear()
        self.waste.fanCount = 0
        self.stock:reset(cards)
        for _, c in ipairs(cards) do self:launch(c) end
        self.scoring:onRecycle()
        self:emit("recycle")
    else
        self.scoring:begin()
        self:pushHistory()
        local drawn = {}
        for _ = 1, self.drawCount do
            local card = self.stock:removeCard()
            if not card then break end
            self:launch(card)
            drawn[#drawn + 1] = card
        end
        self.waste:addFromStock(drawn)
        self:emit("draw", drawn)
    end
    self.hint = nil
    return true
end

-- Step back one action. Cards fly home; the clock keeps running.
function KlondikeGame:undo()
    if #self.history == 0 or self:isBusy() then return false end
    self:cancelDrag()
    local snap = table.remove(self.history)

    local before = {}
    for _, p in ipairs(self.piles) do
        for _, c in ipairs(p.cards) do before[c] = p end
    end

    for i, p in ipairs(self.piles) do
        p:setCards(snap.piles[i])
        for _, c in ipairs(p.cards) do
            if before[c] ~= p then self:launch(c) end
        end
    end
    for c, up in pairs(snap.faceUp) do
        c:setFaceUp(up, false)
    end
    self.waste.fanCount = snap.fan
    self.scoring:restore(snap.scoring)
    for _, p in ipairs(self.piles) do p:updateCardPositions() end

    self.state = "playing"
    self.scoring.finished = false
    self.autoCompleting = false
    self.hint = nil
    self:emit("undo")
    return true
end

-- Start auto-completing (moves run from update)
function KlondikeGame:startAutoComplete()
    if not self:canAutoComplete() then return false end
    self:cancelDrag()
    self.autoCompleting = true
    self.autoTimer = 0
    return true
end

-- One auto-complete step: lowest card that can go up goes up
function KlondikeGame:autoStep()
    local best, bestFrom, bestTo = nil, nil, nil
    for _, t in ipairs(self.tableaus) do
        local top = t:getTopCard()
        if top and (not best or top.value < best.value) then
            for _, f in ipairs(self.foundations) do
                if f:canAccept({top}) then
                    best, bestFrom, bestTo = top, t, f
                    break
                end
            end
        end
    end
    if best then
        return self:moveCards(bestFrom, bestFrom:count(), bestTo)
    end
    return false
end

-- Show a hint; returns the hint (or nil when stuck)
function KlondikeGame:showHint()
    local h = self:findHint()
    self.hint = h and {move = h, time = 0} or nil
    return h
end

function KlondikeGame:checkWin()
    for _, f in ipairs(self.foundations) do
        if not f:isComplete() then return false end
    end
    self.state = "won"
    self.autoCompleting = false
    self.scoring:stop()
    self:emit("win")
    return true
end

--------------------------------------------------
-- POINTER INPUT
--------------------------------------------------

-- Topmost pile and card under a point
function KlondikeGame:hitTest(x, y)
    for _, t in ipairs(self.tableaus) do
        local i, card = t:findCardAtPoint(x, y)
        if card then return t, i, card end
        if t:isEmpty() and t:containsPoint(x, y) then return t end
    end
    local i, card = self.waste:findCardAtPoint(x, y)
    if card then return self.waste, i, card end
    for _, f in ipairs(self.foundations) do
        if f:containsPoint(x, y) then
            local n = f:count()
            return f, n > 0 and n or nil, f:getTopCard()
        end
    end
    if self.stock:containsPoint(x, y) then return self.stock end
    return nil
end

-- What the pointer can act on (for the hand cursor)
function KlondikeGame:isInteractiveAt(x, y)
    if self.state ~= "playing" or self:isBusy() then return false end
    local pile, index, card = self:hitTest(x, y)
    if pile == self.stock then return true end
    return card ~= nil and card.faceUp and pile:canPickUp(index)
end

function KlondikeGame:mousepressed(x, y, button)
    if button ~= 1 or self.state ~= "playing" or self:isBusy() then return end
    local pile, index, card = self:hitTest(x, y)
    if not pile then return end

    if pile == self.stock then
        self:drawStock()
        return
    end
    if card and card.faceUp and pile:canPickUp(index) then
        self.press = {pile = pile, index = index, x = x, y = y, offX = x - card.x, offY = y - card.y}
    end
end

function KlondikeGame:mousemoved(x, y)
    self.mouseX, self.mouseY = x, y
    self.hoverCard = nil
    if not self.drag and not self.press and self:isInteractiveAt(x, y) then
        local _, _, card = self:hitTest(x, y)
        self.hoverCard = card
    end
    local p = self.press
    if p and not self.drag then
        local dx, dy = x - p.x, y - p.y
        if dx * dx + dy * dy > KlondikeGame.DRAG_THRESHOLD ^ 2 then
            self:beginDrag()
        end
    end
    if self.drag then
        self:positionDragCards()
    end
end

function KlondikeGame:mousereleased(x, y, button)
    if button ~= 1 then return end
    if self.drag then
        self:endDrag()
    elseif self.press then
        local p = self.press
        self.press = nil
        local to = self:findSmartTarget(p.pile, p.index)
        if not (to and self:moveCards(p.pile, p.index, to)) and p.pile.kind ~= "foundation" then
            local card = p.pile:getCardAt(p.index)
            if card then card.shake = 1 end
            self:emit("invalid")
        end
    end
    self.press = nil
end

function KlondikeGame:beginDrag()
    local p = self.press
    self.press = nil
    local cards = p.pile:slice(p.index)
    local base = cards[1]
    local offsets = {}
    for i, c in ipairs(cards) do
        -- keep each card's spacing exactly as it was in the pile
        offsets[i] = {c.targetX - base.targetX, c.targetY - base.targetY}
        c.dragging = true
        c.animating = false
    end
    self.drag = {
        pile = p.pile, index = p.index, cards = cards, offsets = offsets,
        offX = p.offX, offY = p.offY, tilt = 0, lastX = self.mouseX,
    }
    self.hint = nil
    self:positionDragCards()
    self:emit("pickup", cards)
end

function KlondikeGame:positionDragCards()
    local d = self.drag
    local bx, by = self.mouseX - d.offX, self.mouseY - d.offY
    for i, c in ipairs(d.cards) do
        c.x, c.y = bx + d.offsets[i][1], by + d.offsets[i][2]
        c.targetX, c.targetY = c.x, c.y
    end
end

-- Bounds of the dragged stack
function KlondikeGame:dragBounds()
    local d = self.drag
    local first, last = d.cards[1], d.cards[#d.cards]
    return first.x, first.y, Card.WIDTH, (last.y - first.y) + Card.HEIGHT
end

local function overlapArea(x1, y1, w1, h1, x2, y2, w2, h2)
    local ox = math.max(0, math.min(x1 + w1, x2 + w2) - math.max(x1, x2))
    local oy = math.max(0, math.min(y1 + h1, y2 + h2) - math.max(y1, y2))
    return ox * oy
end

-- Valid pile the dragged cards overlap most (ties: nearest centre)
function KlondikeGame:findDropTarget()
    local d = self.drag
    if not d then return nil end
    local x, y, w, h = self:dragBounds()
    -- only the top card's footprint matters for single cards; for runs the
    -- leading card decides, so use the first card's box
    h = Card.HEIGHT
    local best, bestArea, bestDist = nil, 0, math.huge
    for _, to in ipairs(self.targets) do
        if self:canMove(d.pile, d.index, to) then
            local px, py, pw, ph = to:getBounds()
            if to.kind == "tableau" and not to:isEmpty() then
                -- the landing spot is the pile's top card
                px, py = to:cardPosition(to:count())
                pw, ph = Card.WIDTH, Card.HEIGHT
            end
            local area = overlapArea(x, y, w, h, px, py, pw, ph)
            if area > 0 then
                local dist = (x + w / 2 - (px + pw / 2)) ^ 2 + (y + h / 2 - (py + ph / 2)) ^ 2
                if area > bestArea or (area == bestArea and dist < bestDist) then
                    best, bestArea, bestDist = to, area, dist
                end
            end
        end
    end
    return best
end

function KlondikeGame:endDrag()
    local d = self.drag
    local to = self:findDropTarget()
    self.drag = nil
    if to and self:moveCards(d.pile, d.index, to) then
        return
    end
    -- no valid target: the cards glide home
    for _, c in ipairs(d.cards) do
        c.dragging = false
        self:launch(c)
    end
    d.pile:updateCardPositions()
    self:emit("return", d.cards)
end

function KlondikeGame:cancelDrag()
    if self.drag then
        local d = self.drag
        self.drag = nil
        for _, c in ipairs(d.cards) do
            c.dragging = false
            self:launch(c)
        end
        d.pile:updateCardPositions()
    end
    self.press = nil
end

--------------------------------------------------
-- UPDATE / DRAW
--------------------------------------------------

function KlondikeGame:update(dt, paused)
    if not paused and self.dealing <= 0 then
        self.scoring:update(dt)
    end
    if self.dealing > 0 then
        self.dealing = math.max(0, self.dealing - dt)
    end

    for _, c in ipairs(self.cards) do
        if c.delay and c.delay > 0 then
            c.delay = c.delay - dt
            if c.delay <= 0 then c.delay = 0 end
        else
            c:update(dt)
        end
        if c.shake > 0 then
            c.shake = math.max(0, c.shake - dt * 3)
        end
        local lift = (c == self.hoverCard and not self.drag) and 1 or 0
        c.lift = c.lift + (lift - c.lift) * math.min(1, dt * 16)
    end

    -- drop settled cards from the flight layer
    for i = #self.flyLayer, 1, -1 do
        if not self.flyLayer[i].flying then table.remove(self.flyLayer, i) end
    end

    if self.drag then
        local d = self.drag
        local vx = (self.mouseX - d.lastX) / math.max(dt, 1e-3)
        d.lastX = self.mouseX
        local target = math.max(-1, math.min(1, vx / 1500)) * 0.08
        d.tilt = d.tilt + (target - d.tilt) * math.min(1, dt * 12)
    end

    if self.autoCompleting then
        self.autoTimer = self.autoTimer - dt
        if self.autoTimer <= 0 then
            self.autoTimer = KlondikeGame.AUTO_STEP
            if not self:autoStep() then self.autoCompleting = false end
        end
    end

    if self.hint then
        self.hint.time = self.hint.time + dt
        if self.hint.time > 2.4 then self.hint = nil end
    end
end

-- Valid drop targets for the current drag (for highlighting)
function KlondikeGame:dropTargets()
    local list = {}
    local d = self.drag
    if not d then return list end
    for _, to in ipairs(self.targets) do
        if self:canMove(d.pile, d.index, to) then list[#list + 1] = to end
    end
    return list
end

-- Draw cards only; the table, slots and glows are drawn by the caller
function KlondikeGame:drawCards()
    self.stock:draw()
    self.waste:draw()
    for _, f in ipairs(self.foundations) do f:draw() end
    for _, t in ipairs(self.tableaus) do t:draw() end
    for _, c in ipairs(self.flyLayer) do
        if not c.dragging and not c.hidden and c.delay <= 0 then c:draw() end
    end
    -- cards still waiting to be dealt sit on the stock, last-dealt underneath
    for i = #self.cards, 1, -1 do
        local c = self.cards[i]
        if c.delay > 0 then c:draw() end
    end
    if self.drag then
        for _, c in ipairs(self.drag.cards) do c:draw({lifted = true, tilt = self.drag.tilt}) end
    end
    love.graphics.setColor(1, 1, 1)
end

return KlondikeGame
