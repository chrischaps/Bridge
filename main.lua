-- Klondike Solitaire - Main Entry Point
-- Part of the Bridge Card Game Suite
--
-- Dev modes:
--   lovec . --selftest                   rules tests, no window
--   lovec . --shot <name> [--size WxH]   render a scripted scenario to the save dir

-- Load LoveLibs
local scaling = require("lib.graphics.scaling")
local settings = require("lib.core.settings")
local sfx = require("lib.audio.sfx")

-- Load game modules
local Card = require("src.cards.card")
local KlondikeGame = require("src.games.klondike.game")
local Cascade = require("src.games.klondike.cascade")
local Stats = require("src.games.klondike.stats")
local Scoring = require("src.games.klondike.scoring")
local Theme = require("src.ui.theme")
local Table = require("src.ui.table")
local Decor = require("src.ui.decor")
local Sparkle = require("src.ui.sparkle")
local HUD = require("src.ui.hud")
local Button = require("src.ui.button")
local Panel = require("src.ui.panel")

-- Virtual resolution
local VW, VH = 960, 540

local game, hud
local buttons = {}       -- rail buttons by name
local railButtons = {}   -- in draw order
local panel = nil        -- the modal panel, if any
local cascade = nil
local winInfo = nil      -- {records = ..., score = ...} for the win panel
local drawMode = 1
local renderScale = 1
local clock = 0
local muted = false
local stuck = false      -- no moves left
local recheckStuck = false
local dev = {}
local shot = nil
local cursors = {}

--------------------------------------------------
-- HELPERS
--------------------------------------------------

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

local function play(name, volume, pitch)
    if not muted and not dev.shot then sfx.play(name, volume, pitch) end
end

-- Rasterise fonts, faces and the table for the current window size
local function rescale()
    renderScale = Theme.windowScale(VW, VH)
    Theme.rebuild(renderScale)
    Card.setRenderScale(renderScale)
end

local function closePanel(after)
    if panel then
        panel:close(after)
    elseif after then
        after()
    end
end

local function openPanel(opts)
    opts.onCancel = opts.onCancel or function() closePanel() end
    panel = Panel.new(VW, VH, opts)
end

local function refreshStuck()
    stuck = game.state == "playing" and not game:isBusy() and game:findHint() == nil
    if stuck then
        hud:setStatus("No moves left \226\128\148 deal again?", math.huge)
    elseif hud.status and hud.status.text:find("No moves") then
        hud:setStatus(nil)
    end
end

local function stopCascade()
    if cascade then cascade:release() end
    cascade = nil
end

-- Deal a fresh game; a game in progress counts as played
local function newDeal(seed)
    if game.state == "playing" and game:hasProgress() then
        Stats.recordLoss()
    end
    stopCascade()
    Sparkle.clear()
    winInfo = nil
    game:deal(drawMode, seed, true)
    hud:setStatus(nil)
    stuck = false
    play("shuffle", 0.5)
end

local function confirm(title, text, yesText, onYes)
    openPanel({
        title = title, width = 380, height = 210,
        body = Panel.textBody({{text, "body"}}),
        buttons = {
            {yesText, function() closePanel(onYes) end, "gold"},
            {"Keep playing", function() closePanel() end},
        },
    })
end

local function toggleDrawMode()
    local nextMode = drawMode == 1 and 3 or 1
    local function apply()
        drawMode = nextMode
        buttons.draw:setText("Draw " .. drawMode)
        settings.set("drawMode", drawMode)
        save()
        -- the rules of a game in progress never change: switching deals afresh
        newDeal()
    end
    if game.state == "playing" and game:hasProgress() then
        confirm("Draw " .. nextMode .. "?",
            "Switching to Draw " .. nextMode .. " deals a new game. This one counts as played.",
            "Deal Draw " .. nextMode, apply)
    else
        apply()
    end
end

local function requestNewDeal()
    if panel then closePanel(newDeal) else newDeal() end
end

