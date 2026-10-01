-- Lifetime statistics, kept in the settings file

local settings = require("lib.core.settings")

local Stats = {}

-- Keys added to the settings schema (merged in main.lua)
Stats.DEFAULTS = {
    statPlayed = 0,
    statWon = 0,
    statStreak = 0,
    statBestStreak = 0,
    statBestTime1 = 0,   -- seconds; 0 = none yet
    statBestTime3 = 0,
    statBestScore1 = 0,
    statBestScore3 = 0,
}

local saveFn = function() settings.save() end

-- Replace how stats are persisted (capture mode turns saving off)
function Stats.setSaver(fn)
    saveFn = fn
end

function Stats.get()
    local s = {}
    for k in pairs(Stats.DEFAULTS) do s[k] = settings.get(k) or 0 end
    return s
end

-- A game with moves in it was abandoned for a new deal
function Stats.recordLoss()
    settings.set("statPlayed", settings.get("statPlayed") + 1)
    settings.set("statStreak", 0)
    saveFn()
end

-- Returns which records fell: {time = bool, score = bool}
function Stats.recordWin(drawMode, seconds, score)
    local s = Stats.get()
    settings.set("statPlayed", s.statPlayed + 1)
    settings.set("statWon", s.statWon + 1)
    local streak = s.statStreak + 1
    settings.set("statStreak", streak)
    settings.set("statBestStreak", math.max(streak, s.statBestStreak))

    local records = {}
    local tKey, sKey = "statBestTime" .. drawMode, "statBestScore" .. drawMode
    seconds = math.floor(seconds)
    if s[tKey] == 0 or seconds < s[tKey] then
        records.time = s[tKey] ~= 0
        settings.set(tKey, seconds)
    end
    if score > s[sKey] then
        records.score = s[sKey] ~= 0
        settings.set(sKey, score)
    end
    saveFn()
    return records
end

return Stats
