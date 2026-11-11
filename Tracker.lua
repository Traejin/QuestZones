local addonName, ns = ...

local SPACING = 2
local QUEST_INDENT = 10
local OBJECTIVE_INDENT = 20
local ITEM_SPACE = 30
local ITEM_HEIGHT = 26
local DEFAULT_WIDTH = 260

-- Session-only collapse state.
local state = { all = false, zones = {}, quests = {} }
local zoneHeaders, questRows, lines = {}, {}, {}
local lastKey

-- Anchored to the emptied Blizzard tracker so Edit Mode positions it. Never moved, sized or hidden after this.
local tracker = CreateFrame("Frame", nil, UIParent)
tracker:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT")
tracker:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT")
tracker:SetHeight(1)
ns.tracker = tracker

local header = CreateFrame("Frame", nil, tracker, "ObjectiveTrackerContainerHeaderTemplate")
header:SetPoint("TOP")
header.Text:SetText(TRACKER_HEADER_QUESTS)
header.MinimizeButton:SetScript("OnClick", function()
    state.all = not state.all
    ns.RequestRefresh()
end)

local function ToggleZone(name)
    state.zones[name] = not state.zones[name]
    ns.RequestRefresh()
end

local function Width()
    local width = tracker:GetWidth()
    return width > 0 and width or DEFAULT_WIDTH
end

local function Acquire(list, index, create)
    local region = list[index] or create()
    list[index] = region
    region:Show()
    return region
end

local function HideFrom(list, index)
    for i = index, #list do
        list[i]:Hide()
    end
end

local function ShowQuestMenu(row, questID)
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(C_QuestLog.GetTitleForQuestID(questID))
        if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
            root:CreateButton(SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(questID) end)
        else
            root:CreateButton(STOP_SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(0) end)
        end
        root:CreateButton(OBJECTIVES_SHOW_QUEST_MAP, function() QuestMapFrame_OpenToQuestDetails(questID) end)
        root:CreateButton(OBJECTIVES_STOP_TRACKING, function() ns.HideQuest(questID) end)
        if C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
            root:CreateButton(SHARE_QUEST, function() QuestUtil.ShareQuest(questID) end)
        end
        root:CreateButton(ABANDON_QUEST_ABBREV, function() QuestMapQuestOptions_AbandonQuest(questID) end)
    end)
end

local function OnQuestClick(row, button)
    local questID = row.questID
    if ChatFrameUtil.TryInsertQuestLinkForQuestID(questID) then
        return
    end
    if button == "RightButton" then
        ShowQuestMenu(row, questID)
    elseif IsControlKeyDown() then
        state.quests[questID] = not state.quests[questID]
        ns.RequestRefresh()
    else
        QuestMapFrame_OpenToQuestDetails(questID)
    end
end

local function CreateZoneHeader()
    local zoneHeader = CreateFrame("Frame", nil, tracker, "ObjectiveTrackerModuleHeaderTemplate")
    zoneHeader:EnableMouse(true)
    zoneHeader:SetScript("OnMouseUp", function(self) ToggleZone(self.zoneName) end)
    zoneHeader.MinimizeButton:SetScript("OnClick", function() ToggleZone(zoneHeader.zoneName) end)
    return zoneHeader
end

local function CreateQuestRow()
    local row = CreateFrame("Button", nil, tracker)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.Text = row:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
    row.Text:SetPoint("TOPLEFT")
    row:SetScript("OnClick", OnQuestClick)
    return row
end

local function CreateLine()
    return tracker:CreateFontString(nil, "ARTWORK", "ObjectiveTrackerLineFont")
end

local function AddLine(text, color, y, counts)
    counts.lines = counts.lines + 1
    local line = Acquire(lines, counts.lines, CreateLine)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", tracker, "TOPLEFT", OBJECTIVE_INDENT, y)
    line:SetWidth(Width() - OBJECTIVE_INDENT - ITEM_SPACE)
    line:SetText(text)
    line:SetTextColor(color.r, color.g, color.b)
    return y - line:GetStringHeight() - SPACING
end

