-- Scripted screenshots: `lovec . --shot <name> [--size WxH]`
-- Each scenario sets up a known state, runs a fixed number of 1/60 s frames,
-- then saves shots/<name>_<w>x<h>.png in the save directory and quits.

local Fixtures = require("src.dev.fixtures")
local Bot = require("src.dev.bot")
local Card = require("src.cards.card")
local Stats = require("src.games.klondike.stats")
local Sparkle = require("src.ui.sparkle")

local Capture = {}
Capture.__index = Capture

-- Play `n` hinted moves from the current state
local function playHints(g, n)
    for _ = 1, n do
        local h = g:findHint()
        if not h then return end
        if h.draw then g:drawStock() else g:moveCards(h.from, h.index, h.to) end
    end
end

-- Snap every card to rest (skip animations)
local function settle(g)
    for _, c in ipairs(g.cards) do
        c.delay = 0
        c.x, c.y, c.animating, c.flying = c.targetX, c.targetY, false, false
        c.flipProgress, c.flipping = c.faceUp and 1 or 0, false
    end
    g.flyLayer, g.dealing = {}, 0
    Sparkle.clear()
end

-- Simulate the pointer (virtual coordinates)
local function press(g, x, y) g:mousemoved(x, y); g:mousepressed(x, y, 1) end
local function moveTo(g, x, y) g:mousemoved(x, y) end

-- Draw a card centred at (x, y), rotated and scaled, with its shadow
local function placeCard(card, x, y, angle, scale, faceUp, height)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle or 0)
    love.graphics.scale(scale or 1)
    local w, h = Card.WIDTH, Card.HEIGHT
    Card.drawShadow(-w / 2, -h / 2, height or 0.4)
    card:drawAt(-w / 2, -h / 2, 1, faceUp)
    love.graphics.pop()
end

local function findCard(g, rank, suit)
    for _, c in ipairs(g.cards) do
        if c.rank == rank and c.suit == suit then return c end
    end
end

