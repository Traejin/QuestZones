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
    function region:GetStringHeight() return 12 end
    function region:SetText(text) self.text = text end
    function region:SetTextColor() end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:EnableMouse() end
    function region:SetScript() end
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
TRACKER_HEADER_QUESTS = "Quests"
OBJECTIVE_TRACKER_COLOR = { Normal = { r = 1, g = 1, b = 1 }, Complete = { r = 0.6, g = 0.6, b = 0.6 } }
GetQuestDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
InCombatLockdown = function() return false end
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

print("test_tracker: OK")
