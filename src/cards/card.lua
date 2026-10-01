-- Card class with procedural rendering
-- Represents a single playing card with suit, rank, position, and animation.
-- Faces and the back are painted once into canvases (at the window's real
-- scale) and then drawn with flip, lift and tilt transforms.

local Suits = require("src.cards.suits")
local Theme = require("src.ui.theme")

local Card = {}
Card.__index = Card

-- Card dimensions (virtual px)
Card.WIDTH = 80
Card.HEIGHT = 112
Card.CORNER_RADIUS = 6

-- Suit constants
Card.SUITS = {"hearts", "diamonds", "clubs", "spades"}
Card.RANKS = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

-- Create a new card
function Card.new(suit, rank)
    local self = setmetatable({}, Card)

    self.suit = suit
    self.rank = rank
    self.value = Card.valueOf(rank)
    self.red = suit == "hearts" or suit == "diamonds"
    self.faceUp = false

    -- Position and animation target
    self.x, self.y = 0, 0
    self.targetX, self.targetY = 0, 0
    self.zIndex = 0

    -- Animation state
    self.animating = false
    self.animSpeed = 12    -- position easing rate
    self.flying = false    -- travelling between piles; drawn above the table
    self.dragging = false  -- held under the pointer
    self.delay = 0         -- seconds before it starts moving (dealing)
    self.shake = 0         -- 1 → 0 after an invalid click
    self.lift = 0          -- eased hover lift 0..1

    -- Flip animation: 0 = back showing, 1 = face showing
    self.flipProgress = 0
    self.flipTarget = 0
    self.flipping = false

    return self
end

-- Numeric value of a rank (Ace = 1 ... King = 13)
function Card.valueOf(rank)
    for i, r in ipairs(Card.RANKS) do
        if r == rank then
            return i
        end
    end
    return 0
end

function Card:isRed()
    return self.red
end

function Card:getValue()
    return self.value
end

-- Set position immediately
function Card:setPosition(x, y)
    self.x, self.y = x, y
    self.targetX, self.targetY = x, y
end

-- Animate to target position
function Card:moveTo(x, y, immediate)
    self.targetX = x
    self.targetY = y
    if immediate then
        self.x = x
        self.y = y
        self.animating = false
        self.flying = false
    elseif math.abs(x - self.x) > 0.5 or math.abs(y - self.y) > 0.5 then
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
    elseif immediate then
        self.flipProgress, self.flipping = self.flipTarget, false
    end
end

-- Update animation
function Card:update(dt)
    if self.animating then
        local dx = self.targetX - self.x
        local dy = self.targetY - self.y
        if dx * dx + dy * dy < 0.25 then
            self.x = self.targetX
            self.y = self.targetY
            self.animating = false
        else
            local factor = 1 - math.pow(0.01, dt * self.animSpeed)
            self.x = self.x + dx * factor
            self.y = self.y + dy * factor
        end
    end
    if not self.animating then
        self.flying = false
    end

    if self.flipping then
        -- a steady turn reads better than an ease for flips
        local step = dt * 5.5
        if self.flipProgress < self.flipTarget then
            self.flipProgress = math.min(self.flipTarget, self.flipProgress + step)
        else
            self.flipProgress = math.max(self.flipTarget, self.flipProgress - step)
        end
        if self.flipProgress == self.flipTarget then self.flipping = false end
    end
end

function Card:isAnimating()
    return self.animating or self.flipping
end

-- Check if point is inside card
function Card:containsPoint(px, py)
    return px >= self.x and px <= self.x + Card.WIDTH
       and py >= self.y and py <= self.y + Card.HEIGHT
end

function Card:__tostring()
    return self.rank .. " of " .. self.suit
end

--------------------------------------------------
-- PAINTING (into cached canvases)
--------------------------------------------------

local PAD = 3            -- canvas margin so antialiased edges aren't clipped
local cache = {}         -- key -> canvas
local renderScale = 1

-- Called when the window scale changes: faces get repainted on demand
function Card.setRenderScale(scale)
    if math.abs(scale - renderScale) > 0.01 then
        renderScale = scale
        for k, c in pairs(cache) do c:release() cache[k] = nil end
    end
end

local function ink(card, alpha)
    Theme.setColor(card.red and Theme.colors.inkRed or Theme.colors.inkBlack, alpha)
end

