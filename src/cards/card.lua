-- Card class with procedural rendering
-- Represents a single playing card with suit, rank, position, and animation

local Card = {}
Card.__index = Card

-- Card dimensions (can be overridden)
Card.WIDTH = 71
Card.HEIGHT = 96
Card.CORNER_RADIUS = 6

-- Suit constants
Card.SUITS = {"hearts", "diamonds", "clubs", "spades"}
Card.RANKS = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

-- Colors
Card.COLORS = {
    red = {0.85, 0.15, 0.15},
    black = {0.1, 0.1, 0.1},
    cardFace = {1, 0.98, 0.95},
    cardBack = {0.15, 0.35, 0.55},
    cardBackPattern = {0.12, 0.28, 0.45},
    shadow = {0, 0, 0, 0.3}
}

-- Create a new card
function Card.new(suit, rank)
    local self = setmetatable({}, Card)

    self.suit = suit
    self.rank = rank
    self.faceUp = false

    -- Position
    self.x = 0
    self.y = 0

    -- Animation target
    self.targetX = 0
    self.targetY = 0

    -- Z-index for draw order
    self.zIndex = 0

    -- Animation state
    self.animating = false
    self.animSpeed = 12  -- Animation speed multiplier

    -- Flip animation
    self.flipProgress = 0  -- 0 = fully back, 1 = fully face
    self.flipTarget = 0
    self.flipping = false

    return self
end

-- Check if card is red
function Card:isRed()
    return self.suit == "hearts" or self.suit == "diamonds"
end

-- Get numeric value (Ace = 1, 2-10 = face value, J/Q/K = 11/12/13)
function Card:getValue()
    for i, r in ipairs(Card.RANKS) do
        if r == self.rank then
            return i
        end
    end
    return 0
end

-- Set position immediately
function Card:setPosition(x, y)
    self.x = x
    self.y = y
    self.targetX = x
    self.targetY = y
end

-- Animate to target position
function Card:moveTo(x, y, immediate)
    self.targetX = x
    self.targetY = y
    if immediate then
        self.x = x
        self.y = y
        self.animating = false
    else
        self.animating = true
    end
end

-- Flip the card
function Card:flip(immediate)
    self.faceUp = not self.faceUp
    self.flipTarget = self.faceUp and 1 or 0
    if immediate then
        self.flipProgress = self.flipTarget
        self.flipping = false
    else
        self.flipping = true
    end
end

-- Set face up state
function Card:setFaceUp(faceUp, immediate)
    if self.faceUp ~= faceUp then
        self:flip(immediate)
    end
end

-- Update animation
function Card:update(dt)
    -- Position animation (ease-out)
    if self.animating then
        local dx = self.targetX - self.x
        local dy = self.targetY - self.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < 0.5 then
            self.x = self.targetX
            self.y = self.targetY
            self.animating = false
        else
            local factor = 1 - math.pow(0.01, dt * self.animSpeed)
            self.x = self.x + dx * factor
            self.y = self.y + dy * factor
        end
    end

    -- Flip animation
    if self.flipping then
        local diff = self.flipTarget - self.flipProgress
        if math.abs(diff) < 0.01 then
            self.flipProgress = self.flipTarget
            self.flipping = false
        else
            local factor = 1 - math.pow(0.01, dt * 15)
            self.flipProgress = self.flipProgress + diff * factor
        end
    end
end

-- Check if animation is complete
function Card:isAnimating()
    return self.animating or self.flipping
end

-- Check if point is inside card
function Card:containsPoint(px, py)
    return px >= self.x and px <= self.x + Card.WIDTH
       and py >= self.y and py <= self.y + Card.HEIGHT
end

