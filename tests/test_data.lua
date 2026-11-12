-- Run from the addon root: lua5.1 tests/test_data.lua
local entries = {}

C_QuestLog = {
    GetNumQuestLogEntries = function() return #entries end,
    GetInfo = function(i) return entries[i] end,
    IsComplete = function(questID) return questID == 3 end,
    GetQuestObjectives = function(questID) return { { text = "Objective " .. questID, finished = false } } end,
}
GetQuestLogSpecialItemInfo = function(logIndex)
    if logIndex == 2 then return "|Hitem:5|h[Item]|h", 134400 end
end
OTHER = "Other"
COMPLETE = "Complete"

local ns = {}
assert(loadfile("Data.lua"))("QuestZones", ns)

local function Header(title)
    return { isHeader = true, title = title }
end

local function Quest(logIndex, questID, flags)
    local quest = { questLogIndex = logIndex, questID = questID, title = "Quest " .. questID, level = 10 }
    for key, value in pairs(flags or {}) do quest[key] = value end
    return quest
end

local function Names(zones)
    local names = {}
    for i, zone in ipairs(zones) do names[i] = zone.name end
    return table.concat(names, ",")
end

-- Quests group under their preceding header; current zone first, others in log order.
entries = {
    Header("Elwynn"), Quest(2, 1),
    Header("Westfall"), Quest(4, 2), Quest(5, 3),
    Header("Duskwood"), Quest(7, 4),
}
local zones = ns.BuildZones({}, "Westfall")
assert(Names(zones) == "Westfall,Elwynn,Duskwood", Names(zones))
assert(#zones[1].quests == 2 and zones[1].quests[1].questID == 2)
assert(zones[1].quests[1].complete == false and zones[1].quests[2].complete == true)
assert(zones[2].quests[1].itemLink == "|Hitem:5|h[Item]|h")
assert(zones[2].quests[1].logIndex == 2 and zones[2].quests[1].title == "Quest 1")
assert(zones[2].quests[1].objectives[1].text == "Objective 1")

-- Missing or unknown current zone keeps log order.
assert(Names(ns.BuildZones({}, nil)) == "Elwynn,Westfall,Duskwood")
assert(Names(ns.BuildZones({}, "Stormwind")) == "Elwynn,Westfall,Duskwood")

-- Hidden-list and isHidden quests are excluded; zones left empty are dropped.
entries = { Header("Elwynn"), Quest(2, 1), Header("Westfall"), Quest(4, 2), Quest(5, 3, { isHidden = true }) }
zones = ns.BuildZones({ [1] = true }, nil)
assert(Names(zones) == "Westfall", Names(zones))
assert(#zones[1].quests == 1 and zones[1].quests[1].questID == 2)

-- Quests before any header go under OTHER.
entries = { Quest(1, 9), Header("Elwynn"), Quest(3, 1) }
assert(Names(ns.BuildZones({}, nil)) == "Other,Elwynn")

-- World quests, bonus objectives and unfinished bounties are excluded, as in Blizzard's quest log.
entries = {
    Header("Elwynn"), Quest(2, 1, { isTask = true }), Quest(3, 2, { isBounty = true }),
    Quest(4, 3, { isBounty = true }), Quest(5, 4),
}
zones = ns.BuildZones({}, nil)
assert(#zones[1].quests == 2, #zones[1].quests)
assert(zones[1].quests[1].questID == 3 and zones[1].quests[2].questID == 4)

-- Completed quests read "<title> (Complete)"; others keep their title.
assert(ns.QuestTitle({ title = "Quest 3", complete = true }) == "Quest 3 (Complete)")
assert(ns.QuestTitle({ title = "Quest 2", complete = false }) == "Quest 2")

print("test_data: OK")
