local addonName, ns = ...

local SPACING = 2
local QUEST_INDENT = 10
local OBJECTIVE_INDENT = 20
local ITEM_SPACE = 30
local ITEM_HEIGHT = 26
local DEFAULT_WIDTH = 260

-- Session-only collapse and scroll state. `offset` counts steps scrolled past: one per quest, one per collapsed zone.
local state = { all = false, zones = {}, quests = {}, offset = 0, canScrollDown = false }
local zoneHeaders, questRows, lines = {}, {}, {}
local lastKey

-- Anchored to the emptied Blizzard tracker so Edit Mode positions it. Never moved or hidden after this; its height
-- follows the content (wheel area) and is set out of combat only, as it parents secure item buttons.
local tracker = CreateFrame("Frame", nil, UIParent)
tracker:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPLEFT")
tracker:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT")
tracker:SetHeight(1)
ns.tracker = tracker

-- Wheel only; clicks on empty space still reach the world.
tracker:EnableMouseWheel(true)
tracker:SetScript("OnMouseWheel", function(_, delta)
    if delta > 0 and state.offset > 0 then
        state.offset = state.offset - 1
    elseif delta < 0 and state.canScrollDown then
        state.offset = state.offset + 1
    else
        return
    end
    ns.RequestRefresh()
end)

local header = CreateFrame("Frame", nil, tracker, "ObjectiveTrackerContainerHeaderTemplate")
header.Text:SetText(TRACKER_HEADER_QUESTS)
header.MinimizeButton:SetScript("OnClick", function()
    state.all = not state.all
    ns.RequestRefresh()
end)

-- Edit Mode's Height setting resizes the emptied Blizzard tracker (ObjectiveTrackerContainerMixin:UpdateHeight).
ObjectiveTrackerFrame:HookScript("OnSizeChanged", function() ns.RequestRefresh() end)

-- Blizzard's Quest Timers box (Blizzard_QuestTimer, classic clients) stays in the right-hand frame stack, drawn
-- behind a tracker moved in Edit Mode. While it shows over the tracker, the content starts below it.
if QuestTimerFrame then
    for _, script in ipairs({ "OnShow", "OnHide", "OnSizeChanged" }) do
        QuestTimerFrame:HookScript(script, function() ns.RequestRefresh() end)
    end
end

local function MaxHeight()
    local height = ObjectiveTrackerFrame:GetHeight()
    return height > 0 and height or math.huge
end

local function TimerOffset()
    local timer = QuestTimerFrame
    if not (timer and timer:IsShown()) then
        return 0
    end
    local top, left, right = tracker:GetTop(), tracker:GetLeft(), tracker:GetRight()
    local timerTop, timerBottom = timer:GetTop(), timer:GetBottom()
    local timerLeft, timerRight = timer:GetLeft(), timer:GetRight()
    if not (top and left and right and timerTop and timerBottom and timerLeft and timerRight) then
        return 0
    end
    if timerRight <= left or timerLeft >= right or timerBottom >= top or timerTop <= top - MaxHeight() then
        return 0
    end
    return top - timerBottom
end

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
        return y
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
    row.Text:SetText(ns.QuestTitle(quest))
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

-- Content below the Blizzard tracker's height (Edit Mode Height) is left out, as Blizzard's tracker does.
-- Rolls `counts` back to `before` when `bottom` does not fit, so the frames laid out since are hidden.
local function Fits(counts, before, bottom)
    if -bottom <= counts.maxHeight then
        return true
    end
    counts.zones, counts.rows, counts.lines, counts.items = before.zones, before.rows, before.lines, before.items
    counts.full = true
    return false
end

local function Snapshot(counts)
    return { zones = counts.zones, rows = counts.rows, lines = counts.lines, items = counts.items }
end

-- True while scroll steps remain to pass; consumes one.
local function Skip(counts)
    if counts.skip > 0 then
        counts.skip = counts.skip - 1
        return true
    end
    return false
end

local function LayoutZoneHeader(zone, collapsed, y, counts)
    counts.zones = counts.zones + 1
    local zoneHeader = Acquire(zoneHeaders, counts.zones, CreateZoneHeader)
    zoneHeader.zoneName = zone.name
    zoneHeader:SetCollapsed(collapsed)
    zoneHeader.Text:SetText(collapsed and format("%s (%d)", zone.name, #zone.quests) or zone.name)
    zoneHeader:ClearAllPoints()
    zoneHeader:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, y)
    return y - zoneHeader:GetHeight() - SPACING
end

-- An expanded zone's header is drawn above its first quest not scrolled past.
local function LayoutZone(zone, y, counts)
    if state.zones[zone.name] then
        if Skip(counts) then
            return y
        end
        local before = Snapshot(counts)
        local bottom = LayoutZoneHeader(zone, true, y, counts)
        return Fits(counts, before, bottom) and bottom or y
    end
    local headed = false
    for _, quest in ipairs(zone.quests) do
        if not Skip(counts) then
            local before = Snapshot(counts)
            local top = headed and y or LayoutZoneHeader(zone, false, y, counts)
            local bottom = LayoutQuest(quest, top, counts)
            if not Fits(counts, before, bottom) then
                return y
            end
            headed, y = true, bottom
        end
    end
    return y
end

local function Layout(zones, timerOffset)
    local counts = { zones = 0, rows = 0, lines = 0, items = 0, skip = state.offset, maxHeight = MaxHeight() }
    header:SetCollapsed(state.all)
    header:ClearAllPoints()
    header:SetPoint("TOP", tracker, "TOP", 0, -timerOffset)
    local y = -timerOffset - header:GetHeight() - SPACING
    for _, zone in ipairs(state.all and {} or zones) do
        y = LayoutZone(zone, y, counts)
        if counts.full then
            break
        end
    end
    state.canScrollDown = counts.full or false
    HideFrom(zoneHeaders, counts.zones + 1)
    HideFrom(questRows, counts.rows + 1)
    HideFrom(lines, counts.lines + 1)
    if not InCombatLockdown() then
        ns.HideItemButtonsFrom(counts.items + 1)
        tracker:SetHeight(math.max(1, -y))
    end
end

local function StepCount(zones)
    local steps = 0
    for _, zone in ipairs(zones) do
        steps = steps + (state.zones[zone.name] and 1 or #zone.quests)
    end
    return steps
end

-- Everything that decides which frames exist and where item buttons go.
local function StructureKey(zones, timerOffset)
    local parts = { tostring(state.all), ObjectiveTrackerFrame:GetHeight(), state.offset, timerOffset }
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
    state.offset = math.max(0, math.min(state.offset, StepCount(zones) - 1))
    local timerOffset = TimerOffset()
    local key = StructureKey(zones, timerOffset)
    local inCombat = InCombatLockdown()
    if inCombat and key ~= lastKey then
        return false
    end
    Layout(zones, timerOffset)
    lastKey = key
    return not inCombat
end