-- Paper: cream with a slightly warmer edge and a fine ink border
local function paintPaper(w, h, r)
    local C = Theme.colors
    Theme.setColor(C.paperEdge)
    love.graphics.rectangle("fill", 0, 0, w, h, r, r)
    Theme.setColor(C.paper)
    love.graphics.rectangle("fill", 1.5, 1.5, w - 3, h - 3, r - 1, r - 1)
    -- a faint sheen that fades out down the top half
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", 2, 2, w - 4, r * 2, r - 1, r - 1)
    local sheen = Card.sheenMesh
    if not sheen then
        sheen = love.graphics.newMesh({
            {0, 0, 0, 0, 1, 1, 1, 0.18}, {1, 0, 0, 0, 1, 1, 1, 0.18},
            {1, 1, 0, 0, 1, 1, 1, 0}, {0, 1, 0, 0, 1, 1, 1, 0},
        }, "fan", "static")
        Card.sheenMesh = sheen
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(sheen, 2, 2 + r * 2, 0, w - 4, h * 0.5 - r * 2)
    Theme.setColor(C.paperLine, 0.75)
    love.graphics.setLineWidth(0.8)
    love.graphics.rectangle("line", 0.4, 0.4, w - 0.8, h - 0.8, r, r)
end

-- Corner index: rank over a small suit, centred on a narrow column
local INDEX_CX = 11
local function paintIndex(card)
    local font = Theme.font("index")
    ink(card)
    love.graphics.setFont(font)
    local text = card.rank
    local tw = font:getWidth(text)
    -- "10" is tucked a little tighter
    local sx = text == "10" and 0.86 or 1
    love.graphics.print(text, INDEX_CX - tw * sx / 2, 2, 0, sx, 1)
    Suits.draw(card.suit, INDEX_CX, 29, 11)
end

-- Paint the index top-left and again rotated in the bottom-right
local function paintIndices(card, w, h)
    paintIndex(card)
    love.graphics.push()
    love.graphics.translate(w, h)
    love.graphics.rotate(math.pi)
    paintIndex(card)
    love.graphics.pop()
end

-- Pip layouts: {column (-1, 0, 1), row (0 = top ... 1 = bottom)}
local PIPS = {
    [2] = {{0, 0}, {0, 1}},
    [3] = {{0, 0}, {0, 0.5}, {0, 1}},
    [4] = {{-1, 0}, {1, 0}, {-1, 1}, {1, 1}},
    [5] = {{-1, 0}, {1, 0}, {0, 0.5}, {-1, 1}, {1, 1}},
    [6] = {{-1, 0}, {1, 0}, {-1, 0.5}, {1, 0.5}, {-1, 1}, {1, 1}},
    [7] = {{-1, 0}, {1, 0}, {0, 0.25}, {-1, 0.5}, {1, 0.5}, {-1, 1}, {1, 1}},
    [8] = {{-1, 0}, {1, 0}, {0, 0.25}, {-1, 0.5}, {1, 0.5}, {0, 0.75}, {-1, 1}, {1, 1}},
    [9] = {{-1, 0}, {1, 0}, {-1, 1/3}, {1, 1/3}, {0, 0.5}, {-1, 2/3}, {1, 2/3}, {-1, 1}, {1, 1}},
    [10] = {{-1, 0}, {1, 0}, {0, 1/6}, {-1, 1/3}, {1, 1/3}, {-1, 2/3}, {1, 2/3}, {0, 5/6}, {-1, 1}, {1, 1}},
}
Card.PIPS = PIPS

local function paintPips(card, w, h)
    local layout = PIPS[card.value]
    local colX, top, bottom, size = 16, 19, h - 19, 17
    ink(card)
    for _, p in ipairs(layout) do
        local px = w / 2 + p[1] * colX
        local py = top + p[2] * (bottom - top)
        -- pips below the middle are printed upside down, as on real cards
        Suits.draw(card.suit, px, py, size, p[2] > 0.5 and math.pi or 0)
    end
end

-- Small engraved ornament: a diamond with dots either side
local function ornament(x, y, s)
    love.graphics.polygon("fill", x, y - s, x + s * 0.6, y, x, y + s, x - s * 0.6, y)
    love.graphics.circle("fill", x - s * 1.6, y, s * 0.35)
    love.graphics.circle("fill", x + s * 1.6, y, s * 0.35)
end

local function paintAce(card, w, h)
    local C = Theme.colors
    local cx, cy = w / 2, h / 2
    if card.suit == "spades" then
        -- the maker's ace: a ringed spade and the house name
        Theme.setColor(C.gold, 0.85)
        love.graphics.setLineWidth(0.8)
        love.graphics.circle("line", cx, cy - 2, 27)
        love.graphics.circle("line", cx, cy - 2, 24.5)
        for i = 0, 7 do
            local a = i / 8 * math.pi * 2 + math.pi / 8
            love.graphics.circle("fill", cx + math.cos(a) * 25.75, cy - 2 + math.sin(a) * 25.75, 1)
        end
        ink(card)
        Suits.draw(card.suit, cx, cy - 2, 36)
        Theme.setColor(C.gold)
        local f = Theme.font("small")
        love.graphics.setFont(f)
        local t = "Bridge"
        love.graphics.print(t, cx - f:getWidth(t) / 2, cy + 28)
    else
        ink(card)
        Suits.draw(card.suit, cx, cy, 40)
        Theme.setColor(C.gold, 0.7)
        ornament(cx, cy + 32, 2.2)
        ornament(cx, cy - 32, 2.2)
    end
