# QuestZones design

Date: 2026-11-11. Target: World of Warcraft: Forever, `## Interface: 16001`, Blizzard UI 12.1.5.

## Goal

Replace the Blizzard objective tracker with a quest tracker that groups every quest in the quest log by zone,
in the Blizzard tracker's art, fonts and colors. Equivalent to Questie's tracker without the rest of Questie.

## Requirements

1. Every quest in the quest log is shown, independent of the Blizzard watch list and its 25-quest limit.
2. Quests are grouped by zone. The current zone's group is first.
3. Zone groups collapse and expand by clicking the zone header.
4. Individual quests collapse to their title line (Ctrl-click the title).
5. The whole tracker collapses to its top header.
6. Collapse state is session-only. It resets on reload.
7. Quest title is colored by difficulty; objectives show progress; completed quests show no objectives and read
   "<title> (Complete)".
8. Left-click a quest title opens it in the world map quest log.
9. Quests with a usable quest item show a clickable item button, usable in combat.
10. Right-click a quest title opens a context menu: super-track, show on map, stop tracking, share, abandon.
11. "Stop tracking" hides the quest from the tracker. Checking its track box in the quest log shows it again.
12. The entire Blizzard objective tracker is hidden (all modules: quests, campaign, achievements, scenarios,
    world quests, bonus objectives, professions, monthly activities).
13. Position and height are set with Blizzard Edit Mode, by moving the (empty) Blizzard objective tracker and
    its Height setting (shown once the tracker is out of its default position). Width is fixed.

## Out of scope

1. Own position, lock or move code (Edit Mode covers it).
2. Scroll bar or scroll arrows; the mouse wheel scrolls, with no indicator of hidden quests.
3. Locale file: all visible strings are existing Blizzard globals, already translated.
4. Flavor-specific `_Forever.toc`; the plain `.toc` is sufficient.
5. Persisting collapse state.
6. Non-quest tracker content (achievements, scenarios, world quests, ...).

## Architecture

### Hiding the Blizzard tracker

At file load, call `ObjectiveTrackerManager:SetCanAddModules(false)`. `ObjectiveTrackerManager:Init` runs after
`PLAYER_ENTERING_WORLD` and `VARIABLES_LOADED` and adds no modules while the flag is false.
An `ObjectiveTrackerFrame` with no modules hides itself outside Edit Mode and shows (selectable) inside Edit Mode
(`Blizzard_ObjectiveTrackerContainer.lua`, `ObjectiveTrackerContainerMixin:Update`).

The TOC declares `## RequiredDeps: Blizzard_ObjectiveTracker` so the manager exists before the addon loads.

Fallback: if `ObjectiveTrackerManager.SetCanAddModules` is nil, call `ObjectiveTrackerFrame:SetAlpha(0)`.

### Position

The addon frame is parented to `UIParent` and anchored TOPLEFT and TOPRIGHT to `ObjectiveTrackerFrame`.
Edit Mode moves the Blizzard frame; the addon frame follows. Anchoring works while the anchor frame is hidden.
Height is `ObjectiveTrackerFrame:GetHeight()`: zone headers and quests that would end below it are left out,
and nothing after them shows. An `OnSizeChanged` hook on `ObjectiveTrackerFrame` redraws when it changes.

### Files (TOC load order)

1. `QuestZones.toc`: `## Interface: 16001`, `## RequiredDeps: Blizzard_ObjectiveTracker`,
   `## SavedVariablesPerCharacter: QuestZonesCharDB`.
2. `Data.lua`: `ns.BuildZones(hidden, currentZone)`, a pure function over the quest log API. Returns the data model.
3. `ItemButton.lua`: pool of secure quest item buttons; all changes deferred out of combat.
4. `Tracker.lua`: frame, top header, zone headers, quest rows, objective lines, collapse, clicks, context menu.
5. `Core.lua`: event frame, Blizzard tracker suppression, SavedVariables, refresh scheduling.

### Data model

```lua
zones = {
    { name = "Elwynn Forest", quests = {
        { questID = 123, logIndex = 5, title = "...", level = 8, complete = false,
          objectives = { { text = "Boar Pelts: 3/8", finished = false } },
          itemLink = nil },
    } },
}
```