-- Draw suit symbol
local function drawSuitSymbol(suit, x, y, size)
    love.graphics.push()
    love.graphics.translate(x, y)

    local s = size / 20  -- Scale factor

    if suit == "hearts" then
        -- Heart shape using bezier-like triangles
        love.graphics.polygon("fill",
            0, -6 * s,
            -8 * s, -12 * s,
            -10 * s, -6 * s,
            -8 * s, 0,
            0, 10 * s,
            8 * s, 0,
            10 * s, -6 * s,
            8 * s, -12 * s
        )
    elseif suit == "diamonds" then
        -- Diamond shape
        love.graphics.polygon("fill",
            0, -10 * s,
            -7 * s, 0,
            0, 10 * s,
            7 * s, 0
        )
    elseif suit == "clubs" then
        -- Club shape (three circles + stem)
        local r = 5 * s
        love.graphics.circle("fill", 0, -5 * s, r)
        love.graphics.circle("fill", -5 * s, 2 * s, r)
        love.graphics.circle("fill", 5 * s, 2 * s, r)
        love.graphics.polygon("fill",
            -2 * s, 0,
            2 * s, 0,
            3 * s, 10 * s,
            -3 * s, 10 * s
        )
    elseif suit == "spades" then
        -- Spade shape (inverted heart + stem)
        love.graphics.polygon("fill",
            0, -10 * s,
            -10 * s, 3 * s,
            -8 * s, 8 * s,
            -4 * s, 6 * s,
            0, 10 * s,
            4 * s, 6 * s,
            8 * s, 8 * s,
            10 * s, 3 * s
        )
        love.graphics.polygon("fill",
            -2 * s, 4 * s,
            2 * s, 4 * s,
            3 * s, 10 * s,
            -3 * s, 10 * s
        )
    end

    love.graphics.pop()
end

-- Draw rounded rectangle
local function drawRoundedRect(mode, x, y, w, h, r)
    love.graphics.rectangle(mode, x, y, w, h, r, r)
end