end

-- Crown-ish emblems above the court letter
local function emblem(rank, x, y)
    if rank == "K" then
        love.graphics.polygon("fill", x - 7, y + 3, x - 7, y - 3, x - 3.5, y, x, y - 5, x + 3.5, y, x + 7, y - 3, x + 7, y + 3)
        love.graphics.circle("fill", x - 7, y - 4, 1.1)
        love.graphics.circle("fill", x, y - 6, 1.2)
        love.graphics.circle("fill", x + 7, y - 4, 1.1)
    elseif rank == "Q" then
        love.graphics.arc("fill", "pie", x, y + 3, 6.5, math.pi, math.pi * 2, 12)
        love.graphics.circle("fill", x - 5, y - 3.2, 1.1)
        love.graphics.circle("fill", x, y - 5, 1.3)
        love.graphics.circle("fill", x + 5, y - 3.2, 1.1)
    else
        -- the Jack's plume
        love.graphics.polygon("fill", x - 6, y + 3, x + 6, y + 3, x + 5, y + 1, x - 5, y + 1)
        love.graphics.ellipse("fill", x + 1, y - 2.5, 2.2, 4.5)
    end
end

local function paintCourt(card, w, h)
    local C = Theme.colors
    local fx, fy, fw, fh = 17, 13, w - 34, h - 26

    -- tinted panel and a double frame
    if card.red then love.graphics.setColor(0.65, 0.12, 0.16, 0.06)
    else love.graphics.setColor(0.1, 0.08, 0.06, 0.06) end
    love.graphics.rectangle("fill", fx, fy, fw, fh, 2)
    Theme.setColor(C.gold)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", fx, fy, fw, fh, 2)
    ink(card, 0.55)
    love.graphics.setLineWidth(0.6)
    love.graphics.rectangle("line", fx + 2.5, fy + 2.5, fw - 5, fh - 5, 1.5)

    -- double-ended: the top half, then the same rotated
    local cx = w / 2
    local function half()
        Theme.setColor(C.gold)
        emblem(card.rank, cx, fy + 10)
        ink(card)
        Suits.draw(card.suit, cx - 14, fy + 10, 7)
        Suits.draw(card.suit, cx + 14, fy + 10, 7)
        local font = Theme.font("court")
        love.graphics.setFont(font)
        local baseline = fy + fh * 0.41
        love.graphics.print(card.rank, cx - font:getWidth(card.rank) / 2, baseline - font:getBaseline())
    end
    half()
    love.graphics.push()
    love.graphics.translate(w, h)
    love.graphics.rotate(math.pi)
    half()
    love.graphics.pop()

    -- the diagonal that divides a double-ended court
    Theme.setColor(C.gold, 0.6)
    love.graphics.setLineWidth(0.7)
    love.graphics.line(fx + 3, fy + fh - 3 - fh * 0.32, fx + fw - 3, fy + 3 + fh * 0.32)
end

local function paintFace(card)
    local w, h, r = Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS
    paintPaper(w, h, r)
    if card.value == 1 then
        paintAce(card, w, h)
    elseif card.value <= 10 then
        paintPips(card, w, h)
    else
        paintCourt(card, w, h)
    end
    paintIndices(card, w, h)
end

