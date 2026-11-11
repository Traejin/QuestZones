local addonName, ns = ...

-- Blizzard's own switch (used by Blizzard_Kiosk): Init after login adds no modules while false.
-- The empty ObjectiveTrackerFrame hides itself outside Edit Mode and stays selectable inside it.
if ObjectiveTrackerManager.SetCanAddModules then
    ObjectiveTrackerManager:SetCanAddModules(false)
else
    ObjectiveTrackerFrame:SetAlpha(0)
end

local REFRESH_EVENTS = {
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_WATCH_UPDATE", "QUEST_REMOVED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}

local scheduled, pending = false, false
-- Watch-list additions this frame. Blizzard auto-watches on objective progress (QUEST_WATCH_UPDATE, see
-- QuestMapFrame_OnEvent) and fires QUEST_WATCH_LIST_CHANGED before this addon sees QUEST_WATCH_UPDATE,
-- so the unhide decision waits for Refresh, one frame later.
local tracked, autoWatched = {}, {}

local function UnhideTracked()
    for questID in pairs(tracked) do
        if not autoWatched[questID] then
            QuestZonesCharDB.hidden[questID] = nil
        end
    end
    tracked, autoWatched = {}, {}
end

local function Refresh()
    scheduled = false
    UnhideTracked()
    local zones = ns.BuildZones(QuestZonesCharDB.hidden, GetRealZoneText())
    pending = not ns.Render(zones)
end

function ns.RequestRefresh()
    if scheduled then
        return
    end
    scheduled = true
    C_Timer.After(0, Refresh)
end

function ns.HideQuest(questID)
    QuestZonesCharDB.hidden[questID] = true
    C_QuestLog.RemoveQuestWatch(questID)
    ns.RequestRefresh()
end

local function OnAddonLoaded(frame)
    QuestZonesCharDB = QuestZonesCharDB or {}
    QuestZonesCharDB.hidden = QuestZonesCharDB.hidden or {}
    frame:UnregisterEvent("ADDON_LOADED")
    for _, event in ipairs(REFRESH_EVENTS) do
        frame:RegisterEvent(event)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(frame, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            OnAddonLoaded(frame)
        end
        return
    end
    if event == "QUEST_WATCH_LIST_CHANGED" and arg1 and arg2 then
        tracked[arg1] = true
    elseif event == "QUEST_WATCH_UPDATE" then
        autoWatched[arg1] = true
    elseif event == "QUEST_REMOVED" then
        QuestZonesCharDB.hidden[arg1] = nil
    elseif event == "PLAYER_REGEN_ENABLED" and not pending then
        return
    end
    ns.RequestRefresh()
end)
