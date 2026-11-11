-- Run from the addon root: lua5.1 tests/test_spoken.lua
local created, callbacks, refreshes, voiced = 0, {}, 0, {}

local function NewRegion()
    local region = { shown = false }
    function region:SetSize() end
    function region:SetHitRectInsets() end
    function region:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function region:ClearAllPoints() self.x, self.y = nil, nil end
    function region:SetColorTexture() end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:CreateTexture() return NewRegion() end
    return region
end

CreateFrame = function()
    created = created + 1
    return NewRegion()
end
hooksecurefunc = function(target, name, post)
    local original = target[name]
    target[name] = function(...) original(...); post(...) end
end
C_QuestLog = { GetTitleForQuestID = function(questID) return "Quest " .. questID end }

local function StubSpoken()
    Spoken = {
        IsCompatible = function(_, version) return version == 1 end,
        DressBoxButton = function(_, button) button.SetBox = function() end end,
        RegisterCallback = function(_, event, fn) callbacks[event] = fn end,
    }
    VoiceOver = { QuestOverlayUI = {
        ShowsTrackerButton = function(_, questID)
            if questID == 99 then error("pack failure") end
            return voiced[questID] or false
        end,
        BindPlayButton = function(_, button, questID, title) button.questID, button.title = questID, title end,
        SetPlayButtonState = function() end,
        FollowQueue = function() end,
        UpdateTrackerButtons = function() end,
    } }
end

local function Load()
    local ns = { tracker = NewRegion(), RequestRefresh = function() refreshes = refreshes + 1 end }
    assert(loadfile("Spoken.lua"))("QuestZones", ns)
    return ns
end

StubSpoken()
local ns = Load()
local row = NewRegion()

-- A voiced quest gets one Play button, bound to it, at the given column offset.
voiced[1] = true
assert(ns.SetPlayButton(row, 1, -40) == true)
assert(row.playButton.shown and row.playButton.questID == 1 and row.playButton.title == "Quest 1")
assert(row.playButton.y == -40 and created == 1)

-- An unvoiced quest hides it.
assert(ns.SetPlayButton(row, 2, -40) == false)
assert(not row.playButton.shown)

-- A row reused for another voiced quest rebinds the same button and drops the old line.
voiced[3] = true
row.playButton.questID, row.playButton.soundData = 1, "old line"
assert(ns.SetPlayButton(row, 3, -60) == true)
assert(row.playButton.shown and row.playButton.questID == 3 and row.playButton.soundData == nil)
assert(created == 1)

-- A Spoken error hides the button instead of breaking the layout.
assert(ns.SetPlayButton(row, 99, -60) == false)
assert(not row.playButton.shown)

-- Spoken's pack load, part switch and settings toggle redraw the tracker.
callbacks.VOICE_PACKS_LOADED()
callbacks.PART_SWITCHED("quests")
VoiceOver.QuestOverlayUI.UpdateTrackerButtons()
assert(refreshes == 3, refreshes)

-- Without Spoken: no button, no frame, no error.
Spoken, VoiceOver, created = nil, nil, 0
ns = Load()
local bare = NewRegion()
assert(ns.SetPlayButton(bare, 1, -40) == false)
assert(created == 0 and bare.playButton == nil)

print("test_spoken: OK")
