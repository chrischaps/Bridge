-- Scoring system for Klondike Solitaire
-- Based on classic Windows Solitaire "standard" scoring

local Scoring = {}
Scoring.__index = Scoring

-- Score values
Scoring.POINTS = {
    TO_FOUNDATION = 10,         -- Waste or tableau card to foundation
    WASTE_TO_TABLEAU = 5,       -- Card from waste to tableau
    FLIP_TABLEAU = 5,           -- Turn over tableau card
    FROM_FOUNDATION = -15,      -- Card taken back off a foundation
    RECYCLE_DRAW1 = -100,       -- Each pass through the deck after the first (Draw 1)
    RECYCLE_DRAW3 = -20,        -- Each pass after the third (Draw 3)
}

-- Create a new scoring instance
function Scoring.new()
    local self = setmetatable({}, Scoring)
    self:start(1)
    return self
end

-- Start/reset for a new deal. The clock waits for the first action.
function Scoring:start(drawMode)
    self.score = 0
    self.moves = 0
    self.elapsedTime = 0
    self.started = false
    self.finished = false
    self.wasteRecycles = 0
    self.drawMode = drawMode or 1
end

-- First action of the game starts the clock
function Scoring:begin()
    self.started = true
end

-- Stop the timer (game over)
function Scoring:stop()
    self.finished = true
end

function Scoring:isRunning()
    return self.started and not self.finished
end

-- Advance the clock (caller decides when the game is paused)
function Scoring:update(dt)
    if self:isRunning() then
        self.elapsedTime = self.elapsedTime + dt
    end
end

-- Add points (score never goes below zero)
function Scoring:addPoints(points)
    self.score = math.max(0, self.score + points)
end

-- A card (or run) moved from one pile kind to another
function Scoring:onMove(fromKind, toKind)
    self.moves = self.moves + 1
    if toKind == "foundation" then
        self:addPoints(Scoring.POINTS.TO_FOUNDATION)
    elseif fromKind == "foundation" then
        self:addPoints(Scoring.POINTS.FROM_FOUNDATION)
    elseif fromKind == "waste" and toKind == "tableau" then
        self:addPoints(Scoring.POINTS.WASTE_TO_TABLEAU)
    end
end

-- Tableau card turned face up
function Scoring:onFlip()
    self:addPoints(Scoring.POINTS.FLIP_TABLEAU)
end

-- Waste turned back over into the stock
function Scoring:onRecycle()
    self.wasteRecycles = self.wasteRecycles + 1
    if self.drawMode == 1 then
        self:addPoints(Scoring.POINTS.RECYCLE_DRAW1)
    elseif self.wasteRecycles >= 3 then
        self:addPoints(Scoring.POINTS.RECYCLE_DRAW3)
    end
end

-- Get current score
function Scoring:getScore()
    return self.score
end

-- Get move count
function Scoring:getMoves()
    return self.moves
end

-- Get elapsed time in seconds
function Scoring:getTime()
    return self.elapsedTime
end

-- Format seconds as M:SS (or H:MM:SS)
function Scoring.formatTime(t)
    t = math.floor(t)
    local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

function Scoring:getTimeString()
    return Scoring.formatTime(self.elapsedTime)
end

-- Time bonus for winning (games over 30 seconds)
function Scoring:getTimeBonus()
    if self.elapsedTime <= 30 then
        return 0
    end
    return math.floor(700000 / self.elapsedTime)
end

-- Get final score with time bonus
function Scoring:getFinalScore()
    return self.score + self:getTimeBonus()
end

-- Undo support: the clock is deliberately not part of the snapshot
function Scoring:snapshot()
    return {score = self.score, moves = self.moves, wasteRecycles = self.wasteRecycles}
end

function Scoring:restore(snap)
    self.score = snap.score
    self.moves = snap.moves
    self.wasteRecycles = snap.wasteRecycles
end

return Scoring