-- Draw card back
local function drawCardBack(x, y, w, h, r)
    -- Main back color
    love.graphics.setColor(Card.COLORS.cardBack)
    drawRoundedRect("fill", x, y, w, h, r)

    -- Pattern (diamond grid)
    love.graphics.setColor(Card.COLORS.cardBackPattern)
    love.graphics.setLineWidth(1)

    local margin = 6
    local spacing = 8

    -- Create a stencil for clipping
    love.graphics.stencil(function()
        drawRoundedRect("fill", x + margin, y + margin, w - margin * 2, h - margin * 2, r - 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    -- Draw diagonal lines
    for i = -20, 30 do
        local offset = i * spacing
        love.graphics.line(x + offset, y, x + offset + h, y + h)
        love.graphics.line(x + offset + h, y, x + offset, y + h)
    end

    love.graphics.setStencilTest()

    -- Border
    love.graphics.setColor(0.1, 0.25, 0.4)
    love.graphics.setLineWidth(2)
    drawRoundedRect("line", x + margin, y + margin, w - margin * 2, h - margin * 2, r - 2)
end

-- Draw card face
local function drawCardFace(card, x, y, w, h, r)
    -- Card background
    love.graphics.setColor(Card.COLORS.cardFace)
    drawRoundedRect("fill", x, y, w, h, r)

    -- Border
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x, y, w, h, r)

    -- Set color based on suit
    local color = card:isRed() and Card.COLORS.red or Card.COLORS.black
    love.graphics.setColor(color)

    -- Draw rank and suit in corners
    local font = love.graphics.getFont()
    local rankText = card.rank
    local cornerX = x + 6
    local cornerY = y + 4

    -- Top-left rank
    love.graphics.print(rankText, cornerX, cornerY)

    -- Top-left small suit
    drawSuitSymbol(card.suit, cornerX + 6, cornerY + 20, 10)

    -- Bottom-right rank (rotated)
    love.graphics.push()
    love.graphics.translate(x + w - 6, y + h - 4)
    love.graphics.rotate(math.pi)
    love.graphics.print(rankText, 0, 0)
    love.graphics.pop()

    -- Bottom-right small suit (rotated)
    love.graphics.push()
    love.graphics.translate(x + w - 12, y + h - 24)
    love.graphics.rotate(math.pi)
    drawSuitSymbol(card.suit, 0, 0, 10)
    love.graphics.pop()

    -- Center suit symbol(s)
    local cx = x + w / 2
    local cy = y + h / 2

    local value = card:getValue()

    if value == 1 then
        -- Ace: one large center symbol
        drawSuitSymbol(card.suit, cx, cy, 30)
    elseif value >= 2 and value <= 10 then
        -- Number cards: arrange pips
        local positions = Card.getPipPositions(value)
        for _, pos in ipairs(positions) do
            local px = cx + pos[1] * 18
            local py = cy + pos[2] * 26
            love.graphics.push()
            if pos[3] then  -- Flip upside down
                love.graphics.translate(px, py)
                love.graphics.rotate(math.pi)
                drawSuitSymbol(card.suit, 0, 0, 14)
            else
                drawSuitSymbol(card.suit, px, py, 14)
            end
            love.graphics.pop()
        end
    else
        -- Face cards (J, Q, K): just show rank in center
        local faceRank = card.rank
        love.graphics.printf(faceRank, cx - 20, cy - 10, 40, "center")
        drawSuitSymbol(card.suit, cx, cy + 15, 18)
    end
end

-- Get pip positions for number cards
function Card.getPipPositions(value)
    local positions = {
        [2] = {{0, -1}, {0, 1, true}},
        [3] = {{0, -1}, {0, 0}, {0, 1, true}},
        [4] = {{-0.5, -1}, {0.5, -1}, {-0.5, 1, true}, {0.5, 1, true}},
        [5] = {{-0.5, -1}, {0.5, -1}, {0, 0}, {-0.5, 1, true}, {0.5, 1, true}},
        [6] = {{-0.5, -1}, {0.5, -1}, {-0.5, 0}, {0.5, 0}, {-0.5, 1, true}, {0.5, 1, true}},
        [7] = {{-0.5, -1}, {0.5, -1}, {0, -0.5}, {-0.5, 0}, {0.5, 0}, {-0.5, 1, true}, {0.5, 1, true}},
        [8] = {{-0.5, -1}, {0.5, -1}, {0, -0.5}, {-0.5, 0}, {0.5, 0}, {0, 0.5, true}, {-0.5, 1, true}, {0.5, 1, true}},
        [9] = {{-0.5, -1}, {0.5, -1}, {-0.5, -0.33}, {0.5, -0.33}, {0, 0}, {-0.5, 0.33, true}, {0.5, 0.33, true}, {-0.5, 1, true}, {0.5, 1, true}},
        [10] = {{-0.5, -1}, {0.5, -1}, {0, -0.66}, {-0.5, -0.33}, {0.5, -0.33}, {-0.5, 0.33, true}, {0.5, 0.33, true}, {0, 0.66, true}, {-0.5, 1, true}, {0.5, 1, true}}
    }
    return positions[value] or {}
end

-- Main draw function
function Card:draw(dragOffset)
    local x, y = self.x, self.y
    local w, h = Card.WIDTH, Card.HEIGHT
    local r = Card.CORNER_RADIUS

    -- Apply drag offset if provided
    if dragOffset then
        x = x + dragOffset.x
        y = y + dragOffset.y
    end

    -- Calculate flip scale (for flip animation)
    local flipScale = 1
    local showFace = self.faceUp

    if self.flipping or self.flipProgress ~= (self.faceUp and 1 or 0) then
        -- During flip animation
        flipScale = math.abs(math.cos(self.flipProgress * math.pi))
        showFace = self.flipProgress > 0.5
    end

    -- Draw shadow
    if dragOffset then
        love.graphics.setColor(Card.COLORS.shadow)
        drawRoundedRect("fill", x + 4, y + 4, w, h, r)
    else
        love.graphics.setColor(0, 0, 0, 0.15)
        drawRoundedRect("fill", x + 2, y + 2, w, h, r)
    end

    -- Apply flip transform
    love.graphics.push()
    love.graphics.translate(x + w / 2, y)
    love.graphics.scale(flipScale, 1)
    love.graphics.translate(-(x + w / 2), -y)

    -- Draw card
    if showFace then
        drawCardFace(self, x, y, w, h, r)
    else
        drawCardBack(x, y, w, h, r)
    end

    love.graphics.pop()

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- String representation
function Card:__tostring()
    return self.rank .. " of " .. self.suit
end

return Card
