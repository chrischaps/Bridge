-- Gold dust that lifts off a foundation when a card lands

local Theme = require("src.ui.theme")

local Sparkle = {}

local motes = {}

-- Burst of `count` motes around (x, y); bigger = a completed suit
function Sparkle.burst(x, y, w, h, count, big)
    for _ = 1, count do
        local edge = love.math.random()
        local px, py
        -- start along the card's edge
        if edge < 0.5 then
            px, py = x + love.math.random() * w, y + (love.math.random() < 0.5 and 0 or h)
        else
            px, py = x + (love.math.random() < 0.5 and 0 or w), y + love.math.random() * h
        end
        local a = math.atan2(py - (y + h / 2), px - (x + w / 2))
        local speed = (big and 60 or 30) + love.math.random() * (big and 90 or 40)
        motes[#motes + 1] = {
            x = px, y = py,
            vx = math.cos(a) * speed, vy = math.sin(a) * speed - 20,
            life = 0, maxLife = 0.5 + love.math.random() * (big and 0.9 or 0.4),
            size = 0.6 + love.math.random() * (big and 1.6 or 1.0),
        }
    end
end

function Sparkle.update(dt)
    for i = #motes, 1, -1 do
        local m = motes[i]
        m.life = m.life + dt
        if m.life >= m.maxLife then
            table.remove(motes, i)
        else
            m.vx = m.vx * (1 - dt * 2.5)
            m.vy = m.vy * (1 - dt * 2.5) - 12 * dt
            m.x = m.x + m.vx * dt
            m.y = m.y + m.vy * dt
        end
    end
end

function Sparkle.draw()
    if #motes == 0 then return end
    local c = Theme.colors.brassLight
    love.graphics.setBlendMode("add")
    for _, m in ipairs(motes) do
        local t = m.life / m.maxLife
        local a = (1 - t) ^ 1.5
        love.graphics.setColor(c[1], c[2], c[3], 0.8 * a)
        love.graphics.circle("fill", m.x, m.y, m.size * (1 - t * 0.5), 8)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1)
end

function Sparkle.clear()
    motes = {}
end

return Sparkle