Built by iterating `C_QuestLog.GetNumQuestLogEntries()` and `C_QuestLog.GetInfo(i)`:

1. An entry with `isHeader` starts a new zone named `info.title`.
2. A quest entry is skipped when `isHidden` is true or its `questID` is in `hidden`.
3. `complete` is `C_QuestLog.IsComplete(questID)`.
4. `objectives` is `C_QuestLog.GetQuestObjectives(questID)`.
5. `itemLink` is the first return of `GetQuestLogSpecialItemInfo(logIndex)`.
6. Zones with no remaining quests are dropped.
7. The zone whose `name` equals `currentZone` (`GetRealZoneText()`) moves to index 1; other zones keep log order.

### SavedVariables

`QuestZonesCharDB = { hidden = { [questID] = true } }`, created on `ADDON_LOADED` if absent.

## UI

All textures, fonts and colors are Blizzard's, from `Blizzard_ObjectiveTracker`.

1. Top header: atlas `ui-questtracker-primary-objective-header`, text `TRACKER_HEADER_QUESTS`, collapse button atlases
   `ui-questtrackerbutton-collapse-all` / `-pressed`. Collapses the whole tracker.
2. Zone header: atlas `UI-QuestTracker-Secondary-Objective-Header`, font `ObjectiveTrackerHeaderFont`, collapse
   button atlases `ui-questtrackerbutton-secondary-collapse` / `-pressed`. Collapsed text: `"<zone> (<count>)"`.
   Click toggles collapse.
3. Quest title: font `ObjectiveTrackerLineFont`, color `GetQuestDifficultyColor(level)`.
4. Objective lines: indented, dash prefix, font `ObjectiveTrackerLineFont`, color `OBJECTIVE_TRACKER_COLOR.Normal`
   or `.Complete` when finished.
5. Completed quest: no objective lines; title `<title> (COMPLETE)`, as `QuestInfo.lua` writes it.
6. Item button: 26x26 at the quest row's right edge, normal texture atlas `UI-QuestTrackerButton-QuestItem-Frame`,
   icon from `GetQuestLogSpecialItemInfo`. Template `SecureActionButtonTemplate`, attributes `type = "item"`,
   `item = itemLink`. Tooltip `GameTooltip:SetQuestLogSpecialItem(logIndex)`.

### Quest Timers box

Blizzard's Quest Timers box (`QuestTimerFrame`, Blizzard_QuestTimer, classic clients, `BACKGROUND` strata) stays in
the right-hand managed frame stack. With the tracker moved in Edit Mode it can sit behind the tracker. While it is
shown and overlaps the tracker (horizontally, and vertically within the height limit), the top header and content
start below its bottom edge. Its `OnShow`, `OnHide` and `OnSizeChanged` redraw the tracker. In combat the push waits
for combat to end.

### Scrolling

1. Mouse wheel over the tracker scrolls one step per notch: one quest, or one collapsed zone.
2. An expanded zone's header is drawn above its first quest not scrolled past.
3. Down only while content is cut off at the height limit; up stops at the top. The position is clamped when
   quests disappear.
4. The tracker frame takes the content height (wheel area), set out of combat only. Wheel only: clicks pass through.
5. In combat a scroll is applied after combat (it moves secure item buttons).

### Quest title clicks

1. Shift-click (chat edit box open): `ChatFrameUtil.TryInsertQuestLinkForQuestID(questID)`.
2. Ctrl-click: toggle that quest's collapse.
3. Left-click: `QuestMapFrame_OpenToQuestDetails(questID)`.
4. Right-click: `MenuUtil.CreateContextMenu` with title `C_QuestLog.GetTitleForQuestID(questID)` and entries:
   1. `SUPER_TRACK_QUEST` / `STOP_SUPER_TRACK_QUEST` via `C_SuperTrack.SetSuperTrackedQuestID`.
   2. `OBJECTIVES_SHOW_QUEST_MAP`: `QuestMapFrame_OpenToQuestDetails(questID)`.
   3. `OBJECTIVES_STOP_TRACKING`: add to `hidden`, `C_QuestLog.RemoveQuestWatch(questID)`, refresh.
   4. `SHARE_QUEST`, only if `C_QuestLog.IsPushableQuest(questID) and IsInGroup()`: `QuestUtil.ShareQuest(questID)`.
   5. `ABANDON_QUEST_ABBREV`: `QuestMapQuestOptions_AbandonQuest(questID)`.

