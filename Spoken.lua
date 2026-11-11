local addonName, ns = ...

-- Play buttons of the Spoken addon (Spoken_Quests). Spoken hooks Blizzard's tracker modules, which QuestZones
-- turns off, so this mirrors its tracker adapter (Spoken_Quests/Compatibility.lua). QuestOverlayUI is not
-- Spoken's public API: every piece is checked, and a missing or failing one means no button.
local BOX, SIZE = "QuestLog-icon-ticksquare", 14
local COLUMN_INSET = -6
ns.PLAY_SIZE = SIZE

local function Overlay()
    local overlay = VoiceOver and VoiceOver.QuestOverlayUI
    if Spoken and Spoken.IsCompatible and Spoken:IsCompatible(1) and Spoken.DressBoxButton and overlay
        and overlay.ShowsTrackerButton and overlay.BindPlayButton and overlay.SetPlayButtonState then
        return Spoken, overlay
    end
end

local function CreatePlayButton(row, spoken, overlay)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(SIZE, SIZE)
    button:SetHitRectInsets(1, 1, 1, 1)
    local ok = pcall(spoken.DressBoxButton, spoken, button)
    if ok then
        ok = pcall(button.SetBox, button, BOX, SIZE, SIZE)
    end
    if not ok then
        button:Hide()
        return false
    end
    button.setPlayState = overlay.FollowQueue
    local back = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    back:SetPoint("TOPLEFT", 1, -1)
    back:SetPoint("BOTTOMRIGHT", -1, 1)
    back:SetColorTexture(0, 0, 0, 0.6)
    return button
end

local function SetPlayButton(row, questID, y)
    local spoken, overlay = Overlay()
    local voiced = spoken and overlay:ShowsTrackerButton(questID)
    if voiced and row.playButton == nil then
        row.playButton = CreatePlayButton(row, spoken, overlay)
    end
    local button = row.playButton
    if not button then
        return false
    end
    if not voiced then
        button:Hide()
        return false
    end
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", ns.tracker, "TOPRIGHT", COLUMN_INSET, y)
    if button.questID ~= questID then
        button.soundData = nil
    end
    overlay:BindPlayButton(button, questID, C_QuestLog.GetTitleForQuestID(questID) or "", "QuestZones")
    button:Show()
    overlay:SetPlayButtonState(button)
    return true
end

-- Shows Spoken's Play button on `row` when a voice pack voices the quest. Returns whether it is shown.
function ns.SetPlayButton(row, questID, y)
    local ok, shown = pcall(SetPlayButton, row, questID, y)
    if not ok and row.playButton then
        row.playButton:Hide()
    end
    return ok and shown
end

local function Refresh()
    ns.RequestRefresh()
end

local spoken, overlay = Overlay()
if spoken then
    if spoken.RegisterCallback then
        spoken:RegisterCallback("VOICE_PACKS_LOADED", Refresh)
        spoken:RegisterCallback("PART_SWITCHED", Refresh)
    end
    -- Spoken's settings panel calls this when its tracker Play option changes.
    if overlay.UpdateTrackerButtons then
        hooksecurefunc(overlay, "UpdateTrackerButtons", Refresh)
    end
end
