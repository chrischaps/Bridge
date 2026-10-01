-- Klondike Solitaire - Main Entry Point
-- Part of the Bridge Card Game Suite
--
-- Dev modes:
--   lovec . --selftest              rules tests, no window
--   lovec . --shot <name> [--size WxH]   render a scripted scenario to the save dir

-- Load LoveLibs
local scaling = require("lib.graphics.scaling")
local settings = require("lib.core.settings")
local sfx = require("lib.audio.sfx")

-- Load game modules
local Card = require("src.cards.card")
local KlondikeGame = require("src.games.klondike.game")
local HUD = require("src.ui.hud")
local Button = require("src.ui.button")

-- Virtual resolution
local VIRTUAL_WIDTH = 960
local VIRTUAL_HEIGHT = 540

-- Game state
local game
local hud
local newGameButton
local drawModeButton
local drawMode = 1
local dev = {}        -- parsed dev flags
local shot = nil      -- active capture scenario

local function parseArgs(args)
    local flags = {}
    local i = 1
    while args and i <= #args do
        local a = args[i]
        if a == "--selftest" then
            flags.selftest = true
        elseif a == "--shot" then
            flags.shot = args[i + 1]
            i = i + 1
        elseif a == "--size" then
            local w, h = (args[i + 1] or ""):match("^(%d+)x(%d+)$")
            flags.size = w and {tonumber(w), tonumber(h)}
            i = i + 1
        end
        i = i + 1
    end
    return flags
end

local function save()
    if not dev.shot then settings.save() end
end

local function newGame()
    game:deal(drawMode, nil, true)
    hud:reset()
    sfx.play("ui_select")
end

local function toggleDrawMode()
    drawMode = drawMode == 1 and 3 or 1
    drawModeButton:setText("Draw " .. drawMode)
    settings.set("drawMode", drawMode)
    save()
    -- the rules of a game in progress never change: switching deals afresh
    newGame()
end

function love.load(args)
    dev = parseArgs(args)

    if dev.selftest then
        local ok = require("src.dev.selftest")()
        love.event.quit(ok and 0 or 1)
        return
    end

    math.randomseed(os.time())
    love.math.setRandomSeed(os.time())

    settings.init({
        drawMode = 1,
        sfxVolume = 0.5,
    }, "klondike_settings.dat")
    if not dev.shot then settings.load() end
    drawMode = settings.get("drawMode")

    if dev.size then
        love.window.setMode(dev.size[1], dev.size[2], {resizable = true, msaa = 4, vsync = 1})
    end
    scaling.init(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    sfx.init()
    sfx.setSfxVolume(dev.shot and 0 or settings.get("sfxVolume"))

    game = KlondikeGame.new(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    game:deal(drawMode, nil, not dev.shot)
    hud = HUD.new(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    local buttonWidth, buttonHeight = 80, 26
    local buttonY = VIRTUAL_HEIGHT - buttonHeight - 10
    newGameButton = Button.new(10, buttonY, buttonWidth, buttonHeight, "New Game", newGame)
    drawModeButton = Button.new(100, buttonY, buttonWidth, buttonHeight, "Draw " .. drawMode, toggleDrawMode)

    if dev.shot then
        shot = require("src.dev.capture").start(dev.shot, {
            game = game,
            setDrawMode = function(n) drawMode = n end,
            size = dev.size,
        })
    end
end

function love.update(dt)
    if shot then dt = 1 / 60 end
    game:update(dt, not love.window.hasFocus() and not shot)
    hud:update(dt, game:getScoring(), game:isWon())
    if shot then shot:update(dt) end
end

-- Temporary table until the art pass
local function drawTable()
    love.graphics.setColor(0.15, 0.4, 0.2)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    love.graphics.setColor(0.2, 0.35, 0.2, 0.6)
    love.graphics.setLineWidth(2)
    for _, p in ipairs(game.piles) do
        love.graphics.rectangle("line", p.x, p.y, Card.WIDTH, Card.HEIGHT, Card.CORNER_RADIUS)
    end
    love.graphics.setColor(1, 0.85, 0.4, 0.35)
    for _, p in ipairs(game:dropTargets()) do
        local x, y, w, h = p:getBounds()
        love.graphics.rectangle("fill", x - 3, y - 3, w + 6, h + 6, Card.CORNER_RADIUS + 2)
    end
end

function love.draw()
    scaling.start()
    drawTable()
    game:drawCards()
    hud:draw(game:getScoring(), drawMode)
    if not game:isWon() then
        newGameButton:draw()
        drawModeButton:draw()
    end
    scaling.stop()
    if shot then shot:afterDraw() end
end

function love.resize(w, h)
    scaling.resize(w, h)
end

function love.mousepressed(x, y, button)
    local vx, vy = scaling.toVirtual(x, y)
    if game:isWon() and button == 1 then
        newGame()
        return
    end
    if newGameButton:mousepressed(vx, vy, button) then return end
    if drawModeButton:mousepressed(vx, vy, button) then return end
    game:mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
    local vx, vy = scaling.toVirtual(x, y)
    newGameButton:mousereleased(vx, vy, button)
    drawModeButton:mousereleased(vx, vy, button)
    game:mousereleased(vx, vy, button)
end

function love.mousemoved(x, y, dx, dy)
    local vx, vy = scaling.toVirtual(x, y)
    newGameButton:mousemoved(vx, vy)
    drawModeButton:mousemoved(vx, vy)
    game:mousemoved(vx, vy)
end

function love.keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl", "rctrl")
    if key == "escape" then
        love.event.quit()
    elseif key == "n" or (key == "space" and game:isWon()) then
        newGame()
    elseif key == "d" then
        toggleDrawMode()
    elseif key == "u" or (ctrl and key == "z") then
        game:undo()
    elseif key == "h" then
        game:showHint()
    end
end
