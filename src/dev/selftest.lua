-- Headless rules tests: `lovec . --selftest`
-- Exits non-zero if anything fails.

local KlondikeGame = require("src.games.klondike.game")
local Scoring = require("src.games.klondike.scoring")

local T = {passed = 0, failed = 0}

local function check(cond, msg)
    if cond then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        print("  FAIL: " .. msg)
    end
    return cond
end

local Fixtures = require("src.dev.fixtures")
local code, newGame, place = Fixtures.code, Fixtures.newGame, Fixtures.place

local function serialize(g)
    local parts = {}
    for _, p in ipairs(g.piles) do
        local cs = {}
        for _, c in ipairs(p.cards) do cs[#cs + 1] = (c.faceUp and "" or "*") .. code(c) end
        parts[#parts + 1] = p.kind .. p.index .. ":" .. table.concat(cs, ",")
    end
    parts[#parts + 1] = "fan" .. g.waste.fanCount
    parts[#parts + 1] = string.format("s%d m%d r%d", g.scoring.score, g.scoring.moves, g.scoring.wasteRecycles)
    return table.concat(parts, "|")
end

-- Structural invariants that must hold after any action
local function invariants(g)
    local seen, count = {}, 0
    for _, p in ipairs(g.piles) do
        for _, c in ipairs(p.cards) do
            if seen[c] then return false, "duplicate " .. code(c) end
            seen[c] = true
            count = count + 1
        end
    end
    if count ~= 52 then return false, "card count " .. count end
    for _, c in ipairs(g.waste.cards) do
        if not c.faceUp then return false, "face-down card in waste" end
    end
    for _, c in ipairs(g.stock.cards) do
        if c.faceUp then return false, "face-up card in stock" end
    end
    for _, f in ipairs(g.foundations) do
        for i, c in ipairs(f.cards) do
            if c.value ~= i or c.suit ~= f.cards[1].suit then return false, "bad foundation" end
        end
    end
    for ti, t in ipairs(g.tableaus) do
        local firstUp = nil
        for i, c in ipairs(t.cards) do
            if c.faceUp then
                firstUp = firstUp or i
            elseif firstUp then
                return false, "face-down above face-up in t" .. ti
            end
        end
        if #t.cards > 0 and not t:getTopCard().faceUp then
            return false, "hidden top card in t" .. ti
        end
        if firstUp and not t:canPickUp(firstUp) then
            return false, "broken run in t" .. ti
        end
    end
    return true
end

local tests = {}

tests["deal is complete, seeded and repeatable"] = function()
    local g = newGame(4242)
    check(invariants(g), "fresh deal invariants")
    for i, t in ipairs(g.tableaus) do
        check(t:count() == i, "tableau " .. i .. " has " .. i .. " cards")
        check(t:getTopCard().faceUp and t:hiddenCount() == i - 1, "tableau " .. i .. " only top face up")
    end
    check(g.stock:count() == 24, "24 cards in stock")
    check(serialize(newGame(4242)) == serialize(g), "same seed, same deal")
    check(serialize(newGame(4243)) ~= serialize(g), "different seed, different deal")
end

tests["bug: auto-move from mid-stack must not destroy cards"] = function()
    local g = newGame(1)
    local c = place(g, {t1 = {"2H", "AS"}, f1 = {"AH"}})
    check(not g:canMove(g.tableaus[1], 1, g.foundations[1]), "2H under AS can't go to foundation")
    check(g:findSmartTarget(g.tableaus[1], 1) ~= g.foundations[1], "smart target isn't the foundation")
    g:moveCards(g.tableaus[1], 1, g.foundations[1])
    check(invariants(g), "still 52 cards")
    check(g:moveCards(g.tableaus[1], 2, g.foundations[2]), "AS (top) goes up")
    check(g:moveCards(g.tableaus[1], 1, g.foundations[1]), "then 2H goes up")
    check(invariants(g), "invariants after")
end

tests["bug: foundations don't stay locked to a suit"] = function()
    local g = newGame(1)
    place(g, {t1 = {"2S"}, f1 = {"AH"}, w = {"AD"}})
    check(not g:canMove(g.foundations[1], 1, g.foundations[2]), "no foundation-to-foundation moves")
    check(g:moveCards(g.foundations[1], 1, g.tableaus[1]), "AH back down onto 2S")
    check(g.foundations[1]:getSuit() == nil, "empty foundation has no suit")
    check(g:moveCards(g.waste, 1, g.foundations[1]), "a different Ace can use it")
    check(g.foundations[1]:getSuit() == "diamonds", "suit follows contents")
end

tests["bug: no score farming through the foundations"] = function()
    local g = newGame(1)
    place(g, {t1 = {"2S"}, w = {"AH"}})
    g:moveCards(g.waste, 1, g.foundations[1])
    local s = g.scoring.score
    check(s == 10, "waste to foundation +10 (got " .. s .. ")")
    g:moveCards(g.foundations[1], 1, g.tableaus[1])
    g:moveCards(g.tableaus[1], 2, g.foundations[1])
    check(g.scoring.score <= s, "down and back up again gains nothing (" .. g.scoring.score .. ")")
end

tests["scoring table"] = function()
    local g = newGame(1)
    place(g, {t1 = {"*9C", "8D"}, t2 = {"9S"}, t3 = {"8S"}, w = {"7H"}, f1 = {"AC"}})
    g:moveCards(g.waste, 1, g.tableaus[3])
    check(g.scoring.score == 5, "waste to tableau +5")
    g:moveCards(g.tableaus[1], 2, g.tableaus[2])
    check(g.scoring.score == 10, "tableau to tableau 0, flip +5")
    check(g.scoring.moves == 2, "two moves counted")

    local s = Scoring.new()
    s:start(1)
    s.score = 300
    s:onRecycle()
    check(s.score == 200, "draw 1 recycle -100")
    s:start(3)
    s.score = 100
    s:onRecycle(); s:onRecycle()
    check(s.score == 100, "draw 3: first passes free")
    s:onRecycle()
    check(s.score == 80, "draw 3: fourth pass -20")
    s:start(1)
    check(s:getTime() == 0 and not s:isRunning(), "clock waits for first action")
end

tests["draw 3 fan never pulls buried cards forward"] = function()
    local g = newGame(7, 3)
    g:drawStock()
    g:drawStock()
    check(g.waste:count() == 6 and g.waste.fanCount == 3, "six in waste, three fanned")
    local second = g.waste.cards[5]
    local sx = select(1, g.waste:cardPosition(5))
    -- take the top card off directly (whether it has a legal home depends on the deal)
    local top = table.remove(g.waste.cards)
    g.waste:onTopTaken()
    check(g.waste.fanCount == 2, "fan shrinks to two")
    check(select(1, g.waste:cardPosition(5)) == sx, "next card stays where it was")
    check(select(1, g.waste:cardPosition(4)) == g.waste.x, "buried card stays buried")
    table.insert(g.waste.cards, top)
end

tests["undo restores every action exactly"] = function()
    local rng = love.math.newRandomGenerator(99)
    for game = 1, 200 do
        local g = newGame(game, game % 2 == 0 and 3 or 1)
        for step = 1, 80 do
            local before = serialize(g)
            local moves = g:legalMoves()
            local acted
            if #moves > 0 and rng:random() < 0.6 then
                local m = moves[rng:random(1, #moves)]
                acted = g:moveCards(m.from, m.index, m.to)
            else
                acted = g:drawStock()
            end
            if acted and rng:random() < 0.3 then
                g:undo()
                if not check(serialize(g) == before, "undo round-trip (game " .. game .. ", step " .. step .. ")") then
                    return
                end
            end
            if g:isWon() then break end
        end
    end
end

tests["random play conserves the deck (2000 games)"] = function()
    local rng = love.math.newRandomGenerator(2026)
    local wins = 0
    for game = 1, 2000 do
        local g = newGame(game * 7919, game % 3 == 0 and 3 or 1)
        for _ = 1, 200 do
            local moves = g:legalMoves()
            if #moves > 0 and rng:random() < 0.65 then
                local m = moves[rng:random(1, #moves)]
                check(g:moveCards(m.from, m.index, m.to), "legal move applies")
            elseif not g:drawStock() then
                break
            end
            if rng:random() < 0.05 then g:undo() end
            local ok, why = invariants(g)
            if not check(ok, "game " .. game .. ": " .. tostring(why)) then return end
            if g:isWon() then wins = wins + 1 break end
        end
    end
    print(string.format("  (random play won %d of 2000)", wins))
end

tests["hints are legal and useful"] = function()
    for seed = 1, 300 do
        local g = newGame(seed)
        for _ = 1, 60 do
            local h = g:findHint()
            if not h then break end
            if h.draw then
                if not g:drawStock() then break end
            else
                check(h.from.kind ~= "foundation", "hint never pulls from a foundation")
                if not check(g:moveCards(h.from, h.index, h.to), "hint move is legal") then return end
            end
            local ok, why = invariants(g)
            if not check(ok, "hint play: " .. tostring(why)) then return end
        end
    end
end

tests["auto-complete finishes a solved board"] = function()
    local g = newGame(1)
    place(g, Fixtures.solvedSpec())
    check(invariants(g), "solved board is valid")
    check(g:canAutoComplete(), "auto-complete is offered")
    g:startAutoComplete()
    local guard = 0
    while g.autoCompleting and guard < 1000 do
        g:update(KlondikeGame.AUTO_STEP)
        guard = guard + 1
    end
    check(g:isWon(), "auto-complete wins")
    check(g.scoring.moves == 52, "52 moves to finish (" .. g.scoring.moves .. ")")
    check(g:undo() and not g:isWon(), "undo after the win reopens the game")
end

return function()
    local names = {}
    for name in pairs(tests) do names[#names + 1] = name end
    table.sort(names)
    local t0 = love.timer.getTime()
    for _, name in ipairs(names) do
        local before = T.failed
        print("- " .. name)
        local ok, err = pcall(tests[name])
        if not ok then
            T.failed = T.failed + 1
            print("  ERROR: " .. tostring(err))
        elseif T.failed == before then
            print("  ok")
        end
    end
    print(string.format("\n%d checks passed, %d failed (%.1fs)", T.passed, T.failed, love.timer.getTime() - t0))
    return T.failed == 0
end
