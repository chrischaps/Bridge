-- Simple button UI component
-- Handles rendering and click detection

local Button = {}
Button.__index = Button

-- Default colors
Button.COLORS = {
    normal = {0.2, 0.4, 0.3, 0.9},
    hover = {0.25, 0.5, 0.35, 0.95},
    pressed = {0.15, 0.35, 0.25, 1},
    text = {1, 1, 1, 1},
    border = {0.3, 0.5, 0.4, 1},
}

-- Create a new button
function Button.new(x, y, width, height, text, onClick)
    local self = setmetatable({}, Button)

    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.text = text or ""
    self.onClick = onClick

    -- State
    self.hovered = false
    self.pressed = false
    self.enabled = true
    self.visible = true

    -- Customization
    self.colors = {}
    for k, v in pairs(Button.COLORS) do
        self.colors[k] = v
    end

    self.cornerRadius = 5
    self.font = nil

    return self
end

-- Set button text
function Button:setText(text)
    self.text = text
end

-- Set button position
function Button:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Set button size
function Button:setSize(width, height)
    self.width = width
    self.height = height
end

-- Set custom colors
function Button:setColor(colorType, r, g, b, a)
    self.colors[colorType] = {r, g, b, a or 1}
end

-- Set custom font
function Button:setFont(font)
    self.font = font
end

-- Enable/disable button
function Button:setEnabled(enabled)
    self.enabled = enabled
end

-- Show/hide button
function Button:setVisible(visible)
    self.visible = visible
end

-- Check if point is inside button
function Button:containsPoint(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
end

-- Handle mouse press
function Button:mousepressed(x, y, button)
    if not self.visible or not self.enabled then return false end
    if button ~= 1 then return false end

    if self:containsPoint(x, y) then
        self.pressed = true
        return true
    end
    return false
end

-- Handle mouse release
function Button:mousereleased(x, y, button)
    if not self.visible or not self.enabled then return false end
    if button ~= 1 then return false end

    if self.pressed and self:containsPoint(x, y) then
        self.pressed = false
        if self.onClick then
            self.onClick()
        end
        return true
    end

    self.pressed = false
    return false
end

-- Handle mouse move
function Button:mousemoved(x, y)
    if not self.visible or not self.enabled then
        self.hovered = false
        return
    end

    self.hovered = self:containsPoint(x, y)

    if not self.hovered then
        self.pressed = false
    end
end

-- Update button state
function Button:update(dt)
    -- Could add animation here
end

-- Draw the button
function Button:draw()
    if not self.visible then return end

    -- Determine current color
    local color
    if not self.enabled then
        color = {self.colors.normal[1] * 0.5, self.colors.normal[2] * 0.5,
                 self.colors.normal[3] * 0.5, self.colors.normal[4] * 0.5}
    elseif self.pressed then
        color = self.colors.pressed
    elseif self.hovered then
        color = self.colors.hover
    else
        color = self.colors.normal
    end

    -- Draw background
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, self.cornerRadius)

    -- Draw border
    love.graphics.setColor(self.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, self.cornerRadius)

    -- Draw text
    local oldFont = love.graphics.getFont()
    if self.font then
        love.graphics.setFont(self.font)
    end

    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.text)
    local textHeight = font:getHeight()

    local textX = self.x + (self.width - textWidth) / 2
    local textY = self.y + (self.height - textHeight) / 2

    -- Text shadow
    love.graphics.setColor(0, 0, 0, self.enabled and 0.5 or 0.25)
    love.graphics.print(self.text, textX + 1, textY + 1)

    -- Text
    local textColor = self.colors.text
    if not self.enabled then
        love.graphics.setColor(textColor[1] * 0.5, textColor[2] * 0.5,
                               textColor[3] * 0.5, textColor[4] * 0.5)
    else
        love.graphics.setColor(textColor)
    end
    love.graphics.print(self.text, textX, textY)

    if self.font then
        love.graphics.setFont(oldFont)
    end

    love.graphics.setColor(1, 1, 1)
end

return Button
