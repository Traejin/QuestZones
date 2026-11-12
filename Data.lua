local addonName, ns = ...

local function BuildQuest(info)
    local questID = info.questID
    return {
        questID = questID,
        logIndex = info.questLogIndex,
        title = info.title,
        level = info.level,
        isScaling = info.isScaling,
        complete = C_QuestLog.IsComplete(questID),
        objectives = C_QuestLog.GetQuestObjectives(questID) or {},
        itemLink = (GetQuestLogSpecialItemInfo(info.questLogIndex)),
    }
end

-- Same visibility rule as Blizzard's quest log (QuestLogQuests_ShouldShowQuestButton), plus the hidden list.
local function IsShown(info, hidden)
    if info.isHidden or info.isTask or hidden[info.questID] then
        return false
    end
    return not info.isBounty or C_QuestLog.IsComplete(info.questID)
end

local function GroupByHeader(hidden)
    local zones, zone = {}, nil
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            zone = { name = info.title, quests = {} }
            zones[#zones + 1] = zone
        elseif info and IsShown(info, hidden) then
            if not zone then
                zone = { name = OTHER, quests = {} }
                zones[#zones + 1] = zone
            end
            zone.quests[#zone.quests + 1] = BuildQuest(info)
        end
    end
    return zones
end

-- Zones with at least one visible quest; current zone first, the rest in quest log order.
function ns.BuildZones(hidden, currentZone)
    local result = {}
    for _, zone in ipairs(GroupByHeader(hidden)) do
        if #zone.quests > 0 then
            if zone.name == currentZone then
                table.insert(result, 1, zone)
            else
                result[#result + 1] = zone
            end
        end
    end
    return result
end

-- Completed quests read "<title> (Complete)", as Blizzard's quest info panel writes it (QuestInfo.lua).
function ns.QuestTitle(quest)
    return quest.complete and quest.title .. " (" .. COMPLETE .. ")" or quest.title
end
