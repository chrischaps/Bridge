-- Scripted screenshots: `lovec . --shot <name> [--size WxH]`
-- Each scenario sets up a known state, runs a fixed number of 1/60 s frames,
-- then saves shots/<name>_<w>x<h>.png in the save directory and quits.

local Fixtures = require("src.dev.fixtures")

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
end

-- Simulate the pointer (virtual coordinates)
local function press(g, x, y) g:mousemoved(x, y); g:mousepressed(x, y, 1) end
local function moveTo(g, x, y) g:mousemoved(x, y) end

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
    gallery = {frames = 3, gallery = true, setup = function(ctx)
        ctx.game:deal(1, 1, false)
    end},
    win = {frames = 150, setup = function(ctx)
        local g = ctx.game
        g:deal(1, 9, false)
        Fixtures.place(g, Fixtures.solvedSpec())
        settle(g)
        g.scoring:begin()
        g.scoring.elapsedTime = 254
        g:startAutoComplete()
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
    return self
end

function Capture:isGallery()
    return self.sc.gallery
end

function Capture:update(dt)
    self.frame = self.frame + 1
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
