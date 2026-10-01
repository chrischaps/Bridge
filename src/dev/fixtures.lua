-- Shared helpers for building known game states (self-tests and captures)

local KlondikeGame = require("src.games.klondike.game")

local Fixtures = {}

function Fixtures.code(card)
    local r = card.rank == "10" and "T" or card.rank
    return r .. card.suit:sub(1, 1):upper()
end

function Fixtures.newGame(seed, drawCount)
    local g = KlondikeGame.new(960, 540)
    g:deal(drawCount or 1, seed or 1, false)
    return g
end

-- Rearrange a dealt game. spec: {t1 = {"*KS", "QH"}, f1 = {"AH"}, w = {...}}
-- "*" = face down. Unlisted cards go to the stock, face down.
function Fixtures.place(g, spec)
    local byCode = {}
    for _, c in ipairs(g.cards) do byCode[Fixtures.code(c)] = c end
    for _, p in ipairs(g.piles) do p:clear() end
    g.history, g.flyLayer = {}, {}
    g.state = "playing"
    g.scoring:start(g.drawCount)
    local used = {}
    local function fill(pile, list)
        for _, s in ipairs(list or {}) do
            local down = s:sub(1, 1) == "*"
            local c = assert(byCode[down and s:sub(2) or s], "no card " .. s)
            used[c] = true
            c:setFaceUp(not down, true)
            table.insert(pile.cards, c)
        end
    end
    for i, t in ipairs(g.tableaus) do fill(t, spec["t" .. i]) end
    for i, f in ipairs(g.foundations) do fill(f, spec["f" .. i]) end
    fill(g.waste, spec.w)
    g.waste.fanCount = #g.waste.cards
    for _, c in ipairs(g.cards) do
        if not used[c] then
            c:setFaceUp(false, true)
            table.insert(g.stock.cards, c)
        end
    end
    for _, p in ipairs(g.piles) do p:updateCardPositions(true) end
    return byCode
end

-- A finished-looking board: four king-down runs ready to auto-complete
function Fixtures.solvedSpec()
    local ranks = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K"}
    local pairsBy = {{"S", "H"}, {"H", "S"}, {"C", "D"}, {"D", "C"}}
    local spec = {t1 = {}, t2 = {}, t3 = {}, t4 = {}}
    for col = 1, 4 do
        for r = 13, 1, -1 do
            local p = pairsBy[col]
            table.insert(spec["t" .. col], ranks[r] .. (r % 2 == 1 and p[1] or p[2]))
        end
    end
    return spec
end

return Fixtures
