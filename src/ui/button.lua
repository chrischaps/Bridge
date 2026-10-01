-- Engraved brass-plate button for the rail and panels

local Theme = require("src.ui.theme")

local Button = {}
Button.__index = Button

-- style: "plate" (walnut with brass rim) or "gold" (the call to action)
function Button.new(x, y, width, height, text, onClick, style)
    local self = setmetatable({}, Button)
    self.x, self.y = x, y
    self.width, self.height = width, height
    self.text = text or ""
    self.onClick = onClick
    self.style = style or "plate"

    self.hovered = false
    self.pressed = false
    self.enabled = true
    self.visible = true
    self.hover = 0     -- eased 0..1
    self.pulse = false -- gentle glow to draw the eye
    self.time = 0
    return self
end

function Button:setText(text)
    self.text = text
end

function Button:setPosition(x, y)
    self.x, self.y = x, y
end

function Button:setEnabled(enabled)
    self.enabled = enabled
end

function Button:setVisible(visible)
    self.visible = visible
    if not visible then self.hovered, self.pressed = false, false end
end

function Button:containsPoint(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
end

function Button:isActive()
    return self.visible and self.enabled
end

function Button:mousepressed(x, y, button)
    if not self:isActive() or button ~= 1 then return false end
    if self:containsPoint(x, y) then
        self.pressed = true
        return true
    end
    return false
end

function Button:mousereleased(x, y, button)
    if button ~= 1 then return false end
    local wasPressed = self.pressed
    self.pressed = false
    if wasPressed and self:isActive() and self:containsPoint(x, y) then
        if self.onClick then self.onClick() end
        return true
    end
    return false
end

function Button:mousemoved(x, y)
    self.hovered = self:isActive() and self:containsPoint(x, y)
end

function Button:update(dt)
    self.time = self.time + dt
    local target = self.hovered and 1 or 0
    self.hover = self.hover + (target - self.hover) * math.min(1, dt * 14)
end

function Button:draw()
    if not self.visible then return end
    local C = Theme.colors
    local x, y, w, h = self.x, self.y, self.width, self.height
    local a = self.enabled and 1 or 0.45
    local lift = (self.pressed and 0 or self.hover * 1)
    y = y - lift

    -- drop shadow
    love.graphics.setColor(0, 0, 0, 0.35 * a)
    love.graphics.rectangle("fill", x + 1, y + 2 + lift, w, h, 4)

    if self.style == "gold" then
        local glow = self.pulse and (0.5 + 0.5 * math.sin(self.time * 3)) or 0
        if glow > 0 then
            love.graphics.setColor(C.brassLight[1], C.brassLight[2], C.brassLight[3], 0.25 * glow)
            love.graphics.rectangle("fill", x - 4, y - 4, w + 8, h + 8, 7)
        end
        Theme.setColor(self.pressed and C.brassDark or C.brass, a)
        love.graphics.rectangle("fill", x, y, w, h, 4)
        love.graphics.setColor(1, 1, 1, (0.12 + 0.18 * self.hover) * a)
        love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h / 2 - 1, 3)
        Theme.setColor(C.brassLight, a)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 4)
    else
        local top = self.pressed and C.railBottom or C.railTop
        Theme.setColor(top, a)
        love.graphics.rectangle("fill", x, y, w, h, 4)
        love.graphics.setColor(1, 0.9, 0.7, (0.05 + 0.08 * self.hover) * a)
        love.graphics.rectangle("fill", x + 1, y + 1, w - 2, h / 2 - 1, 3)
        local rim = C.brassDark
        love.graphics.setColor(
            rim[1] + (C.brass[1] - rim[1]) * self.hover,
            rim[2] + (C.brass[2] - rim[2]) * self.hover,
            rim[3] + (C.brass[3] - rim[3]) * self.hover, a)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 4)
    end

    -- label
    local font = Theme.font("button")
    love.graphics.setFont(font)
    local tx = math.floor(x + (w - font:getWidth(self.text)) / 2 + 0.5)
    local ty = math.floor(y + (h - font:getHeight()) / 2 + 0.5)
    if self.style == "gold" then
        Theme.setColor(C.inkBlack, 0.9 * a)
        love.graphics.print(self.text, tx, ty)
    else
        love.graphics.setColor(0, 0, 0, 0.5 * a)
        love.graphics.print(self.text, tx, ty + 1)
        local c = C.creamDim
        love.graphics.setColor(
            c[1] + (C.cream[1] - c[1]) * self.hover,
            c[2] + (C.cream[2] - c[2]) * self.hover,
            c[3] + (C.cream[3] - c[3]) * self.hover, a)
        love.graphics.print(self.text, tx, ty)
    end
    love.graphics.setColor(1, 1, 1)
end

return Button