local function paintBack()
    local C = Theme.colors
    local w, h, r = Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS
    paintPaper(w, h, r)

    -- green field inside a cream border
    local m = 5
    local fx, fy, fw, fh = m, m, w - m * 2, h - m * 2
    Theme.setColor(C.backField)
    love.graphics.rectangle("fill", fx, fy, fw, fh, 3, 3)

    -- gold lattice, clipped to the field
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", fx + 3, fy + 3, fw - 6, fh - 6, 2, 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    Theme.setColor(C.backGold, 0.32)
    love.graphics.setLineWidth(0.6)
    local step = 7
    for i = -20, 30 do
        local o = i * step
        love.graphics.line(fx + o, fy, fx + o + fh, fy + fh)
        love.graphics.line(fx + o + fh, fy, fx + o, fy + fh)
    end
    -- small dots where the lattice crosses
    Theme.setColor(C.backGold, 0.45)
    for i = -20, 30 do
        for j = 0, 40 do
            local x = fx + i * step + (j % 2) * step / 2
            local y = fy + j * step / 2
            if x > fx and x < fx + fw and y > fy and y < fy + fh then
                love.graphics.circle("fill", x, y, 0.55, 6)
            end
        end
    end
    love.graphics.setStencilTest()

    -- frames
    Theme.setColor(C.backGold, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", fx + 2.5, fy + 2.5, fw - 5, fh - 5, 2, 2)
    Theme.setColor(C.backGold, 0.5)
    love.graphics.setLineWidth(0.6)
    love.graphics.rectangle("line", fx + 5, fy + 5, fw - 10, fh - 10, 1.5, 1.5)

    -- medallion with a rosette
    local cx, cy = w / 2, h / 2
    Theme.setColor(C.backDeep)
    love.graphics.circle("fill", cx, cy, 15)
    Theme.setColor(C.backGold)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, 15)
    love.graphics.setLineWidth(0.6)
    love.graphics.circle("line", cx, cy, 12.5)
    for i = 0, 7 do
        local a = i / 8 * math.pi * 2
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(a)
        love.graphics.ellipse("fill", 0, -6, 1.9, 5, 12)
        love.graphics.pop()
    end
    Theme.setColor(C.backDeep)
    love.graphics.circle("fill", cx, cy, 2.6)
    Theme.setColor(C.backGold)
    love.graphics.circle("fill", cx, cy, 1.5)
    -- corner pips
    for _, p in ipairs({{fx + 9, fy + 9}, {fx + fw - 9, fy + 9}, {fx + 9, fy + fh - 9}, {fx + fw - 9, fy + fh - 9}}) do
        love.graphics.polygon("fill", p[1], p[2] - 2.4, p[1] + 1.6, p[2], p[1], p[2] + 2.4, p[1] - 1.6, p[2])
    end
end

-- Render into a canvas the first time it's needed
local function canvasFor(key, painter)
    local c = cache[key]
    if c then return c end
    c = love.graphics.newCanvas(Card.WIDTH + PAD * 2, Card.HEIGHT + PAD * 2,
        {dpiscale = renderScale, msaa = 4})
    love.graphics.push("all")
    love.graphics.setCanvas({c, stencil = true})
    love.graphics.setScissor()
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.translate(PAD, PAD)
    painter()
    love.graphics.pop()
    cache[key] = c
    return c
end

function Card:faceCanvas()
    return canvasFor(self.rank .. self.suit, function() paintFace(self) end)
end

function Card.backCanvas()
    return canvasFor("back", paintBack)
end

-- Paint every face now (avoids a hitch the first time each card shows)
function Card.prewarm(cards)
    Card.backCanvas()
    for _, c in ipairs(cards) do c:faceCanvas() end
end

--------------------------------------------------
-- DRAWING
--------------------------------------------------

-- Soft shadow under a card; height lifts it further off the cloth
function Card.drawShadow(x, y, height, scaleX)
    local w, h, r = Card.WIDTH * (scaleX or 1), Card.HEIGHT, Card.CORNER_RADIUS
    local ox = x + (Card.WIDTH - w) / 2
    local off = 1 + height * 6
    local spread = height * 3
    love.graphics.setColor(0.05, 0, 0, 0.16 + height * 0.06)
    love.graphics.rectangle("fill", ox + off * 0.6 - spread, y + off - spread * 0.5,
        w + spread * 2, h + spread, r + spread, r + spread)
    love.graphics.setColor(0.05, 0, 0, 0.18)
    love.graphics.rectangle("fill", ox + 0.5, y + 1.2, w, h, r, r)
end

-- opts: lifted (bool) and tilt (radians) while dragged
function Card:draw(opts)
    local w, h = Card.WIDTH, Card.HEIGHT
    local lifted = opts and opts.lifted
    local tilt = opts and opts.tilt or 0

    local x, y = self.x, self.y
    if self.shake > 0 then
        x = x + math.sin(self.shake * 26) * 4 * self.shake
    end

    -- flip: squash horizontally through edge-on, with a little pop
    local p = self.flipProgress
    local flipScale = math.abs(math.cos(p * math.pi))
    local pop = 1 + 0.06 * math.sin(p * math.pi)
    local showFace = p > 0.5

    local height = lifted and 1 or (self.flying and 0.5 or 0) + self.lift * 0.3 + (pop - 1) * 6
    local liftScale = lifted and 1.04 or 1
    y = y - self.lift * 2

    Card.drawShadow(x, y, height, flipScale)

    local img = showFace and self:faceCanvas() or Card.backCanvas()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x + w / 2, y + h / 2, tilt,
        flipScale * pop * liftScale, pop * liftScale, w / 2 + PAD, h / 2 + PAD)
end

-- Draw a card face at any spot (galleries, the win cascade)
function Card:drawAt(x, y, scale, faceUp)
    local img = (faceUp == false) and Card.backCanvas() or self:faceCanvas()
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x - PAD * scale, y - PAD * scale, 0, scale, scale)
end

return Card