local function LayoutObjectives(quest, y, counts)
    if quest.complete then
        return AddLine(QUEST_WATCH_QUEST_READY, OBJECTIVE_TRACKER_COLOR.Complete, y, counts)
    end
    for _, objective in ipairs(quest.objectives) do
        if objective.text and objective.text ~= "" then
            local color = objective.finished and OBJECTIVE_TRACKER_COLOR.Complete or OBJECTIVE_TRACKER_COLOR.Normal
            y = AddLine("- " .. objective.text, color, y, counts)
        end
    end
    return y
end

local function LayoutQuest(quest, y, counts)
    local top = y
    counts.rows = counts.rows + 1
    local row = Acquire(questRows, counts.rows, CreateQuestRow)
    local width = Width() - QUEST_INDENT - ITEM_SPACE
    row.questID = quest.questID
    row.Text:SetWidth(width)
    row.Text:SetText(quest.title)
    local color = GetQuestDifficultyColor(quest.level, quest.isScaling, quest.questID)
    row.Text:SetTextColor(color.r, color.g, color.b)
    row:SetSize(width, row.Text:GetStringHeight())
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", tracker, "TOPLEFT", QUEST_INDENT, y)
    y = y - row:GetHeight() - SPACING
    if not state.quests[quest.questID] then
        y = LayoutObjectives(quest, y, counts)
    end
    -- Right-hand column: item button, then Spoken's Play button below it.
    local column = top
    if quest.itemLink then
        counts.items = counts.items + 1
        if not InCombatLockdown() then
            ns.SetItemButton(counts.items, quest, top)
        end
        column = column - ITEM_HEIGHT - SPACING
    end
    if ns.SetPlayButton(row, quest.questID, column) then
        column = column - ns.PLAY_SIZE - SPACING
    end
    return math.min(y, column) - SPACING
end

local function LayoutZone(zone, y, counts)
    counts.zones = counts.zones + 1
    local zoneHeader = Acquire(zoneHeaders, counts.zones, CreateZoneHeader)
    local collapsed = state.zones[zone.name]
    zoneHeader.zoneName = zone.name
    zoneHeader:SetCollapsed(collapsed)
    zoneHeader.Text:SetText(collapsed and format("%s (%d)", zone.name, #zone.quests) or zone.name)
    zoneHeader:ClearAllPoints()
    zoneHeader:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, y)
    y = y - zoneHeader:GetHeight() - SPACING
    if collapsed then
        return y
    end
    for _, quest in ipairs(zone.quests) do
        y = LayoutQuest(quest, y, counts)
    end
    return y
end

local function Layout(zones)
    local counts = { zones = 0, rows = 0, lines = 0, items = 0 }
    header:SetCollapsed(state.all)
    local y = -header:GetHeight() - SPACING
    if not state.all then
        for _, zone in ipairs(zones) do
            y = LayoutZone(zone, y, counts)
        end
    end
    HideFrom(zoneHeaders, counts.zones + 1)
    HideFrom(questRows, counts.rows + 1)
    HideFrom(lines, counts.lines + 1)
    if not InCombatLockdown() then
        ns.HideItemButtonsFrom(counts.items + 1)
    end
end

-- Everything that decides which frames exist and where item buttons go.
local function StructureKey(zones)
    local parts = { tostring(state.all) }
    for _, zone in ipairs(zones) do
        parts[#parts + 1] = zone.name .. tostring(state.zones[zone.name])
        for _, quest in ipairs(zone.quests) do
            parts[#parts + 1] = table.concat({ quest.questID, tostring(quest.complete), #quest.objectives,
                tostring(quest.itemLink), tostring(state.quests[quest.questID]) }, ":")
        end
    end
    return table.concat(parts, "|")
end

-- In combat, only a structurally unchanged layout runs (text in place); the caller re-renders after combat.
function ns.Render(zones)
    local key = StructureKey(zones)
    local inCombat = InCombatLockdown()
    if inCombat and key ~= lastKey then
        return false
    end
    Layout(zones)
    lastKey = key
    return not inCombat
end