local function restartDeal()
    local function go()
        stopCascade()
        winInfo = nil
        game:restartDeal(true)
        hud:setStatus("Deal " .. game.seed .. " again, from the top", 2.5)
        stuck = false
        play("shuffle", 0.5)
    end
    if game.state == "playing" and game:hasProgress() then
        confirm("Start over?", "Redeal this same game from the beginning?", "Start over", go)
    else
        go()
    end
end

local function undo()
    if game:isWon() or panel then return end
    if game:undo() then
        play("ui_back", 0.35)
        refreshStuck()
    end
end

local function hint()
    if game:isWon() or panel or game:isBusy() then return end
    local h = game:showHint()
    if not h then
        refreshStuck()
        play("reject", 0.3)
    elseif h.draw then
        hud:setStatus(game.stock:isEmpty() and "Turn the waste over" or "Draw from the stock", 2.2)
    end
end

local function finish()
    if game:startAutoComplete() then play("ui_select", 0.4) end
end

-- The stats sheet
local function statsBody(extra)
    return function(_, x, y, w, h, a)
        local C = Theme.colors
        local s = Stats.get()
        local function bestTime(t) return t > 0 and Scoring.formatTime(t) or "\226\128\148" end
        local function bestScore(n) return n > 0 and tostring(n) or "\226\128\148" end
        local rate = s.statPlayed > 0 and math.floor(s.statWon / s.statPlayed * 100 + 0.5) .. "%" or "\226\128\148"
        local rows = {
            {"Games played", tostring(s.statPlayed)},
            {"Games won", tostring(s.statWon) .. "   (" .. rate .. ")"},
            {"Current streak", tostring(s.statStreak)},
            {"Best streak", tostring(s.statBestStreak)},
            {"Best time", bestTime(s.statBestTime1) .. "  /  " .. bestTime(s.statBestTime3)},
            {"Best score", bestScore(s.statBestScore1) .. "  /  " .. bestScore(s.statBestScore3)},
        }
        local label, value = Theme.font("bodyItalic"), Theme.font("hudBold")
        local lh = 23
        local cy = y + (extra or 0)
        for i, r in ipairs(rows) do
            local ry = cy + (i - 1) * lh
            love.graphics.setFont(label)
            Theme.setColor(C.inkBlack, 0.7 * a)
            love.graphics.print(r[1], x + 20, ry)
            love.graphics.setFont(value)
            Theme.setColor(C.inkBlack, a)
            love.graphics.print(r[2], x + w - 20 - value:getWidth(r[2]), ry)
            -- dotted leader
            Theme.setColor(C.paperLine, 0.5 * a)
            local from, to = x + 26 + label:getWidth(r[1]), x + w - 26 - value:getWidth(r[2])
            for dx = from, to, 5 do love.graphics.circle("fill", dx, ry + label:getHeight() - 4, 0.6) end
        end
        love.graphics.setFont(Theme.font("small"))
        Theme.setColor(C.paperLine, a)
        love.graphics.printf("times and scores: Draw 1 / Draw 3", x, cy + #rows * lh + 4, w, "center")
    end
end

local function showStats()
    if panel then return end
    openPanel({
        title = "The Ledger", width = 400, height = 312,
        body = statsBody(),
        buttons = {{"Close", function() closePanel() end}},
    })
end

local function showWinPanel()
    if panel or not winInfo then return end
    local sc = game:getScoring()
    local records = winInfo.records
    openPanel({
        title = "Well Played", width = 400, height = 300, dim = 0.35,
        body = function(_, x, y, w, h, a)
            local C = Theme.colors
            local rows = {
                {"Time", sc:getTimeString(), records.time and "a new best" or nil},
                {"Moves", tostring(sc:getMoves())},
                {"Score", tostring(sc:getScore())},
                {"Time bonus", "+" .. sc:getTimeBonus()},
            }
            local label, value = Theme.font("bodyItalic"), Theme.font("hudBold")
            for i, r in ipairs(rows) do
                local ry = y + (i - 1) * 22
                love.graphics.setFont(label)
                Theme.setColor(C.inkBlack, 0.7 * a)
                love.graphics.print(r[1], x + 40, ry)
                love.graphics.setFont(value)
                Theme.setColor(C.inkBlack, a)
                love.graphics.print(r[2], x + w - 40 - value:getWidth(r[2]), ry)
                if r[3] then
                    love.graphics.setFont(Theme.font("small"))
                    Theme.setColor(C.inkRed, a)
                    love.graphics.print(r[3], x + w - 36, ry + 3)
                end
            end
            local fy = y + #rows * 22 + 8
            Panel.rule(x + w / 2, fy, 110, a)
            local big = Theme.font("heading")
            love.graphics.setFont(big)
            Theme.setColor(C.inkRed, a)
            local t = "Final " .. sc:getFinalScore()
            love.graphics.print(t, math.floor(x + (w - big:getWidth(t)) / 2), fy + 6)
            if records.score then
                love.graphics.setFont(Theme.font("small"))
                Theme.setColor(C.gold, a)
                love.graphics.printf("a new best score", x, fy + 6 + big:getHeight(), w, "center")
            end
        end,
        buttons = {
            {"Deal Again", function() closePanel(newDeal) end, "gold"},
            {"Ledger", function() closePanel(showStats) end},
        },
        onCancel = function() closePanel() end,
    })
end

local function confirmQuit()
    if dev.shot then love.event.quit() return end
    if not game:hasProgress() or game:isWon() then
        love.event.quit()
        return
    end
    confirm("Leave the table?", "Your game in progress will be lost.", "Quit", function() love.event.quit() end)
end

--------------------------------------------------
-- GAME EVENTS (sound and sparkle)
--------------------------------------------------

local function onGameEvent(event, data)
    if event == "move" then
        local to = data.to
        play("card_place", 0.55, 0.92 + love.math.random() * 0.16)
        if to.kind == "foundation" then
            play("coin", 0.18, 0.9 + to:count() * 0.03)
            Sparkle.burst(to.x, to.y, Card.WIDTH, Card.HEIGHT, 10)
        end
    elseif event == "foundationComplete" then
        Sparkle.burst(data.x, data.y, Card.WIDTH, Card.HEIGHT, 40, true)
        play("stabilize", 0.25)
    elseif event == "flip" then
        play("card_snick", 0.3, 1.35)
    elseif event == "pickup" then
        play("card_snick", 0.35, 1.15)
    elseif event == "return" then
        play("card_place", 0.3, 0.8)
    elseif event == "draw" then
        play("card_snick", 0.45, 1.0 + love.math.random() * 0.1)
    elseif event == "recycle" then
        play("whir", 0.25, 1.2)
    elseif event == "invalid" then
        play("reject", 0.22, 1.3)
    elseif event == "win" then
        play("ending", 0.5)
        winInfo = {
            records = dev.shot and {} or Stats.recordWin(drawMode, game.scoring:getTime(), game.scoring:getFinalScore()),
        }
        cascade = Cascade.new(game.foundations, VW, hud.y, renderScale, game.seed)
    end
    if event == "move" or event == "draw" or event == "recycle" or event == "undo" or event == "deal" then
        if stuck then hud:setStatus(nil) end
        stuck = false
        recheckStuck = true
    end
end

-- Paper-ish noises for the cards
local function addCardSounds()
    local function noise(duration, volume, decay, tone)
        local rate = 44100
        local n = math.floor(rate * duration)
        local data = love.sound.newSoundData(n, rate, 16, 1)
        local prev = 0
        for i = 0, n - 1 do
            local t = i / n
            local env = math.exp(-t * decay) * math.min(1, t * 40)
            local white = love.math.random() * 2 - 1
            -- a one-pole filter takes the hiss off; tone sets how much
            prev = prev + (white - prev) * tone
            data:setSample(i, prev * volume * env)
        end
        return love.audio.newSource(data, "static")
    end
    sfx.addSound("card_snick", noise(0.05, 0.6, 9, 0.55))
    sfx.addSound("card_place", noise(0.09, 0.8, 7, 0.22))
    sfx.addSound("shuffle", noise(0.55, 0.35, 2.2, 0.35))
end

--------------------------------------------------
-- LOVE CALLBACKS
--------------------------------------------------

function love.load(args)
    dev = parseArgs(args)

    if dev.selftest then
        local ok = require("src.dev.selftest")()
        love.event.quit(ok and 0 or 1)
        return
    end

    love.math.setRandomSeed(os.time())
    math.randomseed(os.time())

    local defaults = {drawMode = 1, sfxVolume = 0.5, muted = false}
    for k, v in pairs(Stats.DEFAULTS) do defaults[k] = v end
    settings.init(defaults, "klondike_settings.dat")
    if not dev.shot then settings.load() end
    Stats.setSaver(save)
    drawMode = settings.get("drawMode") == 3 and 3 or 1
    muted = settings.get("muted")

    if dev.size then
        love.window.setMode(dev.size[1], dev.size[2], {resizable = true, msaa = 4, vsync = 1, minwidth = 960, minheight = 540})
    end
    scaling.init(VW, VH)
    rescale()

    sfx.init()
    sfx.setSfxVolume(settings.get("sfxVolume"))
    addCardSounds()

    cursors.hand = love.mouse.getSystemCursor("hand")
    cursors.arrow = love.mouse.getSystemCursor("arrow")

    hud = HUD.new(VW, VH)
    game = KlondikeGame.new(VW, VH)
    game.listener = onGameEvent

    -- the rail
    local y, h = hud.y + 8, 28
    local x = 16
    local function add(name, text, w, fn, style)
        local b = Button.new(x, y, w, h, text, fn, style)
        buttons[name] = b
        railButtons[#railButtons + 1] = b
        x = x + w + 8
        return b
    end
    add("new", "New Deal", 82, requestNewDeal)
    add("undo", "Undo", 58, undo)
    add("hint", "Hint", 54, hint)
    add("draw", "Draw " .. drawMode, 66, toggleDrawMode)
    add("stats", "Ledger", 62, showStats)
    x = x + 10
    buttons.finish = add("finish", "Finish", 70, finish, "gold")
    buttons.finish.pulse = true
    buttons.finish:setVisible(false)

    if dev.shot then
        shot = require("src.dev.capture").start(dev.shot, {
            game = game,
            setDrawMode = function(n) drawMode = n buttons.draw:setText("Draw " .. n) end,
            showStats = showStats,
            showWin = function() showWinPanel() end,
            hud = hud,
        })
        Card.prewarm(game.cards)
    else
        game:deal(drawMode, nil, true)
        Card.prewarm(game.cards)
        play("shuffle", 0.5)
    end
end

function love.update(dt)
    if shot then dt = 1 / 60 end
    dt = math.min(dt, 1 / 20)
    clock = clock + dt

    local paused = panel ~= nil or (not shot and not love.window.hasFocus())
    game:update(dt, paused)
    hud:update(dt, game:getScoring())
    Sparkle.update(dt)

    if cascade then
        cascade:update(dt)
        if cascade:isDone() and not panel then showWinPanel() end
    end

    if panel then
        panel:update(dt)
        if panel:isGone() then panel = nil end
    end

    buttons.undo:setEnabled(#game.history > 0 and not game:isWon())
    buttons.hint:setEnabled(game.state == "playing")
    buttons.finish:setVisible(game:canAutoComplete() and not game.autoCompleting)
    for _, b in ipairs(railButtons) do b:update(dt) end

    -- notice when the table has run dry (once things have settled)
    if recheckStuck and not game:isBusy() and #game.flyLayer == 0 then
        recheckStuck = false
        refreshStuck()
    end

    -- the hand cursor over anything clickable
    if not shot then
        local mx, my = scaling.toVirtual(love.mouse.getPosition())
        local hand = false
        if panel then
            hand = panel:isHoveringButton()
        else
            for _, b in ipairs(railButtons) do if b.hovered then hand = true end end
            hand = hand or game:isInteractiveAt(mx, my) or (game.drag ~= nil)
        end
        love.mouse.setCursor(hand and cursors.hand or cursors.arrow)
    end

    if shot then shot:update(dt) end
end

-- Every card face and the back, for checking the art
local function drawGallery()
    local cards = game.cards
    table.sort(cards, function(a, b)
        if a.suit ~= b.suit then return a.suit < b.suit end
        return a.value < b.value
    end)
    local s = 0.78
    for i, c in ipairs(cards) do
        local col, row = (i - 1) % 13, math.floor((i - 1) / 13)
        c:drawAt(14 + col * 66, 14 + row * 96, s, true)
    end
    cards[1]:drawAt(14 + 12 * 66 - 70, 14 + 4 * 96, s, false)
end

function love.draw()
    scaling.start()

    Table.draw(VW, VH, renderScale)
    if shot and shot:isGallery() then
        drawGallery()
        scaling.stop()
        shot:afterDraw()
        return
    end

    Decor.drawSlots(game)
    Decor.drawHint(game)
    Decor.drawDropGlows(game, clock)
    game:drawCards()
    Sparkle.draw()
    if cascade then cascade:draw(VW, VH) end

    hud:drawRail()
    for _, b in ipairs(railButtons) do b:draw() end
    hud:drawReadout(game:getScoring(), game.seed, drawMode)
    local statusLeft = buttons.finish.visible and (buttons.finish.x + buttons.finish.width) or (buttons.stats.x + buttons.stats.width)
    hud:drawStatus(statusLeft + 10)

    if panel then panel:draw() end

    scaling.stop()
    if shot then shot:afterDraw() end
end

function love.resize(w, h)
    scaling.resize(w, h)
    rescale()
end

function love.mousepressed(x, y, button)
    local vx, vy = scaling.toVirtual(x, y)
    if panel then panel:mousepressed(vx, vy, button) return end
    if cascade then
        -- a click during the cascade brings the scores up
        showWinPanel()
        return
    end
    for _, b in ipairs(railButtons) do
        if b:mousepressed(vx, vy, button) then return end
    end
    game:mousepressed(vx, vy, button)
end

function love.mousereleased(x, y, button)
    local vx, vy = scaling.toVirtual(x, y)
    if panel then panel:mousereleased(vx, vy, button) return end
    for _, b in ipairs(railButtons) do b:mousereleased(vx, vy, button) end
    game:mousereleased(vx, vy, button)
end

function love.mousemoved(x, y)
    local vx, vy = scaling.toVirtual(x, y)
    if panel then
        panel:mousemoved(vx, vy)
        for _, b in ipairs(railButtons) do b:mousemoved(-1, -1) end
        return
    end
    for _, b in ipairs(railButtons) do b:mousemoved(vx, vy) end
    game:mousemoved(vx, vy)
end

function love.focus(focused)
    if not focused and game and game.drag then game:cancelDrag() end
end

function love.keypressed(key)
    if key == "f11" or (key == "return" and love.keyboard.isDown("lalt", "ralt")) then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        return
    end
    if panel then panel:keypressed(key) return end

    local ctrl = love.keyboard.isDown("lctrl", "rctrl")
    if key == "escape" then
        if cascade then showWinPanel() else confirmQuit() end
    elseif cascade and (key == "space" or key == "return") then
        showWinPanel()
    elseif key == "n" then
        requestNewDeal()
    elseif key == "r" then
        restartDeal()
    elseif key == "d" then
        toggleDrawMode()
    elseif key == "u" or (ctrl and key == "z") or key == "backspace" then
        undo()
    elseif key == "h" then
        hint()
    elseif key == "s" or key == "l" then
        showStats()
    elseif key == "f" or key == "return" then
        finish()
    elseif key == "space" then
        if not game:isBusy() and game.state == "playing" then game:drawStock() end
    elseif key == "m" then
        muted = not muted
        settings.set("muted", muted)
        save()
        hud:setStatus(muted and "Sound off" or "Sound on", 1.5)
    end
end
