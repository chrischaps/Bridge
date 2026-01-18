-- HUD (Heads-Up Display) for Klondike Solitaire
-- Shows score, timer, moves, and game controls

local HUD = {}
HUD.__index = HUD

-- Create a new HUD
function HUD.new(screenWidth, screenHeight)
    local self = setmetatable({}, HUD)

    self.screenWidth = screenWidth
    self.screenHeight = screenHeight

    -- Colors
    self.colors = {
        text = {1, 1, 1, 0.9},
        shadow = {0, 0, 0, 0.5},
        highlight = {1, 0.9, 0.5, 1},
        panel = {0, 0, 0, 0.3},
    }

    -- Font (will use default if not set)
    self.font = nil

    -- Win screen state
    self.showWinScreen = false
    self.winScreenAlpha = 0

    return self
end

-- Set custom font
function HUD:setFont(font)
    self.font = font
end

-- Update dimensions (for resize)
function HUD:resize(width, height)
    self.screenWidth = width
    self.screenHeight = height
end

-- Update HUD state
function HUD:update(dt, scoring, gameWon)
    -- Animate win screen
    if gameWon and not self.showWinScreen then
        self.showWinScreen = true
        self.winScreenAlpha = 0
    end

    if self.showWinScreen then
        self.winScreenAlpha = math.min(1, self.winScreenAlpha + dt * 2)
    else
        self.winScreenAlpha = 0
    end
end

-- Draw text with shadow
local function drawShadowText(text, x, y, colors)
    love.graphics.setColor(colors.shadow)
    love.graphics.print(text, x + 1, y + 1)
    love.graphics.setColor(colors.text)
    love.graphics.print(text, x, y)
end

-- Draw the HUD
function HUD:draw(scoring, drawMode)
    local oldFont = love.graphics.getFont()
    if self.font then
        love.graphics.setFont(self.font)
    end

    local padding = 10
    local lineHeight = 20

    -- Top-left: Score and Moves
    local x = padding
    local y = padding

    drawShadowText("Score: " .. scoring:getScore(), x, y, self.colors)
    drawShadowText("Moves: " .. scoring:getMoves(), x, y + lineHeight, self.colors)

    -- Top-center: Timer
    local timeText = "Time: " .. scoring:getTimeString()
    local timeWidth = love.graphics.getFont():getWidth(timeText)
    drawShadowText(timeText, (self.screenWidth - timeWidth) / 2, y, self.colors)

    -- Top-right: Draw mode indicator
    local modeText = "Draw " .. drawMode
    local modeWidth = love.graphics.getFont():getWidth(modeText)
    drawShadowText(modeText, self.screenWidth - modeWidth - padding, y, self.colors)

    -- Draw win screen if game is won
    if self.showWinScreen then
        self:drawWinScreen(scoring)
    end

    love.graphics.setFont(oldFont)
    love.graphics.setColor(1, 1, 1)
end

-- Draw win celebration screen
function HUD:drawWinScreen(scoring)
    local alpha = self.winScreenAlpha

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Win panel
    local panelWidth = 300
    local panelHeight = 200
    local panelX = (self.screenWidth - panelWidth) / 2
    local panelY = (self.screenHeight - panelHeight) / 2

    -- Panel background
    love.graphics.setColor(0.1, 0.25, 0.15, 0.95 * alpha)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 10)

    -- Panel border
    love.graphics.setColor(0.3, 0.6, 0.4, alpha)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 10)

    -- Title
    love.graphics.setColor(1, 0.9, 0.3, alpha)
    local title = "You Win!"
    local titleFont = love.graphics.getFont()
    local titleWidth = titleFont:getWidth(title)
    love.graphics.print(title, (self.screenWidth - titleWidth) / 2, panelY + 20)

    -- Stats
    love.graphics.setColor(1, 1, 1, alpha)
    local statsY = panelY + 60
    local statsX = panelX + 30
    local lineH = 25

    love.graphics.print("Time: " .. scoring:getTimeString(), statsX, statsY)
    love.graphics.print("Moves: " .. scoring:getMoves(), statsX, statsY + lineH)
    love.graphics.print("Score: " .. scoring:getScore(), statsX, statsY + lineH * 2)

    local timeBonus = scoring:getTimeBonus()
    if timeBonus > 0 then
        love.graphics.setColor(0.5, 1, 0.5, alpha)
        love.graphics.print("Time Bonus: +" .. timeBonus, statsX, statsY + lineH * 3)
    end

    love.graphics.setColor(1, 0.9, 0.5, alpha)
    love.graphics.print("Final Score: " .. scoring:getFinalScore(), statsX, statsY + lineH * 4)

    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.7, alpha)
    local instruction = "Press SPACE or click for new game"
    local instrWidth = titleFont:getWidth(instruction)
    love.graphics.print(instruction, (self.screenWidth - instrWidth) / 2, panelY + panelHeight - 30)
end

-- Reset win screen state
function HUD:reset()
    self.showWinScreen = false
    self.winScreenAlpha = 0
end

return HUD
