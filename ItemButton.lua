local addonName, ns = ...

-- Secure buttons: create, move, show, hide and SetAttribute only out of combat. Callers check InCombatLockdown().
local buttons = {}

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetQuestLogSpecialItem(self.logIndex)
    GameTooltip:Show()
end

local function CreateItemButton()
    local button = CreateFrame("Button", nil, ns.tracker, "SecureActionButtonTemplate")
    button:SetSize(26, 26)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "item")
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetAllPoints()
    local border = button:CreateTexture(nil, "ARTWORK")
    border:SetAtlas("UI-QuestTrackerButton-QuestItem-Frame")
    border:SetSize(42, 42)
    border:SetPoint("CENTER")
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- Anchored to the tracker, not the quest row, so rows stay movable in combat.
function ns.SetItemButton(index, quest, y)
    local button = buttons[index] or CreateItemButton()
    buttons[index] = button
    local _, icon = GetQuestLogSpecialItemInfo(quest.logIndex)
    button.icon:SetTexture(icon)
    button.logIndex = quest.logIndex
    button:SetAttribute("item", quest.itemLink)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", ns.tracker, "TOPRIGHT", 0, y)
    button:Show()
end

function ns.HideItemButtonsFrom(index)
    for i = index, #buttons do
        buttons[i]:Hide()
    end
end
