-- A plain hint-following player for captures: it does whatever the Hint
-- button would suggest, at a steady pace, so showcase numbers are earned.

local Bot = {}

-- Play the current deal until it is won or stuck.
-- pace: seconds of game clock per action. Returns true if won.
function Bot.play(game, pace, maxActions)
    pace = pace or 1.5
    local idleDraws = 0
    for _ = 1, maxActions or 600 do
        if game:isWon() then return true end
        if game:canAutoComplete() then
            game:startAutoComplete()
            for _ = 1, 400 do
                if not game.autoCompleting then break end
                game:update(game.AUTO_STEP or 0.08)
            end
            return game:isWon()
        end
        local h = game:findHint()
        if not h then return false end
        if h.draw then
            idleDraws = idleDraws + 1
            -- a full trip through stock and waste with nothing played: give up
            if idleDraws > (game.stock:count() + game.waste:count()) + 2 then return false end
            game:drawStock()
        else
            idleDraws = 0
            game:moveCards(h.from, h.index, h.to)
        end
        game:update(pace)
    end
    return game:isWon()
end

return Bot