## Spoken compatibility

The Spoken addon (Spoken_Quests 3.8.6) puts a Play button on tracked quests by hooking Blizzard's tracker
modules, which QuestZones turns off. `Spoken.lua` mirrors Spoken's tracker adapter
(`Spoken_Quests/Compatibility.lua`) on QuestZones rows:

1. `## OptionalDeps: Spoken, Spoken_Quests` so Spoken loads first when installed.
2. Shown when `Spoken:IsCompatible(1)` and `VoiceOver.QuestOverlayUI:ShowsTrackerButton(questID)` (part on,
   tracker Play setting on, quest voiced). One 14x14 button per row, dressed with `Spoken:DressBoxButton`,
   bound with `QuestOverlayUI:BindPlayButton`, state via `QuestOverlayUI.FollowQueue`.
3. Placed in the right-hand column, below the item button when there is one.
4. Redraw on Spoken callbacks `VOICE_PACKS_LOADED`, `PART_SWITCHED` and on `QuestOverlayUI.UpdateTrackerButtons`.
5. `QuestOverlayUI` is not Spoken's public API: every piece is checked, calls run under `pcall`, and any
   failure means no button.

## Data flow

1. Events schedule a refresh; multiple events in one frame coalesce into one `C_Timer.After(0, ...)` rebuild.
2. Refresh events: `QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ENTERING_WORLD`.
3. `QUEST_WATCH_LIST_CHANGED(questID, added)` with `added == true`: remove `questID` from `hidden` first.
4. `QUEST_REMOVED(questID)`: remove `questID` from `hidden`.
5. Refresh: `ns.BuildZones(...)`, release all pooled frames, lay out top-down from the data model.
6. Frames: reused by index (`list[i] = list[i] or Create()`), extras hidden. Headers reuse Blizzard templates
   `ObjectiveTrackerContainerHeaderTemplate` and `ObjectiveTrackerModuleHeaderTemplate`.

### Combat

Secure item buttons, and frames with secure children, cannot be created, shown, hidden or moved in combat.

1. In combat, a refresh whose quest/row structure (zone order, quest set, collapse, item presence) is unchanged
   updates text and colors in place.
2. In combat, a refresh with structural change sets a pending flag; layout runs on `PLAYER_REGEN_ENABLED`.
3. Collapse clicks in combat are applied after combat.

## Error handling

1. Uncached objectives (empty `GetQuestObjectives` on an incomplete quest): show the title only; the next
   `QUEST_LOG_UPDATE` fills them.
2. Missing `SetCanAddModules`: alpha fallback, no chat output (no non-Blizzard strings).

## Testing

1. `tests/test_data.lua`, run with `lua5.1 tests/test_data.lua` (Arch: `pacman -S lua51`). Stubs `C_QuestLog`
   and `GetQuestLogSpecialItemInfo`, loads `Data.lua`, asserts:
   1. Quests group under their preceding header.
   2. The current zone sorts first; other zones keep log order.
   3. Quests in `hidden` and with `isHidden` are excluded.
   4. Zones left empty are dropped.
2. In-game checklist:
   1. Blizzard tracker hidden in all situations, including after `/reload`.
   2. Edit Mode moves the addon tracker; its Height setting limits how many quests show.
   3. Zone, quest (Ctrl-click) and whole-tracker collapse.
   4. Left-click, Shift-click and every context-menu entry.
   5. Item button usable in combat.
   6. Objective progress updates in combat; quest completion in combat lays out after combat.
   7. Stop tracking hides the quest; checking it in the quest log shows it again.
   8. No `ADDON_ACTION_BLOCKED` or taint errors (`/console taintLog 1`).
   9. With Spoken: voiced quests show Play; it plays, stops and replays; toggling Spoken's tracker Play option
      shows and hides it.
