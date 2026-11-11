-- Run from the addon root: lua5.1 tests/test_core.lua
local handler, frame, timers = nil, nil, {}

ObjectiveTrackerManager = { SetCanAddModules = function() end }
CreateFrame = function()
    frame = {
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        SetScript = function(_, _, fn) handler = fn end,
    }
    return frame
end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
C_QuestLog = { RemoveQuestWatch = function() end }
GetRealZoneText = function() return "Elwynn" end

local ns = { BuildZones = function() return {} end, Render = function() return true end }
assert(loadfile("Core.lua"))("QuestZones", ns)

local function Fire(event, ...)
    handler(frame, event, ...)
end

local function Flush()
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
end

Fire("ADDON_LOADED", "QuestZones")
local hidden = QuestZonesCharDB.hidden

-- Blizzard auto-watch on objective progress (QUEST_WATCH_UPDATE) does not unhide.
ns.HideQuest(5)
Flush()
Fire("QUEST_WATCH_LIST_CHANGED", 5, true)
Fire("QUEST_WATCH_UPDATE", 5)
Flush()
assert(hidden[5], "auto-watch unhid quest 5")

-- Tracking the quest by hand (quest log checkbox) unhides it.
Fire("QUEST_WATCH_LIST_CHANGED", 5, true)
Flush()
assert(not hidden[5], "manual track did not unhide quest 5")

-- An auto-watch in an earlier frame does not block a later manual track.
ns.HideQuest(6)
Fire("QUEST_WATCH_UPDATE", 6)
Flush()
Fire("QUEST_WATCH_LIST_CHANGED", 6, true)
Flush()
assert(not hidden[6], "stale auto-watch blocked manual track of quest 6")

-- Removed quests leave the hidden list.
ns.HideQuest(7)
Fire("QUEST_REMOVED", 7)
Flush()
assert(not hidden[7], "removed quest 7 stayed hidden")

print("test_core: OK")
