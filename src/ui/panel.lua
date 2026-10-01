-- Modal panel: a sheet of card-stock with a gold double frame, a display
-- title, a body and a row of buttons. Used for confirmations, stats and the
-- win screen. Ignores clicks until it has faded in, so a stray click can't
-- dismiss it by accident.

local Theme = require("src.ui.theme")
local Button = require("src.ui.button")

local Panel = {}
Panel.__index = Panel

-- opts: title, width, height, body = function(panel, x, y, w, h, alpha),
--       buttons = {{text, onClick, style}}, onCancel, dim (0..1)
function Panel.new(screenW, screenH, opts)
    local self = setmetatable({}, Panel)
    self.screenW, self.screenH = screenW, screenH
    self.title = opts.title
    self.w = opts.width or 360
    self.h = opts.height or 200
    self.x = math.floor((screenW - self.w) / 2)
    self.y = math.floor((screenH - 44 - self.h) / 2)
    self.body = opts.body
    self.onCancel = opts.onCancel
    self.dim = opts.dim or 0.55
    self.alpha = 0
    self.closing = false
    self.time = 0

    self.buttons = {}
    local list = opts.buttons or {}
    local bw, gap = opts.buttonWidth or 112, 12
    local total = #list * bw + (#list - 1) * gap
    local bx = self.x + (self.w - total) / 2
    for i, b in ipairs(list) do
        local btn = Button.new(bx + (i - 1) * (bw + gap), self.y + self.h - 46, bw, 28, b[1], b[2], b[3])
        self.buttons[i] = btn
    end
    return self
end

function Panel:isReady()
    return self.alpha >= 0.9 and not self.closing
end

function Panel:close(after)
    self.closing = true
    self.afterClose = after
end

-- True once fully faded out (the owner can drop it)
function Panel:isGone()
    return self.closing and self.alpha <= 0
end

function Panel:update(dt)
    self.time = self.time + dt
    if self.closing then
        self.alpha = math.max(0, self.alpha - dt * 6)
        if self.alpha <= 0 and self.afterClose then
            local f = self.afterClose
            self.afterClose = nil
            f()
        end
    else
        self.alpha = math.min(1, self.alpha + dt * 4)
    end
    for _, b in ipairs(self.buttons) do b:update(dt) end
end

function Panel:mousepressed(x, y, button)
    if not self:isReady() then return true end
    for _, b in ipairs(self.buttons) do
        if b:mousepressed(x, y, button) then return true end
    end
    return true -- modal: swallow everything
end

function Panel:mousereleased(x, y, button)
    if not self:isReady() then
        for _, b in ipairs(self.buttons) do b.pressed = false end
        return true
    end
    for _, b in ipairs(self.buttons) do
        if b:mousereleased(x, y, button) then return true end
    end
    return true
end

function Panel:mousemoved(x, y)
    for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end
end

function Panel:isHoveringButton()
    for _, b in ipairs(self.buttons) do
        if b.hovered then return true end
    end
    return false
end

-- Enter presses the first button, Esc cancels
function Panel:keypressed(key)
    if not self:isReady() then return true end
    if key == "escape" then
        if self.onCancel then self.onCancel() end
    elseif key == "return" or key == "kpenter" or key == "space" then
        local b = self.buttons[1]
        if b and b.onClick then b.onClick() end
    end
    return true
end

-- A frame of thin gold lines with corner diamonds
function Panel.frame(x, y, w, h, alpha)
    local C = Theme.colors
    Theme.setColor(C.gold, alpha)
    love.graphics.setLineWidth(1.2)
    love.graphics.rectangle("line", x + 7, y + 7, w - 14, h - 14, 3)
    Theme.setColor(C.gold, 0.55 * alpha)
    love.graphics.setLineWidth(0.7)
    love.graphics.rectangle("line", x + 11, y + 11, w - 22, h - 22, 2)
    Theme.setColor(C.gold, alpha)
    for _, p in ipairs({{x + 7, y + 7}, {x + w - 7, y + 7}, {x + 7, y + h - 7}, {x + w - 7, y + h - 7}}) do
        love.graphics.polygon("fill", p[1], p[2] - 4, p[1] + 3, p[2], p[1], p[2] + 4, p[1] - 3, p[2])
    end
end

-- A short rule with a diamond in the middle, under titles
function Panel.rule(cx, y, half, alpha)
    local C = Theme.colors
    Theme.setColor(C.gold, 0.8 * alpha)
    love.graphics.setLineWidth(0.8)
    love.graphics.line(cx - half, y, cx - 6, y)
    love.graphics.line(cx + 6, y, cx + half, y)
    love.graphics.polygon("fill", cx, y - 3, cx + 2.5, y, cx, y + 3, cx - 2.5, y)
end

function Panel:draw()
    local a = self.alpha
    if a <= 0 then return end
    local C = Theme.colors
    local ease = 1 - (1 - a) ^ 3

    love.graphics.setColor(0.04, 0.0, 0.01, self.dim * a)
    love.graphics.rectangle("fill", 0, 0, self.screenW, self.screenH)

    love.graphics.push()
    local cx, cy = self.x + self.w / 2, self.y + self.h / 2
    local s = 0.96 + 0.04 * ease
    love.graphics.translate(cx, cy + (1 - ease) * 10)
    love.graphics.scale(s, s)
    love.graphics.translate(-cx, -cy)

    local x, y, w, h = self.x, self.y, self.w, self.h
    -- shadow and card-stock
    love.graphics.setColor(0, 0, 0, 0.45 * a)
    love.graphics.rectangle("fill", x + 3, y + 6, w, h, 8)
    Theme.setColor(C.paperEdge, a)
    love.graphics.rectangle("fill", x, y, w, h, 8)
    Theme.setColor(C.paper, a)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h - 4, 7)
    Panel.frame(x, y, w, h, a)

    if self.title then
        local font = Theme.font("title")
        love.graphics.setFont(font)
        Theme.setColor(C.inkRed, a)
        love.graphics.print(self.title, math.floor(cx - font:getWidth(self.title) / 2), y + 18)
        Panel.rule(cx, y + 20 + font:getHeight() + 2, 70, a)
    end
    if self.body then
        local top = y + (self.title and 74 or 24)
        self.body(self, x + 24, top, w - 48, h - (top - y) - 54, a)
    end
    for _, b in ipairs(self.buttons) do b:draw() end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- Body helper: centred lines of text {text, font role, colour, alpha}
function Panel.textBody(lines)
    return function(panel, x, y, w, h, a)
        local cy = y
        for _, l in ipairs(lines) do
            local font = Theme.font(l[2] or "body")
            love.graphics.setFont(font)
            Theme.setColor(l[3] or Theme.colors.inkBlack, a)
            local text = l[1]
            love.graphics.printf(text, x, cy, w, "center")
            local _, wrapped = font:getWrap(text, w)
            cy = cy + #wrapped * font:getHeight() + (l[4] or 4)
        end
    end
end

return Panel
