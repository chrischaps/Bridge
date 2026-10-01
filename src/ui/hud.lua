-- The walnut rail along the bottom of the table: buttons on the left,
-- the running score on the right, a status line in between

local Theme = require("src.ui.theme")
local Scoring = require("src.games.klondike.scoring")

local HUD = {}
HUD.__index = HUD

HUD.HEIGHT = 44

function HUD.new(screenWidth, screenHeight)
    local self = setmetatable({}, HUD)
    self.screenWidth = screenWidth
    self.screenHeight = screenHeight
    self.y = screenHeight - HUD.HEIGHT
    self.status = nil       -- {text=..., time=...}
    self.scoreShown = 0     -- eased score for a rolling counter
    return self
end

-- Brief italic note in the middle of the rail
function HUD:setStatus(text, seconds)
    self.status = text and {text = text, time = seconds or 3} or nil
end

function HUD:update(dt, scoring)
    local target = scoring:getScore()
    local diff = target - self.scoreShown
    if math.abs(diff) < 0.5 then
        self.scoreShown = target
    else
        self.scoreShown = self.scoreShown + diff * math.min(1, dt * 10)
    end
    if self.status then
        self.status.time = self.status.time - dt
        if self.status.time <= 0 then self.status = nil end
    end
end

function HUD:drawRail()
    local C = Theme.colors
    local y, w, h = self.y, self.screenWidth, HUD.HEIGHT

    -- shadow the rail throws onto the felt
    for i = 1, 6 do
        love.graphics.setColor(0, 0, 0, 0.07 * (7 - i) / 6)
        love.graphics.rectangle("fill", 0, y - i, w, 1)
    end

    -- walnut body, top lit
    local mesh = HUD.railMesh
    if not mesh then
        mesh = love.graphics.newMesh({
            {0, 0, 0, 0, C.railTop[1], C.railTop[2], C.railTop[3], 1},
            {1, 0, 0, 0, C.railTop[1], C.railTop[2], C.railTop[3], 1},
            {1, 1, 0, 0, C.railBottom[1], C.railBottom[2], C.railBottom[3], 1},
            {0, 1, 0, 0, C.railBottom[1], C.railBottom[2], C.railBottom[3], 1},
        }, "fan", "static")
        HUD.railMesh = mesh
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(mesh, 0, y, 0, w, h)

    -- fine grain lines in the wood
    local rng = love.math.newRandomGenerator(7)
    for _ = 1, 26 do
        local gy = y + 3 + rng:random() * (h - 6)
        local gx = rng:random() * w
        love.graphics.setColor(0, 0, 0, 0.08 + rng:random() * 0.07)
        love.graphics.rectangle("fill", gx, gy, 60 + rng:random() * 220, 1)
    end

    -- brass inlay along the top edge
    Theme.setColor(C.brassDark)
    love.graphics.rectangle("fill", 0, y, w, 2)
    Theme.setColor(C.brass, 0.85)
    love.graphics.rectangle("fill", 0, y, w, 1)
end

-- Right-hand readout: Score · Moves · Time, and the deal number beneath
function HUD:drawReadout(scoring, dealNumber, drawMode)
    local C = Theme.colors
    local right = self.screenWidth - 18
    local midY = self.y + HUD.HEIGHT / 2

    local items = {
        {"Score", tostring(math.floor(self.scoreShown + 0.5))},
        {"Moves", tostring(scoring:getMoves())},
        {"Time", Scoring.formatTime(scoring:getTime())},
    }
    local label, value = Theme.font("small"), Theme.font("hudBold")
    local x = right
    for i = #items, 1, -1 do
        local item = items[i]
        local vw = value:getWidth(item[2])
        -- fixed slot for the clock so it doesn't jitter as digits change
        local slot = math.max(vw, item[1] == "Time" and value:getWidth("00:00") or 0)
        local lw = label:getWidth(item[1])
        x = x - slot
        Theme.printShadow(item[2], value, x + slot - vw, midY - value:getHeight() / 2 - 1, C.cream)
        x = x - 5 - lw
        Theme.printShadow(item[1], label, x, midY - label:getHeight() / 2, C.creamDim)
        x = x - 22
        if i > 1 then
            Theme.setColor(C.brass, 0.55)
            local dx, dy = x + 11, midY
            love.graphics.polygon("fill", dx, dy - 3, dx + 2, dy, dx, dy + 3, dx - 2, dy)
        end
    end

    self.readoutLeft = x
    if dealNumber then
        local small = Theme.font("small")
        local t = string.format("Deal %d", dealNumber)
        love.graphics.setFont(small)
        Theme.setColor(C.creamDim, 0.55)
        love.graphics.print(t, x - small:getWidth(t) + 4, midY - small:getHeight() / 2)
        self.readoutLeft = x - small:getWidth(t)
    end
end

-- Italic note centred in the free space of the rail
function HUD:drawStatus(left, right)
    if not self.status then return end
    local font = Theme.font("bodyItalic")
    local a = math.min(1, self.status.time * 3)
    local cx = (left + (right or self.readoutLeft or self.screenWidth)) / 2
    love.graphics.setFont(font)
    Theme.printShadow(self.status.text, font,
        math.floor(cx - font:getWidth(self.status.text) / 2),
        math.floor(self.y + (HUD.HEIGHT - font:getHeight()) / 2), Theme.colors.brassLight, a)
end

return HUD
