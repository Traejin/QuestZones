local addonName, ns = ...

-- Blizzard's own switch (used by Blizzard_Kiosk): Init after login adds no modules while false.
-- The empty ObjectiveTrackerFrame hides itself outside Edit Mode and stays selectable inside it.
if ObjectiveTrackerManager.SetCanAddModules then
    ObjectiveTrackerManager:SetCanAddModules(false)
else
    ObjectiveTrackerFrame:SetAlpha(0)
end

local REFRESH_EVENTS = {
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_REMOVED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}

local scheduled, pending = false, false

local function Refresh()
    scheduled = false
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
        QuestZonesCharDB.hidden[arg1] = nil
    elseif event == "QUEST_REMOVED" then
        QuestZonesCharDB.hidden[arg1] = nil
    elseif event == "PLAYER_REGEN_ENABLED" and not pending then
        return
    end
    ns.RequestRefresh()
end)
