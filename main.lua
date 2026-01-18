-- Klondike Solitaire - Main Entry Point
-- Part of the Bridge Card Game Suite

-- Load LoveLibs
local scaling = require("lib.graphics.scaling")
local settings = require("lib.core.settings")
local sfx = require("lib.audio.sfx")

-- Load game modules
local KlondikeGame = require("src.games.klondike.game")
local HUD = require("src.ui.hud")
local Button = require("src.ui.button")
local Animation = require("src.util.animation")

-- Virtual resolution
local VIRTUAL_WIDTH = 960
local VIRTUAL_HEIGHT = 540

-- Game state
local game
local hud
local newGameButton
local drawModeButton

-- Current draw mode (1 or 3)
local drawMode = 1

function love.load()
    -- Initialize random seed
    math.randomseed(os.time())

    -- Initialize settings
    settings.init({
        drawMode = 1,
        sfxVolume = 0.5,
    }, "klondike_settings.dat")
    settings.load()

    drawMode = settings.get("drawMode")

    -- Initialize scaling
    scaling.init(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    -- Initialize sound effects
    sfx.init()
    sfx.setSfxVolume(settings.get("sfxVolume"))

    -- Create game
    game = KlondikeGame.new(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    game:init(drawMode)

    -- Create HUD
    hud = HUD.new(VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    -- Create buttons
    local buttonWidth = 80
    local buttonHeight = 26
    local buttonY = VIRTUAL_HEIGHT - buttonHeight - 10

    newGameButton = Button.new(10, buttonY, buttonWidth, buttonHeight, "New Game", function()
        game:newGame()
        hud:reset()
        sfx.play("ui_select")
    end)

    drawModeButton = Button.new(100, buttonY, buttonWidth, buttonHeight, "Draw " .. drawMode, function()
        drawMode = drawMode == 1 and 3 or 1
        drawModeButton:setText("Draw " .. drawMode)
        settings.set("drawMode", drawMode)
        settings.save()
        game:setDrawCount(drawMode)
        sfx.play("ui_navigate")
    end)

    -- Set window title
    love.window.setTitle("Klondike Solitaire")
end

function love.update(dt)
    -- Update game
    game:update(dt)

    -- Update HUD
    hud:update(dt, game:getScoring(), game:isWon())

    -- Update animations
    Animation.update(dt)

    -- Update buttons
    newGameButton:update(dt)
    drawModeButton:update(dt)
end

function love.draw()
    -- Start scaled rendering
    scaling.start()

    -- Draw game
    game:draw()

    -- Draw HUD
    hud:draw(game:getScoring(), drawMode)

    -- Draw buttons (only when not showing win screen)
    if not game:isWon() then
        newGameButton:draw()
        drawModeButton:draw()
    end

    -- End scaled rendering
    scaling.stop()
end

function love.resize(w, h)
    scaling.resize(w, h)
end

function love.mousepressed(x, y, button)
    -- Convert to virtual coordinates
    local vx, vy = scaling.toVirtual(x, y)

    -- Check for win screen interaction
    if game:isWon() and button == 1 then
        game:newGame()
        hud:reset()
        sfx.play("ui_select")
        return
    end

    -- Check buttons first
    if newGameButton:mousepressed(vx, vy, button) then
        return
    end
    if drawModeButton:mousepressed(vx, vy, button) then
        return
    end

    -- Pass to game
    game:mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
    local vx, vy = scaling.toVirtual(x, y)

    -- Check buttons
    newGameButton:mousereleased(vx, vy, button)
    drawModeButton:mousereleased(vx, vy, button)

    -- Pass to game
    game:mousereleased(vx, vy, button)
end

function love.mousemoved(x, y, dx, dy)
    local vx, vy = scaling.toVirtual(x, y)

    -- Update button hover states
    newGameButton:mousemoved(vx, vy)
    drawModeButton:mousemoved(vx, vy)

    -- Pass to game
    game:mousemoved(vx, vy, dx, dy)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "n" then
        -- New game shortcut
        game:newGame()
        hud:reset()
        sfx.play("ui_select")
    elseif key == "space" then
        -- Space for new game when won
        if game:isWon() then
            game:newGame()
            hud:reset()
            sfx.play("ui_select")
        end
    elseif key == "d" then
        -- Toggle draw mode
        drawMode = drawMode == 1 and 3 or 1
        drawModeButton:setText("Draw " .. drawMode)
        settings.set("drawMode", drawMode)
        settings.save()
        game:setDrawCount(drawMode)
        sfx.play("ui_navigate")
    end
end
