-- Scoring system for Klondike Solitaire
-- Based on classic Windows Solitaire scoring

local Scoring = {}
Scoring.__index = Scoring

-- Score values
Scoring.POINTS = {
    TO_FOUNDATION = 10,         -- Card moved to foundation
    WASTE_TO_TABLEAU = 5,       -- Card from waste to tableau
    FLIP_TABLEAU = 5,           -- Turn over tableau card
    FROM_FOUNDATION = -15,      -- Card moved from foundation back
    RECYCLE_WASTE = -20,        -- Cycling waste (draw 3 only, after first)
}

-- Create a new scoring instance
function Scoring.new()
    local self = setmetatable({}, Scoring)

    self.score = 0
    self.moves = 0
    self.startTime = 0
    self.elapsedTime = 0
    self.isRunning = false

    -- Track waste recycling (for draw 3 penalty)
    self.wasteRecycles = 0
    self.drawMode = 1  -- 1 or 3

    return self
end

-- Start/reset the game
function Scoring:start(drawMode)
    self.score = 0
    self.moves = 0
    self.startTime = love.timer.getTime()
    self.elapsedTime = 0
    self.isRunning = true
    self.wasteRecycles = 0
    self.drawMode = drawMode or 1
end

-- Stop the timer (game over)
function Scoring:stop()
    self.isRunning = false
end

-- Update timer
function Scoring:update(dt)
    if self.isRunning then
        self.elapsedTime = love.timer.getTime() - self.startTime
    end
end

-- Add points
function Scoring:addPoints(points)
    self.score = math.max(0, self.score + points)
end

-- Record a move
function Scoring:recordMove()
    self.moves = self.moves + 1
end

-- Card moved to foundation
function Scoring:cardToFoundation()
    self:addPoints(Scoring.POINTS.TO_FOUNDATION)
    self:recordMove()
end

-- Card moved from waste to tableau
function Scoring:wasteToTableau()
    self:addPoints(Scoring.POINTS.WASTE_TO_TABLEAU)
    self:recordMove()
end

-- Tableau card flipped face up
function Scoring:tableauFlipped()
    self:addPoints(Scoring.POINTS.FLIP_TABLEAU)
end

-- Card moved from foundation back to tableau
function Scoring:foundationToTableau()
    self:addPoints(Scoring.POINTS.FROM_FOUNDATION)
    self:recordMove()
end

-- Waste recycled (stock reset)
function Scoring:recycleWaste()
    self.wasteRecycles = self.wasteRecycles + 1

    -- Only penalize in draw 3 mode after the first cycle
    if self.drawMode == 3 and self.wasteRecycles > 1 then
        self:addPoints(Scoring.POINTS.RECYCLE_WASTE)
    end
end

-- General move (tableau to tableau, etc.)
function Scoring:generalMove()
    self:recordMove()
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

-- Get formatted time string (MM:SS)
function Scoring:getTimeString()
    local minutes = math.floor(self.elapsedTime / 60)
    local seconds = math.floor(self.elapsedTime % 60)
    return string.format("%02d:%02d", minutes, seconds)
end

-- Calculate time bonus for winning
function Scoring:getTimeBonus()
    if self.elapsedTime <= 30 then
        return 0
    end

    -- Bonus decreases as time increases
    -- Max bonus around 700,000 / time in seconds
    local bonus = math.floor(700000 / self.elapsedTime)
    return math.max(0, bonus)
end

-- Get final score with time bonus
function Scoring:getFinalScore()
    return self.score + self:getTimeBonus()
end

-- Reset scoring
function Scoring:reset()
    self.score = 0
    self.moves = 0
    self.startTime = 0
    self.elapsedTime = 0
    self.isRunning = false
    self.wasteRecycles = 0
end

return Scoring