-- All 52 faces in suit rows, like a printer's specimen sheet
local function drawDeck(ctx)
    local cards = {}
    for _, c in ipairs(ctx.game.cards) do cards[#cards + 1] = c end
    local order = {spades = 1, hearts = 2, clubs = 3, diamonds = 4}
    table.sort(cards, function(a, b)
        if a.suit ~= b.suit then return order[a.suit] < order[b.suit] end
        return a.value < b.value
    end)
    local s, dx, dy = 0.84, 70, 106
    local left = (960 - (12 * dx + Card.WIDTH * s)) / 2
    for i, c in ipairs(cards) do
        local col, row = (i - 1) % 13, math.floor((i - 1) / 13)
        local x, y = left + col * dx, 64 + row * dy
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(s)
        Card.drawShadow(0, 0, 0.2)
        love.graphics.pop()
        c:drawAt(x, y, s, true)
    end
end

-- How good a mid-game board looks: plenty face up, foundations under way,
-- a full Draw 3 fan, few hidden cards, no empty columns
local function boardBeauty(g)
    local up, hidden, empty, longest = 0, 0, 0, 0
    for _, t in ipairs(g.tableaus) do
        if t:isEmpty() then empty = empty + 1 end
        local run = 0
        for _, c in ipairs(t.cards) do
            if c.faceUp then up = up + 1 run = run + 1 else hidden = hidden + 1 end
        end
        longest = math.max(longest, run)
    end
    local found = 0
    for _, f in ipairs(g.foundations) do found = found + f:count() end
    if empty > 0 or g.waste.fanCount < 3 or found < 6 or found > 16 then return -1 end
    if longest > 9 then return -1 end
    return up * 2 - hidden + math.min(longest, 7) * 2 + found
end

-- The best-looking Draw 3 board the hint bot reaches over many deals
local function heroBoard(g)
    local best, bestSeed, bestSteps = -1, 1, 0
    for seed = 1, 600 do
        g:deal(3, seed, false)
        for step = 1, 70 do
            local h = g:findHint()
            if not h then break end
            if h.draw then g:drawStock() else g:moveCards(h.from, h.index, h.to) end
            local v = boardBeauty(g)
            if v > best then best, bestSeed, bestSteps = v, seed, step end
        end
    end
    g:deal(3, bestSeed, false)
    for _ = 1, bestSteps do
        local h = g:findHint()
        if h.draw then g:drawStock() else g:moveCards(h.from, h.index, h.to) end
    end
    print(string.format("hero: seed %d after %d actions (beauty %d)", bestSeed, bestSteps, best))
    -- the clock at a steady 3.2 s per action
    g.scoring.elapsedTime = bestSteps * 3.2
end

-- A seeded Draw 1 deal the hint bot wins, played to the last card, then
-- the final move taken back so the win can happen on camera
local function nearlyWon(ctx)
    local g = ctx.game
    for seed = 1, 400 do
        g:deal(1, seed, false)
        if Bot.play(g, 2.4) then
            print("won deal " .. seed .. " in " .. g.scoring:getMoves() .. " moves")
            ctx.clearEffects()
            g:undo()
            return seed
        end
    end
end

Capture.scenarios = {
    deal = {frames = 5, setup = function(ctx)
        ctx.game:deal(1, 1776, false)
    end},
    dealing = {frames = 24, setup = function(ctx)
        ctx.game:deal(1, 1776, true)
    end},
    midgame = {frames = 5, setup = function(ctx)
        ctx.setDrawMode(3)
        ctx.game:deal(3, 31, false)
        playHints(ctx.game, 40)
        settle(ctx.game)
    end},
    longcolumn = {frames = 5, setup = function(ctx)
        local g = ctx.game
        g:deal(1, 5, false)
        Fixtures.place(g, {
            t1 = {"*2C", "*3D", "*4H", "*5S", "*6C", "*7D",
                  "KS", "QH", "JC", "TD", "9S", "8H", "7C", "6H", "5C", "4D", "3S", "2H", "AC"},
            t2 = {"KD"}, t3 = {"*9D", "8S"}, f1 = {"AH"}, w = {"5D", "9H", "QS"},
        })
        settle(g)
    end},
    drag = {frames = 4, setup = function(ctx)
        local g = ctx.game
        g:deal(1, 5, false)
        Fixtures.place(g, {
            t1 = {"*2C", "*3D", "KS", "QH", "JC"}, t2 = {"*4D", "QD"}, t3 = {"*7C", "TH"},
            t4 = {"QC"}, t5 = {}, f1 = {"AH", "2H"}, w = {"5D", "9H", "3H"},
        })
        settle(g)
        -- pick up the K-Q-J run and hover it over the empty column
        local q = g.tableaus[1].cards[3]
        press(g, q.x + 20, q.y + 10)
        moveTo(g, q.x + 30, q.y + 30)
        local t5 = g.tableaus[5]
        moveTo(g, t5.x + 30, t5.y + 25)
        moveTo(g, t5.x + 36, t5.y + 28)
    end},
    hint = {frames = 30, setup = function(ctx)
        ctx.game:deal(1, 1776, false)
        ctx.game:showHint()
    end},
    stats = {frames = 40, setup = function(ctx)
        ctx.game:deal(1, 1776, false)
        ctx.showStats()
    end},
    winpanel = {frames = 60, setup = function(ctx)
        local g = ctx.game
        g:deal(1, 9, false)
        Fixtures.place(g, Fixtures.solvedSpec())
        settle(g)
        g.scoring:begin()
        g.scoring.elapsedTime = 254
        g.scoring.score = 485
        for _ = 1, 52 do g:autoStep() end
        settle(g)
        ctx.showWin()
    end},
    win = {frames = 400, setup = function(ctx)
        local g = ctx.game
        g:deal(1, 9, false)
        Fixtures.place(g, Fixtures.solvedSpec())
        settle(g)
        g.scoring:begin()
        g.scoring.elapsedTime = 254
        g:startAutoComplete()
    end},
    gallery = {frames = 3, zoom = 1.3, setup = function(ctx)
        ctx.game:deal(1, 1, false)
    end, draw = drawDeck},

    ----------------------------------------------------------------
    -- Showcase stills for chaps.dev (render with --size 2560x1440)
    ----------------------------------------------------------------

    ["site-cover"] = {frames = 40, zoom = 2.4, setup = function(ctx)
        ctx.game:deal(1, 1, false)
    end, draw = function(ctx)
        local g = ctx.game
        local hand = {
            {nil, nil}, {"J", "clubs"}, {"Q", "diamonds"}, {"K", "hearts"}, {"A", "spades"},
        }
        local pivotX, pivotY, radius, scale = 480, 712, 420, 2.4
        for i, h in ipairs(hand) do
            local a = (i - 3) * 0.19
            local card = h[1] and findCard(g, h[1], h[2]) or g.cards[1]
            placeCard(card, pivotX + math.sin(a) * radius, pivotY - math.cos(a) * radius,
                a, scale, h[1] ~= nil, 0.5)
        end
    end},

    ["site-table"] = {frames = 4, setup = function(ctx)
        ctx.setDrawMode(3)
        heroBoard(ctx.game)
        settle(ctx.game)
    end},

    ["site-deal"] = {frames = 30, setup = function(ctx)
        ctx.game:deal(1, 1776, true)
    end},

    ["site-drag"] = {frames = 6, setup = function(ctx)
        local g = ctx.game
        ctx.setDrawMode(3)
        heroBoard(g)
        settle(g)
        -- the longest run that can legally move to another column
        local m, len = nil, 0
        for _, mv in ipairs(g:legalMoves()) do
            if mv.from.kind == "tableau" and mv.to.kind == "tableau" then
                local n = mv.from:count() - mv.index + 1
                if n > len then m, len = mv, n end
            end
        end
        if not m then
            for _, mv in ipairs(g:legalMoves()) do
                if mv.from.kind == "waste" and mv.to.kind == "tableau" then m = mv end
            end
        end
        print("drag: " .. m.from.kind .. m.from.index .. " -> " .. m.to.kind .. m.to.index)
        local card = m.from:getCardAt(m.index)
        press(g, card.x + 30, card.y + 12)
        moveTo(g, card.x + 40, card.y + 30)
        local tx, ty = m.to:cardPosition(math.max(1, m.to:count()))
        local dy = m.to:isEmpty() and 0 or 26
        moveTo(g, tx + 30 + 14, ty + dy + 12 + 8)
    end},

    ["site-hint"] = {frames = 20, setup = function(ctx)
        ctx.setDrawMode(3)
        heroBoard(ctx.game)
        settle(ctx.game)
        ctx.game:showHint()
    end},

    ["site-deck"] = {frames = 3, zoom = 1.3, setup = function(ctx)
        ctx.game:deal(1, 1, false)
    end, draw = drawDeck},

    ["site-courts"] = {frames = 3, zoom = 2.6, setup = function(ctx)
        ctx.game:deal(1, 1, false)
    end, draw = function(ctx)
        local g = ctx.game
        local row = {{"A", "spades"}, {"K", "hearts"}, {"Q", "clubs"}, {"J", "diamonds"}}
        local s, gap = 2.0, 18
        local w = Card.WIDTH * s
        local left = (960 - (#row * w + (#row - 1) * gap)) / 2 + w / 2
        for i, r in ipairs(row) do
            local tilt = (i - 2.5) * 0.035
            placeCard(findCard(g, r[1], r[2]), left + (i - 1) * (w + gap),
                262 + math.abs(i - 2.5) * 6, tilt, s, true, 0.6)
        end
    end},

    ["site-cascade"] = {frames = 330, setup = function(ctx)
        local g = ctx.game
        nearlyWon(ctx)
        settle(g)
        local h = g:findHint()
        g:moveCards(h.from, h.index, h.to)
    end},

    ["site-won"] = {frames = 300, setup = function(ctx)
        local g = ctx.game
        nearlyWon(ctx)
        settle(g)
        local h = g:findHint()
        g:moveCards(h.from, h.index, h.to)
    end, at = {[250] = function(ctx) ctx.showWin() end}},

    ["site-ledger"] = {frames = 40, setup = function(ctx)
        local g = ctx.game
        local tally = {[1] = {0, 0}, [3] = {0, 0}}
        for _, mode in ipairs({1, 3}) do
            for seed = 1, 60 do
                g:deal(mode, 5000 + seed, false)
                local won = Bot.play(g, 2.4)
                if won then
                    Stats.recordWin(mode, g.scoring:getTime(), g.scoring:getFinalScore())
                else
                    Stats.recordLoss()
                end
                local t = tally[mode]
                if won then t[1] = t[1] + 1 else t[2] = t[2] + 1 end
            end
        end
        print(string.format("ledger: draw1 %d won / %d lost, draw3 %d won / %d lost",
            tally[1][1], tally[1][2], tally[3][1], tally[3][2]))
        ctx.setDrawMode(1)
        ctx.clearEffects()
        g:deal(1, 1776, false)
        ctx.showStats()
    end},
}

function Capture.start(name, ctx)
    local sc = Capture.scenarios[name]
    if not sc then
        print("unknown scenario '" .. tostring(name) .. "'; have:")
        for k in pairs(Capture.scenarios) do print("  " .. k) end
        love.event.quit(1)
        return nil
    end
    local self = setmetatable({name = name, sc = sc, ctx = ctx, frame = 0, done = false}, Capture)
    sc.setup(ctx)
    -- the rail's rolling score shows the settled value
    if ctx.hud then ctx.hud.scoreShown = ctx.game.scoring:getScore() end
    return self
end

function Capture:update(dt)
    self.frame = self.frame + 1
    local action = self.sc.at and self.sc.at[self.frame]
    if action then action(self.ctx) end
end

-- Scenario-specific drawing in place of the table scene (or nil)
function Capture:customDraw()
    return self.sc.draw and function() self.sc.draw(self.ctx) end
end

function Capture:zoom()
    return self.sc.zoom or 1
end

function Capture:afterDraw()
    if self.done then
        self.quitIn = (self.quitIn or 3) - 1
        if self.quitIn <= 0 then love.event.quit(0) end
        return
    end
    if self.frame >= self.sc.frames then
        love.filesystem.createDirectory("shots")
        local w, h = love.graphics.getDimensions()
        local file = string.format("shots/%s_%dx%d.png", self.name, w, h)
        love.graphics.captureScreenshot(file)
        print("captured " .. love.filesystem.getSaveDirectory() .. "/" .. file)
        self.done = true
    end
end

return Capture
