-- Animation utilities for smooth transitions and effects
-- Includes easing functions and tween management

local Animation = {}

-- Active tweens
local tweens = {}
local tweenId = 0

--------------------------------------------------
-- EASING FUNCTIONS
--------------------------------------------------

Animation.ease = {}

-- Linear
function Animation.ease.linear(t)
    return t
end

-- Quadratic
function Animation.ease.inQuad(t)
    return t * t
end

function Animation.ease.outQuad(t)
    return t * (2 - t)
end

function Animation.ease.inOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

-- Cubic
function Animation.ease.inCubic(t)
    return t * t * t
end

function Animation.ease.outCubic(t)
    local t1 = t - 1
    return t1 * t1 * t1 + 1
end

function Animation.ease.inOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        local t1 = 2 * t - 2
        return 0.5 * t1 * t1 * t1 + 1
    end
end

-- Exponential
function Animation.ease.inExpo(t)
    if t == 0 then return 0 end
    return math.pow(2, 10 * (t - 1))
end

function Animation.ease.outExpo(t)
    if t == 1 then return 1 end
    return 1 - math.pow(2, -10 * t)
end

function Animation.ease.inOutExpo(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    if t < 0.5 then
        return 0.5 * math.pow(2, 20 * t - 10)
    else
        return 1 - 0.5 * math.pow(2, -20 * t + 10)
    end
end

-- Back (overshoots then returns)
function Animation.ease.outBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

function Animation.ease.inBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return c3 * t * t * t - c1 * t * t
end

-- Bounce
function Animation.ease.outBounce(t)
    local n1 = 7.5625
    local d1 = 2.75

    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return n1 * t * t + 0.984375
    end
end

--------------------------------------------------
-- TWEEN MANAGEMENT
--------------------------------------------------

-- Create a new tween
-- target: table to modify
-- props: table of property -> target value
-- duration: time in seconds
-- easingFunc: optional easing function (default: outQuad)
-- onComplete: optional callback when done
function Animation.tween(target, props, duration, easingFunc, onComplete)
    tweenId = tweenId + 1

    local tween = {
        id = tweenId,
        target = target,
        duration = duration,
        elapsed = 0,
        easing = easingFunc or Animation.ease.outQuad,
        onComplete = onComplete,
        properties = {}
    }

    -- Store start and end values for each property
    for prop, endValue in pairs(props) do
        tween.properties[prop] = {
            start = target[prop],
            endVal = endValue
        }
    end

    table.insert(tweens, tween)
    return tweenId
end

-- Cancel a tween by ID
function Animation.cancel(id)
    for i, tween in ipairs(tweens) do
        if tween.id == id then
            table.remove(tweens, i)
            return true
        end
    end
    return false
end

-- Cancel all tweens for a target
function Animation.cancelAll(target)
    for i = #tweens, 1, -1 do
        if tweens[i].target == target then
            table.remove(tweens, i)
        end
    end
end

-- Update all tweens
function Animation.update(dt)
    for i = #tweens, 1, -1 do
        local tween = tweens[i]
        tween.elapsed = tween.elapsed + dt

        local progress = math.min(1, tween.elapsed / tween.duration)
        local easedProgress = tween.easing(progress)

        -- Update properties
        for prop, values in pairs(tween.properties) do
            tween.target[prop] = values.start + (values.endVal - values.start) * easedProgress
        end

        -- Check if complete
        if progress >= 1 then
            if tween.onComplete then
                tween.onComplete(tween.target)
            end
            table.remove(tweens, i)
        end
    end
end

-- Check if any tweens are active
function Animation.isActive()
    return #tweens > 0
end

-- Get number of active tweens
function Animation.count()
    return #tweens
end

-- Clear all tweens
function Animation.clear()
    tweens = {}
end

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------

-- Lerp (linear interpolation)
function Animation.lerp(a, b, t)
    return a + (b - a) * t
end

-- Clamp value between min and max
function Animation.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Map value from one range to another
function Animation.map(value, inMin, inMax, outMin, outMax)
    return outMin + (outMax - outMin) * ((value - inMin) / (inMax - inMin))
end

-- Smoothstep interpolation
function Animation.smoothstep(edge0, edge1, x)
    local t = Animation.clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end

return Animation
