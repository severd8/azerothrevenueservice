# ARS Forever — developer notes

Gold statistics for **World of Warcraft: Forever** (interface 16001, client 1.60.x, Lua 5.1, the retail-style API): total gold acquired, peak gold and your own gold, plus income, spending, auction, activity and profession statistics, for you and for players you inspect, with saved captures. ARS = Azeroth Revenue Service.

- Author: `severd8`. License: MIT.
- CurseForge project ID: **1766671** (in the `.toc` as `X-Curse-Project-ID`).
- Repo: `severd8/azerothrevenueservice`. Folder and `.toc`: `ARSForever`. Command `/ars` (`/arsforever`).
- Based on **Forever IRS** 0.5.5 by wowplayer95 (MIT; its copyright line is kept in LICENSE). Reused: the statistic list (`A.FIELDS`, 36 achievement-statistic IDs checked by its author against the game's Achievement data for builds 1.60.1.70124 and 1.60.1.70291), number and coin-text reading (`A.Entry`, `A.ParseMoney`), saved-capture cleaning, the request logic (one request, 5 s apart, 15 s wait, queue during the wait, step aside for other addons), the achievement comparison guard, the wording of the disclaimers. Everything shown is new (Theme.lua look instead of Blizzard templates).
- Sister addons: TauntMaster, ToppedOff, Outfitter, BattleText, GatherPath, AuctionHouse Forever.

## Files

- `ARSForever.toc` — `## Version: @project-version@` (the packager fills it from the tag). `SavedVariables: ARSForeverDB` (account-wide: settings and every capture).
- `Theme.lua` — **the shared look, the same file in all seven Forever addons.** Built for ARS by merging all six copies (as of 2026-10-26): BattleText's (`T.List` / `T.OpenList`, the addon's own dropdown list instead of the game's menus) plus AuctionHouse's (`opts.height`, `T.BodyHeight`, `T.WINDOW.H = 556`, the `GatherPathForever` and `AuctionHouseForever` BRANDS rows) plus an `ARSForever` row (logo `Media\Icon`). Change it in one repo, then copy it to the others.
- `Stats.lua` — no frames: `A.FIELDS` (`{ key, statistic ID, label, is money, is a profession's highest rank }`), `A.Number`/`A.Plain`/`A.IsSecret`, money (`A.Money`, `A.Coins`, `A.ParseMoney`), `A.Entry`, `A.REASONS`/`A.Reason`/`A.MissingWord`/`A.Value`/`A.Numeric`, `A.Gap`, `A.SourceStatus`, `A.CheckCapture`, `A.Read` (one capture), `A.Professions`, `A.Assess` (a plain count, no grading), `A.Report` (the copy text).
- `Core.lua` — settings (`A.DEFAULTS`, `A.RANGES`, `A.SORT_KEYS`, `A.RESTORE_KEYS`, `A.KEPT_KEYS`, `LoadSettings`), saved history (`CleanSnapshot`, `MergeCharacters`, `Save`, `History`, `DirectoryRows`, `SortDirectory`, `ClearHistory`), the Forever IRS import (`IRSData`, `ImportIRS`), `RunOutOfCombat`, requests (`Subject`, `Audit`, `Finish`, `Cancel`, `Release`, `VerificationView`, `Refresh`, `OpenSaved`, `OpenDirectory`), the hooks (`InstallComparisonHooks`, `InstallAchievementGuard`, `HookInspect`), the minimap button, `/ars` (`Command`, `Status`, `Check`), events and the once-a-second OnUpdate.
- `Ledger.lua` — the ledger window (`A:ShowLedger(origin)`, `A:Render()`, `A:FitLedger()`, `A:RefreshAge()`), the report window (`A:OpenReport()`). `A.ledgerUI` keeps the widgets the tests use.
- `News.lua` — "What's new" lines, newest first. **Add an entry with every release**; its top version must match the top `## X.Y.Z` of `CHANGELOG.md` (a test checks).
- `Options.lua` — the options window (`T.Window`, tabs `general` and `data`), `A:Confirm`, `A:RefreshOptions`. `A.optionsUI` keeps the controls; each has `.tip`.
- `Splash.lua` — the welcome / what's new window, once per new `News.lua` version (`lastSeenVersion`), unless `showSplash` is off.
- `Media/Icon.tga` — 128×128, 32-bit, uncompressed, bottom-up, alpha (header type 2, 32 bits, descriptor 8, the same as TauntMaster's `logo.tga`). The one logo, used everywhere through `Theme.LOGO`. Sources in `art/` (not shipped): `icon.svg` (the medallion: coin stacks under a magnifying glass in a gold ring, picked from four options as "A"), `logo.svg` (the medallion in a framed square with "ARS FOREVER" on a red banner), `logo.png` (1024×1024 from `logo.svg`, the CurseForge icon). Rendered with Playwright Chromium, converted with Pillow.
- `tests/` — `wowstub.lua`, `run_tests.lua`, `run.lua`, `render.lua`, `render.py`.

## The ledger window

560 × 540 (option "C" of four layouts: compact, tabs along the top, long notes in hover help). Header 56 (logo, name in class colour, level/class/guild/realm; Options, X, the "With Inspect" switch), tabs 28 (Ledger, Activity, History, Characters), content, a status line with the capture's age at its right, the source line, footer 40 (My character, Target, Refresh | Copy report, Save). When a read fails, a red strip (50) goes under the tabs and the window grows by 50. Ledger/Activity/History share the top block (three cards, the activity line, peak minus acquired with its bar, the disclaimer); the lower block changes. Characters: search box, six sortable column headers, 11 rows, `<`/`>` pages. Size: `db.scale` (0.6–1.6), never bigger than the screen.

Opening from the Inspect window always anchors beside it (`TOPLEFT` to `InspectFrame`'s `TOPRIGHT`, +12); otherwise the dragged position (`db.position`) or the middle.

## Saved data

```
ARSForeverDB = { schema = 1, autoInspect, inspectButton, minimapButton, minimapAngle, showSplash, scale,
    directorySort = { key, descending }, position = { point, relative, x, y }, lastSeenVersion, importedIRS,
    characters = { ["Player-..."] = { firstSeen, lastSeen, name, snapshots = { oldest ... newest (max 20) } } } }
snapshot = { guid, name, realm, class, classFile, level, guild, at (server time), build ("1.60.1.70532"), own,
    wallet (own only), values = { [key] = { number = n } or { display = text } }, unavailable = { [key] = reason }, available }
```

- Same shape as Forever IRS's `ForeverIRSDB.characters` plus `classFile` (for class colours), so its captures merge as they are.
- Loading checks everything: a wrong type goes back to its default, numbers are clamped (`A.RANGES`), a sort key not in `A.SORT_KEYS` goes back, a bad position is dropped, captures are cleaned field by field (`CleanSnapshot`: a time saved as text is read as a number, old coin text is read again, junk is dropped), at most 20 per character, one per time + build.
- A `schema` newer than ours: used for the session, `ARSForeverDB` is not replaced (`A.sessionOnly`).
- Restore defaults resets `A.RESTORE_KEYS`; `A.KEPT_KEYS` lists what it keeps (minimap button place, sort order). A test fails if a new default is in neither.

## Forever IRS import

The game only loads `ForeverIRSDB` while Forever IRS is enabled. At `PLAYER_LOGIN`, if it's there and `db.importedIRS` isn't set, `ImportIRS(true)` merges it (`MergeCharacters`: same cleaning, no doubles by time + build, earliest `firstSeen`) and prints a line. The Saved data tab's button (greyed out without the data) and `/ars import` do it again on request.

## Requests (from Forever IRS)

- Yourself: `GetStatistic(id)` at once, plus `GetMoney()`.
- Others: `SetAchievementComparisonUnit(unit)`, then `INSPECT_ACHIEVEMENT_READY` with their GUID, then `GetComparisonStatistic(id)`, then `ClearAchievementComparisonUnit()`. One at a time, `A.REQUEST_GAP` 5 s apart (a request during the wait is queued and sent by the OnUpdate), `A.REQUEST_WAIT` 15 s, never resent by itself. Re-checked when sent: same GUID, out of combat, `CanInspect(unit, false)`, the game's comparison window not open.
- `hooksecurefunc` on `SetAchievementComparisonUnit` / `ClearAchievementComparisonUnit` notices another addon's request: we step aside (5 s wait, the pending request is cancelled).
- The achievement guard (Forever IRS 0.5.2): `AchievementFrameComparison` listens for `INSPECT_ACHIEVEMENT_READY` even while hidden, and an answer meant for us made the game's Summary page error (`GetCategoryNumAchievements`). It is made to listen only while shown, with `HookScript("OnShow"/"OnHide")` and `RegisterEvent`/`UnregisterEvent` on it. Its scripts are untouched.
- These four functions and `GetAchievementInfo`/`GetGuildInfo` aren't in Forever's generated API docs (old globals the game's own achievement UI calls); everything is `type(...) == "function"` checked and in `pcall`.

## Forever API notes

- Checked in `Blizzard_APIDocumentationGenerated` (forever branch, build 1.60.1.70532): `UnitGUID`, `UnitFullName`, `UnitClass` are `SecretWhenUnitIdentityRestricted`; `UnitIsUnit` is `SecretWhenUnitComparisonRestricted`; `UnitName` `SecretWhenUnitNameIdentityRestricted`. `UnitExists`, `UnitIsPlayer`, `UnitLevel`, `CanInspect`, `GetMoney`, `GetServerTime`, `C_AchievementInfo.IsValidAchievement` have no secret flags.
- `A:Subject` checks `IsSecret` before any test on these and gives up with "hidden" (Forever IRS truth-tested `UnitGUID` and string-handled the name, which errors where identity is hidden). "Is this me" compares GUIDs instead of `UnitIsUnit`. The event's GUID, `CanInspect`'s answer and every statistic value are checked the same way. **The stub can't catch a truth-test on a secret; these were reviewed by hand.**
- The current client is 1.60.1.70532, newer than the builds Forever IRS checked. `A.SourceStatus` only adds a note for that (in hover help and the report); a red warning is kept for another game or missing functions. `/ars check` lists each ID with `GetAchievementInfo(id)`'s name so the list can be checked in game.
- Inspect: Blizzard_InspectUI loads on demand (`ADDON_LOADED` "Blizzard_InspectUI" → `HookInspect`). `InspectFrame:HookScript("OnShow")` plus `hooksecurefunc("InspectFrame_Show")` (Forever's Camelot `InspectFrame_Show(unit)` sets `InspectFrame.unit`; inspecting someone else while it's open doesn't fire OnShow again, which Forever IRS missed). We never open or close the Inspect window. The ARS button is a `T.FlatButton` under it.
- No secure frames, nothing protected; `RunOutOfCombat` is there for anything that ever needs it. Requests are refused in combat.

## Fixes over Forever IRS 0.5.5

Found by reading its code (its CurseForge comments and issues weren't reachable from here):
1. Errors where the game hides identity (secret `UnitGUID`/names truth-tested).
2. Once the window had been dragged, it never opened beside Inspect again (saved position won).
3. A second inspect while the Inspect window was open wasn't read.
4. The copy report's box was a fixed 800 px tall, so long reports were cut off.
5. Every capture after a game update showed a red "WARNING" source line.
6. A skull level (-1) was shown live but dropped on reload; now "??" both ways.

## Tests

`lua5.1 tests/run.lua` (GitHub Actions runs it on every push and before every release). `tests/wowstub.lua` fakes the game as Forever has it: no `GetPetHappiness`, `GetSpecialization`, `IsPlayerSpell`, `GetCoinTextureString`; frames take any method name (capitalised) but a field never set reads nil, and the methods the addon adds itself (`ADDON_METHODS`) read nil unless added; OnUpdate only on shown frames; `Show` on a hidden frame runs OnShow; secrets (`Secret(v)`, `SECRET_MODE`) error on comparison, maths, joining and indexing, and passing one to a method other than `SetText`/`SetValue`/... errors; `BLOCKED` records protected calls in combat. Fake units (`UNITS`, `SetTarget`), statistics (`STAT_NAMES`, `STATS_SELF`, `STATS_OTHER`, `STAT_SKIP`), requests (`REQUESTS`, `Answer`), the Inspect window (`LoadInspectUI`), time (`Wait`, `Tick`), `C_Timer.After` (`RunTimers`).

Scenarios: loading, broken and newer saved settings, Restore defaults coverage, your own and another player's capture, request spacing, timeout and late answers, target changes, another addon's request, combat, reload in combat, hidden identity and hidden values, skipped/unknown statistics, number reading, build notes, the Inspect window (beside it after moving, second inspect, switch off, ARS button), the comparison guard, 20-capture limit, Characters tab (sorting, missing last, search, pages, row click), saved captures and Refresh, tabs and History, the report, the Forever IRS import (once, no doubles), options controls (hover help, each works), Restore defaults and Delete history confirms, the minimap button, the welcome window, every slash command, `/ars check`, News vs CHANGELOG, the `.toc`, no Blizzard templates or direct `print`, only Forever's API, no banned words in any file. Every chat line must start with `Theme.CHAT_PREFIX`.

Mutation checks (1.0.0, each broke a test, then restored): no second-inspect hook; saved position winning over Inspect; no hidden-GUID guard; 800 px report box; import at every login; no request spacing; missing values sorting first.

Render check: `lua5.1 tests/render.lua out.json && python3 tests/render.py out.json outdir` draws the ledger (each tab, yourself, an error), the report, both options tabs and the welcome window as PNGs (an approximation: plain colours, no real textures). Look before any layout commit.

## Not yet seen in game

Everything (first release). Worth checking first:
1. `/ars me`: the numbers match the game's Statistics page (Character → Achievements → Statistics → Wealth).
2. Inspect a nearby player: the ledger opens beside the Inspect window and fills in; the ARS button sits under the Inspect window.
3. With the Inspect window open, inspect a second player: the ledger switches to them.
4. Drag the ledger, close it, inspect someone: it opens beside Inspect again.
5. `/ars check`: every ID found (green), none red; note any orange (renamed).
6. Forever IRS on + ARS on, log in: the chat line says how many characters came in; the Characters tab lists them.
7. The window's fit: text not clipped in the cards (big gold amounts), the Characters columns, the History columns.
8. Hover help on the cards, rows, the activity line and the source line.
9. Inside a dungeon, target a party member and `/ars`: either it works or it says the game is hiding them (no Lua error).
10. The minimap button: left-click, right-click, drag.
11. The welcome window on first login.
12. The ledger's size slider; `/ars reset`.

## Releasing

1. Tests green. New top section `## X.Y.Z` in `CHANGELOG.md` (for players), the matching top entry in `News.lua`, technical notes here.
2. Commit and push to `main`.
3. The version tag (`vX.Y.Z`) is made in GitHub Desktop on that commit and pushed once; it uploads to CurseForge through the **Package and release** workflow (needs the `CF_API_KEY` secret).
