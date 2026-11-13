-- Run from the addon root: lua5.1 tests/test_tracker.lua
-- Stub frames: title and objective text 12 high, top header 32, zone header 26, spacing 2.
-- Each quest with one objective takes 30: the first starts 62 below the top.
local rows, zoneHeaders, sizeHook = {}, {}, nil
local HEADER_HEIGHTS = { ObjectiveTrackerContainerHeaderTemplate = 32, ObjectiveTrackerModuleHeaderTemplate = 26 }

local function NewRegion(height)
    local region = { shown = true, height = height or 0 }
    function region:SetPoint() end
    function region:ClearAllPoints() end
    function region:SetWidth() end
    function region:SetHeight(h) self.height = h end
    function region:SetSize(_, h) self.height = h end
    function region:GetHeight() return self.height end
    function region:GetWidth() return 0 end
    function region:GetTop() return self.top end
    function region:GetBottom() return self.bottom end
    function region:GetLeft() return self.left end
    function region:GetRight() return self.right end
    function region:IsShown() return self.shown end
    function region:GetStringHeight() return 12 end
    function region:SetText(text) self.text = text end
    function region:SetTextColor() end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:EnableMouse() end
    function region:SetScript(script, fn) self.scripts = self.scripts or {}; self.scripts[script] = fn end
    function region:EnableMouseWheel() end
    function region:RegisterForClicks() end
    function region:SetCollapsed() end
    function region:CreateFontString() return NewRegion() end
    return region
end

