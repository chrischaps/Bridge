-- Theme: the warm-vintage palette and the typefaces
--
-- Fonts are rasterised at the window's real scale (dpiscale) so text stays
-- sharp however the 960x540 virtual table is stretched. Call Theme.rebuild
-- from love.resize.

local Theme = {}

local function hex(h, a)
    h = h:gsub("#", "")
    return {
        tonumber(h:sub(1, 2), 16) / 255,
        tonumber(h:sub(3, 4), 16) / 255,
        tonumber(h:sub(5, 6), 16) / 255,
        a or 1,
    }
end
Theme.hex = hex

Theme.colors = {
    -- the table: burgundy baize under a lamp
    feltCenter = hex("#7d2632"),
    feltMid    = hex("#5b1622"),
    feltEdge   = hex("#2a080e"),

    -- walnut rail along the bottom
    railTop    = hex("#4a2e1c"),
    railBottom = hex("#25150b"),
    brass      = hex("#c9a24f"),
    brassLight = hex("#ecd593"),
    brassDark  = hex("#7a5a24"),

    -- paper and ink
    paper      = hex("#f5ecd7"),
    paperEdge  = hex("#e2d1ae"),
    paperLine  = hex("#9b8762"),
    inkRed     = hex("#a51f2a"),
    inkBlack   = hex("#211a17"),
    gold       = hex("#b38a3c"),

    -- card back: bottle green with gold work
    backField  = hex("#1d4436"),
    backDeep   = hex("#123026"),
    backGold   = hex("#c7a35a"),

    -- text on felt and rail
    cream      = hex("#f1e4c6"),
    creamDim   = hex("#cbb894"),
    shadow     = {0.08, 0.02, 0.02, 0.45},
}

-- Font roles: file, size in virtual px
local FILES = {
    regular = "assets/fonts/OldStandard-Regular.ttf",
    bold    = "assets/fonts/OldStandard-Bold.ttf",
    italic  = "assets/fonts/OldStandard-Italic.ttf",
    display = "assets/fonts/IMFellEnglishSC-Regular.ttf",
}

local ROLES = {
    index     = {"bold", 17},     -- card corner rank
    court     = {"bold", 25},     -- J/Q/K centre letter
    hud       = {"regular", 14},
    hudBold   = {"bold", 15},
    button    = {"regular", 14},
    small     = {"italic", 12},
    body      = {"regular", 16},
    bodyItalic = {"italic", 15},
    title     = {"display", 40},
    heading   = {"display", 24},
    slot      = {"display", 30},  -- faint letters on empty piles
}

local fonts = {}
local currentScale = nil

-- (Re)build every font at the given pixel scale
function Theme.rebuild(scale)
    scale = math.max(1, scale or 1)
    -- small changes aren't worth a rebuild
    if currentScale and math.abs(scale - currentScale) < 0.05 then return end
    currentScale = scale
    for role, spec in pairs(ROLES) do
        local ok, font = pcall(love.graphics.newFont, FILES[spec[1]], spec[2], "normal", scale)
        if not ok then
            font = love.graphics.newFont(spec[2], "normal", scale)
        end
        fonts[role] = font
    end
end

-- Scale that maps the virtual table onto the window
function Theme.windowScale(virtualW, virtualH)
    local w, h = love.graphics.getDimensions()
    return math.min(w / virtualW, h / virtualH) * love.window.getDPIScale()
end

function Theme.font(role)
    return fonts[role]
end

-- Set colour from a palette entry with optional alpha multiplier
function Theme.setColor(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alpha or 1))
end

-- Print centred on x
function Theme.printCentered(text, font, cx, y)
    love.graphics.setFont(font)
    love.graphics.print(text, math.floor(cx - font:getWidth(text) / 2 + 0.5), math.floor(y + 0.5))
end

-- Print with a soft drop shadow
function Theme.printShadow(text, font, x, y, color, alpha)
    love.graphics.setFont(font)
    local s = Theme.colors.shadow
    love.graphics.setColor(s[1], s[2], s[3], s[4] * (alpha or 1))
    love.graphics.print(text, x + 1, y + 1)
    Theme.setColor(color or Theme.colors.cream, alpha)
    love.graphics.print(text, x, y)
end

return Theme