CreateFrame = function(frameType, _, _, template)
    local frame = NewRegion(HEADER_HEIGHTS[template])
    if template then
        frame.Text, frame.MinimizeButton = NewRegion(), NewRegion()
    end
    if template == "ObjectiveTrackerModuleHeaderTemplate" then
        zoneHeaders[#zoneHeaders + 1] = frame
    elseif frameType == "Button" then
        rows[#rows + 1] = frame
    end
    return frame
end
UIParent = NewRegion()
ObjectiveTrackerFrame = NewRegion()
function ObjectiveTrackerFrame:HookScript(script, fn)
    if script == "OnSizeChanged" then sizeHook = fn end
end
local timerHooks = {}
QuestTimerFrame = NewRegion()
QuestTimerFrame.shown = false
function QuestTimerFrame:HookScript(script, fn) timerHooks[script] = fn end
TRACKER_HEADER_QUESTS = "Quests"
OBJECTIVE_TRACKER_COLOR = { Normal = { r = 1, g = 1, b = 1 }, Complete = { r = 0.6, g = 0.6, b = 0.6 } }
GetQuestDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
local inCombat = false
InCombatLockdown = function() return inCombat end
format = string.format

local refreshes = 0
local ns = {
    SetItemButton = function() end,
    HideItemButtonsFrom = function() end,
    SetPlayButton = function() return false end,
    PLAY_SIZE = 14,
    QuestTitle = function(quest) return quest.title end,
    RequestRefresh = function() refreshes = refreshes + 1 end,
}
assert(loadfile("Tracker.lua"))("QuestZones", ns)

local function Quest(questID)
    return { questID = questID, title = "Quest " .. questID, level = 10, complete = false,
        objectives = { { text = "Objective", finished = false } } }
end

local zones = {
    { name = "Elwynn", quests = { Quest(1), Quest(2), Quest(3), Quest(4) } },
    { name = "Westfall", quests = { Quest(5) } },
}

local function Shown(list)
    local count = 0
    for _, region in ipairs(list) do
        if region.shown then count = count + 1 end
    end
    return count
end

-- Unset height (0): everything shows.
assert(ns.Render(zones) == true)
assert(Shown(rows) == 5 and Shown(zoneHeaders) == 2, Shown(rows) .. " rows")

-- Edit Mode height 150: quests 1 and 2 end at 92 and 122; quest 3 would end at 152 and is left out,
-- and nothing after it shows.
ObjectiveTrackerFrame.height = 150
ns.Render(zones)
assert(Shown(rows) == 2, Shown(rows) .. " rows")
assert(Shown(zoneHeaders) == 1, Shown(zoneHeaders) .. " zone headers")

-- Height 152 fits quest 3 exactly.
ObjectiveTrackerFrame.height = 152
ns.Render(zones)
assert(Shown(rows) == 3, Shown(rows) .. " rows")

-- A zone header that does not fit is left out too.
ObjectiveTrackerFrame.height = 60
ns.Render(zones)
assert(Shown(rows) == 0 and Shown(zoneHeaders) == 0, Shown(zoneHeaders) .. " zone headers")

-- Resizing the Blizzard tracker (Edit Mode Height) redraws.
assert(sizeHook, "no OnSizeChanged hook")
sizeHook()
assert(refreshes == 1, refreshes)

local function ShownQuests()
    local ids = {}
    for _, row in ipairs(rows) do
        if row.shown then ids[#ids + 1] = row.questID end
    end
    return table.concat(ids, ",")
end

local function ShownZones()
    local names = {}
    for _, zoneHeader in ipairs(zoneHeaders) do
        if zoneHeader.shown then names[#names + 1] = zoneHeader.zoneName end
    end
    return table.concat(names, ",")
end

local function Wheel(delta, times)
    for _ = 1, times or 1 do
        ns.tracker.scripts.OnMouseWheel(ns.tracker, delta)
        ns.Render(zones)
    end
end

-- Height 150 shows two quests. One notch down drops quest 1; Elwynn's header stays above quest 2.
ObjectiveTrackerFrame.height = 150
ns.Render(zones)
assert(ShownQuests() == "1,2", ShownQuests())
Wheel(-1)
assert(ShownQuests() == "2,3" and ShownZones() == "Elwynn", ShownQuests() .. " / " .. ShownZones())

-- Scrolling down stops once the rest fits: quest 4 with Westfall and quest 5 end exactly at 150.
Wheel(-1, 5)
assert(ShownQuests() == "4,5" and ShownZones() == "Elwynn,Westfall", ShownQuests() .. " / " .. ShownZones())

-- Scrolling up stops at the top.
Wheel(1, 10)
assert(ShownQuests() == "1,2", ShownQuests())

-- Nothing to scroll when everything fits.
ObjectiveTrackerFrame.height = 0
ns.Render(zones)
Wheel(-1)
assert(ShownQuests() == "1,2,3,4,5", ShownQuests())

-- A collapsed zone is one step: Elwynn collapsed, then one notch shows Westfall alone.
ObjectiveTrackerFrame.height = 92
zoneHeaders[1].scripts.OnMouseUp(zoneHeaders[1])
ns.Render(zones)
assert(ShownZones() == "Elwynn" and ShownQuests() == "", ShownQuests() .. " / " .. ShownZones())
Wheel(-1)
assert(ShownZones() == "Westfall" and ShownQuests() == "5", ShownQuests() .. " / " .. ShownZones())
Wheel(1)
assert(ShownZones() == "Elwynn", ShownZones())
zoneHeaders[1].scripts.OnMouseUp(zoneHeaders[1])

-- Fewer quests than the scroll position: it moves back to the last quest.
ObjectiveTrackerFrame.height = 150
ns.Render(zones)
Wheel(-1, 3)
assert(ShownQuests() == "4,5", ShownQuests())
ns.Render({ { name = "Elwynn", quests = { Quest(1), Quest(2) } } })
assert(ShownQuests() == "2", ShownQuests())

-- In combat a notch waits; it applies once combat ends.
ns.Render(zones)
inCombat = true
local before = ShownQuests()
ns.tracker.scripts.OnMouseWheel(ns.tracker, 1)
assert(ns.Render(zones) == false and ShownQuests() == before, ShownQuests())
inCombat = false
assert(ns.Render(zones) == true and ShownQuests() ~= before, ShownQuests())

-- Blizzard's Quest Timers box over the tracker's top: content starts below the box (52 lower here), so at
-- height 150 only quest 1 fits.
Wheel(1, 10)
ObjectiveTrackerFrame.height = 150
ns.tracker.top, ns.tracker.left, ns.tracker.right = 500, 1000, 1260
QuestTimerFrame.top, QuestTimerFrame.bottom, QuestTimerFrame.left, QuestTimerFrame.right = 520, 448, 1050, 1208
QuestTimerFrame.shown = true
ns.Render(zones)
assert(ShownQuests() == "1", ShownQuests())

-- Beside the tracker, below its height limit, or hidden: no push.
QuestTimerFrame.left, QuestTimerFrame.right = 600, 758
ns.Render(zones)
assert(ShownQuests() == "1,2", ShownQuests())
QuestTimerFrame.left, QuestTimerFrame.right, QuestTimerFrame.top, QuestTimerFrame.bottom = 1050, 1208, 300, 228
ns.Render(zones)
assert(ShownQuests() == "1,2", ShownQuests())
QuestTimerFrame.top, QuestTimerFrame.bottom = 520, 448
QuestTimerFrame.shown = false
ns.Render(zones)
assert(ShownQuests() == "1,2", ShownQuests())

-- Pushed down in combat waits for combat to end (it moves the secure item buttons).
QuestTimerFrame.shown = true
inCombat = true
assert(ns.Render(zones) == false and ShownQuests() == "1,2", ShownQuests())
inCombat = false
ns.Render(zones)
assert(ShownQuests() == "1", ShownQuests())

-- The box showing, hiding or resizing redraws.
refreshes = 0
for _, script in ipairs({ "OnShow", "OnHide", "OnSizeChanged" }) do
    assert(timerHooks[script], "no " .. script .. " hook")
    timerHooks[script]()
end
assert(refreshes == 3, refreshes)

print("test_tracker: OK")
