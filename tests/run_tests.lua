-- ARS Forever test scenarios. Run with: lua5.1 tests/run.lua

RESULTS = {}
local A, T, ns

local G = 10000
local BASE_STATS = { acquired = 48213 * G + 512, peak = 9120 * G, looted = 6021 * G, quests = 3410 * G, vendors = 5230 * G,
    auctions = 30122 * G, daily = 312 * G, travel = 410 * G, postage = 12 * G, barber = 0, respec = 85 * G,
    posted = 1840, purchases = 512, largestSale = 1200 * G, largestBid = 450 * G, questCount = 812, kills = 23412,
    dungeons = 214, deaths = 96, disenchanted = 1420, disenchantMaterials = 2611, fishCaught = 340, flights = 602,
    honorableKills = 1210, firstAid = 300, cooking = 285, fishing = 150, enchanting = 300, tailoring = 300 }
local OTHER = { guid = "Player-1-00000002", name = "Goldbeard", realm = "Forever", class = "Warrior", classFile = "WARRIOR",
    level = 60, guild = "Iron Vault", player = true }
local THIRD = { guid = "Player-1-00000003", name = "Coinpurse", realm = "Forever", class = "Priest", classFile = "PRIEST",
    level = 58, player = true }

local function Stats(t)
    local out = {}
    for _, f in ipairs(A.FIELDS) do out[f[2]] = t[f[1]] end
    return out
end

-- A clean game with the addon loaded and logged in
local function Fresh(opts)
    opts = opts or {}
    dofile("tests/wowstub.lua")
    ARSForeverDB = opts.db
    ForeverIRSDB = opts.irs
    COMBAT = opts.combat or false
    ns = LoadAddon(".")
    A, T = ns.ARS, ns.Theme
    for _, f in ipairs(A.FIELDS) do STAT_NAMES[f[2]] = f[3] end
    STATS_SELF = Stats(BASE_STATS)
    STATS_OTHER[OTHER.guid] = Stats({ acquired = 152003 * G, peak = 61000 * G, auctions = 140210 * G, posted = 9100,
        questCount = 120, kills = 3010, mining = 300 })
    STATS_OTHER[THIRD.guid] = Stats({ acquired = 21000 * G, peak = 4800 * G })
    FireEvent("ADDON_LOADED", "ARSForever")
    FireEvent("PLAYER_LOGIN")
    return A
end

local function Fail(msg, level) error(msg, (level or 1) + 1) end
local function eq(a, b, msg) if a ~= b then Fail((msg or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function yes(v, msg) if not v then Fail(msg or "expected true", 2) end end
local function no(v, msg) if v then Fail(msg or "expected false", 2) end end
local function LogHas(text)
    for _, l in ipairs(LOG) do if l:find(text, 1, true) then return true end end
    return false
end

local function Test(name, fn)
    fn()
    -- Every chat line starts with the logo and the full name
    if T then
        for _, l in ipairs(LOG) do
            if l:sub(1, #T.CHAT_PREFIX) ~= T.CHAT_PREFIX then Fail(name .. ": chat line without the prefix: " .. l) end
        end
    end
    eq(#(BLOCKED or {}), 0, name .. ": protected action in combat")
    RESULTS[#RESULTS + 1] = "PASS  " .. name
end

local function ReadFile(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

---------------------------------------------------------------------------
-- Loading and settings
---------------------------------------------------------------------------
Test("loads and logs in", function()
    Fresh()
    yes(A.db, "settings loaded")
    eq(ARSForeverDB, A.db, "saved table in use")
    yes(A.minimapButton, "minimap button")
    eq(T.NAME, "ARS Forever")
    yes(T.CHAT_PREFIX:find("ARS Forever", 1, true), "chat prefix has the full name")
    yes(T.LOGO:find("ARSForever\\Media\\Icon", 1, true), "logo path")
end)

Test("broken saved settings go back to their defaults", function()
    Fresh({ db = { autoInspect = "yes", scale = "big", minimapAngle = 9999, showSplash = 1,
        directorySort = { key = "bogus", descending = true }, position = { point = "NOPE", relative = "CENTER", x = 1, y = 1 },
        characters = { ["not a guid"] = { snapshots = {} } } } })
    eq(A.db.autoInspect, true)
    eq(A.db.scale, 1)
    eq(A.db.minimapAngle, 360, "angle clamped")
    eq(A.db.showSplash, true)
    eq(A.db.directorySort.key, "peak")
    eq(A.db.position, nil)
    eq(next(A.db.characters), nil, "bad character dropped")
    Fresh({ db = { scale = 5, minimapAngle = 0 / 0 } })
    eq(A.db.scale, 1.6, "scale clamped")
    eq(A.db.minimapAngle, 210, "NaN back to default")
end)

Test("a newer saved format is used but never written over", function()
    local saved = { schema = 99, autoInspect = false, characters = {} }
    Fresh({ db = saved })
    yes(A.sessionOnly, "session only")
    eq(ARSForeverDB, saved, "saved table left alone")
    eq(A.db.autoInspect, false)
end)

Test("defaults: Restore defaults resets each, or it's listed as kept", function()
    Fresh()
    local restore = {}
    for _, k in ipairs(A.RESTORE_KEYS) do restore[k] = true end
    for k in pairs(A.DEFAULTS) do
        yes(restore[k] or A.KEPT_KEYS[k], "default '" .. k .. "' is neither restored nor listed as kept")
    end
end)

---------------------------------------------------------------------------
-- Reading statistics
---------------------------------------------------------------------------
Test("your own ledger: every statistic, your gold, saved", function()
    Fresh()
    A:Audit("player")
    local s = A.snapshot
    yes(s and s.own, "own capture")
    eq(A.Numeric(s, "acquired"), BASE_STATS.acquired)
    eq(s.wallet, MONEY)
    eq(#A:History(s.guid), 1, "saved")
    yes(A.ledger:IsShown(), "ledger shown")
    eq(A.Value(s, "barber"), A.Money(0), "a real zero stays zero")
    eq(A.Value(s, "alchemy"), "Not reported", "missing is not zero")
    eq(#REQUESTS, 0, "no inspect request for yourself")
end)

Test("another player: one request, their numbers, no gold shown", function()
    Fresh()
    SetTarget(OTHER)
    A:Audit("target")
    eq(#REQUESTS, 1)
    yes(A.pending, "waiting for the answer")
    Answer("target")
    local s = A.snapshot
    yes(s and not s.own, "their capture")
    eq(A.Numeric(s, "acquired"), 152003 * G)
    eq(s.wallet, nil, "no wallet for others")
    eq(A.ledgerUI.cards.wallet:GetText(), "--")
    eq(COMPARING, nil, "comparison released")
    eq(#A:History(OTHER.guid), 1)
end)

Test("requests are spaced 5 seconds apart, queued ones go by themselves", function()
    Fresh()
    SetTarget(OTHER)
    A:Audit("target")
    Answer("target")
    A:Refresh()
    eq(#REQUESTS, 1, "second request waits")
    yes(A.pending and A.pending.queuedUntil, "queued")
    Wait(6)
    eq(#REQUESTS, 2, "sent when the wait ended")
    Answer("target")
    eq(A.pending, nil)
end)

Test("no answer in 15 seconds gives up, nothing sent again", function()
    Fresh()
    SetTarget(OTHER)
    A:Audit("target")
    Wait(16)
    eq(A.pending, nil)
    eq(A.verification.state, "failed")
    yes(A.status:find("No answer", 1, true), "says so")
    eq(#REQUESTS, 1, "no retry")
    -- a late answer changes nothing
    Answer("target")
    eq(#A:History(OTHER.guid), 0)
end)

Test("changing target cancels; another addon taking the request steps aside", function()
    Fresh()
    SetTarget(OTHER)
    A:Audit("target")
    SetTarget(THIRD)
    FireEvent("PLAYER_TARGET_CHANGED")
    eq(A.pending, nil, "cancelled")
    Wait(6)
    SetTarget(OTHER)
    A:Audit("target")
    SetAchievementComparisonUnit("player")   -- someone else's request
    eq(A.pending, nil, "stepped aside")
    yes(A.status:find("Another addon", 1, true))
end)

Test("in combat: nothing is requested", function()
    Fresh()
    SetTarget(OTHER)
    COMBAT = true
    A:Audit("target")
    eq(#REQUESTS, 0)
    yes(A.status:find("combat", 1, true))
    COMBAT = false
end)

Test("reload in combat: login works with combat on", function()
    Fresh({ combat = true })
    yes(A.db and A.minimapButton, "loaded")
    A:Command("")
    COMBAT = false
    FireEvent("PLAYER_REGEN_ENABLED")
end)

Test("hidden identity: no errors, a plain message", function()
    Fresh()
    SetTarget(OTHER)
    SECRET_MODE = true
    A:Audit("target")
    eq(#REQUESTS, 0)
    yes(A.status:find("hiding", 1, true), "explains")
    A:Audit("player")
    A:Command("status")
    SECRET_MODE = false
    -- hidden statistic values are left out, not errors
    STATS_SELF[328] = Secret(5)
    STAT_SKIP[334] = Secret(true)
    A:Audit("player")
    eq(A.snapshot.unavailable.acquired, "unreadable")
    eq(A.snapshot.unavailable.peak, "unreadable")
    A:OpenReport()
end)

Test("skipped and unknown statistics are reported, not zero", function()
    Fresh()
    STAT_SKIP[333] = true
    STAT_NAMES[921] = nil
    A:Audit("player")
    eq(A.snapshot.unavailable.looted, "skipped")
    eq(A.snapshot.unavailable.vendors, "unsupported")
    eq(A.Value(A.snapshot, "looted"), "Unavailable")
end)

Test("numbers: coin text, grouped digits, gap", function()
    Fresh()
    eq(A.ParseMoney("12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t 3|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"), 120300)
    eq(A.ParseMoney("3|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t 12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"), nil, "wrong order")
    eq(A.Entry("1,234").number, 1234)
    eq(A.Entry("1,23").number, nil, "a broken digit group is never a number")
    eq(A.Entry(""), nil, "no digits: nothing")
    eq(A.Entry("12 copper-ish").display ~= nil, true, "unknown text kept as text")
    local s = { values = { acquired = { number = 100 }, peak = { number = 300 } } }
    local gap, ratio = A.Gap(s)
    eq(gap, 200)
    eq(ratio, 100 / 300)
    eq(A.Gap({ values = { peak = { number = 5 } } }), nil, "needs both")
    eq(A.Coins(nil), "--")
end)

Test("an unchecked game build is a note, not a red warning", function()
    Fresh()
    local st = A.SourceStatus(nil)
    eq(st.reason, nil)
    yes(st.note, "note")
    BUILD_NUMBER = "70291"
    eq(A.SourceStatus(nil).note, nil)
    BUILD_VERSION = "2.5.4"
    yes(A.SourceStatus(nil).reason, "another game is a warning")
    BUILD_VERSION, BUILD_NUMBER = nil, nil
end)

---------------------------------------------------------------------------
-- The Inspect window
---------------------------------------------------------------------------
Test("inspect: opens beside it, even after the ledger was moved", function()
    Fresh({ db = { position = { point = "TOPLEFT", relative = "TOPLEFT", x = 50, y = -50 } } })
    LoadInspectUI()
    yes(A.inspectButton, "ARS button added")
    SetTarget(OTHER)
    InspectFrame_Show("target")
    eq(#REQUESTS, 1, "one request")
    yes(A.ledger:IsShown())
    local p = A.ledger.__points[#A.ledger.__points]
    eq(p[2], InspectFrame, "anchored beside Inspect")
    Answer("target")
    -- a second player while it's open
    SetTarget(THIRD)
    InspectFrame_Show("target")
    Wait(6)
    eq(#REQUESTS, 2, "second inspect read too")
    Answer("target")
    eq(A.snapshot.guid, THIRD.guid)
    InspectFrame:Hide()
    no(A.ledger:IsShown(), "closes with Inspect")
end)

Test("inspect with the switch off: nothing happens", function()
    Fresh()
    LoadInspectUI()
    A.db.autoInspect = false
    SetTarget(OTHER)
    InspectFrame_Show("target")
    eq(#REQUESTS, 0)
    Click(A.inspectButton)
    eq(#REQUESTS, 1, "the ARS button still works")
    A.db.inspectButton = false
    A:Changed()
    no(A.inspectButton:IsShown(), "button hidden")
end)

Test("the game's comparison panel only listens while shown", function()
    Fresh()
    AchievementFrameComparison = NewObj("Frame", "AchievementFrameComparison", UIParent)
    AchievementFrameComparison.__shown = false
    AchievementFrameComparison:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    A:Audit("player")
    no(AchievementFrameComparison:IsEventRegistered("INSPECT_ACHIEVEMENT_READY"), "off while hidden")
    AchievementFrameComparison:Show()
    yes(AchievementFrameComparison:IsEventRegistered("INSPECT_ACHIEVEMENT_READY"), "on while shown")
end)

---------------------------------------------------------------------------
-- Saved history and the Characters tab
---------------------------------------------------------------------------
local function Save(guid, name, at, acq, peak, level)
    local values = {}
    if acq then values.acquired = { number = acq } end
    if peak then values.peak = { number = peak } end
    return A:Save({ guid = guid, name = name, realm = "Forever", class = "Mage", level = level, at = at,
        build = "1.60.1.70532", values = values, unavailable = {}, available = (acq and 1 or 0) + (peak and 1 or 0) })
end

Test("20 captures kept per character, no doubles", function()
    Fresh()
    for i = 1, 25 do Save("Player-1-0000000A", "Alt", 1000 + i, i, i) end
    local h = A:History("Player-1-0000000A")
    eq(#h, 20)
    eq(h[1].at, 1006, "oldest dropped")
    no(Save("Player-1-0000000A", "Alt", 1025, 1, 1), "same capture again")
    no(A:Save({ guid = "Player-1-0000000B", values = {}, available = 0, at = 5, build = "x" }), "nothing in it")
end)

Test("Characters tab: sorting, missing last, search, pages", function()
    Fresh()
    Save("Player-1-0000000A", "Alpha", 100, 500, 300, 10)
    Save("Player-1-0000000B", "Bravo", 100, 100, 900, 20)
    Save("Player-1-0000000C", "Charlie", 100, 50, nil, 30)
    local rows = A:DirectoryRows("")
    eq(rows[1].snapshot.name, "Bravo", "highest peak first")
    eq(rows[3].snapshot.name, "Charlie", "missing last")
    rows = A:DirectoryRows("", "peak", false)
    eq(rows[1].snapshot.name, "Alpha")
    eq(rows[3].snapshot.name, "Charlie", "missing last either way")
    A:SortDirectory("name")
    eq(A.db.directorySort.descending, false, "name starts A to Z")
    A:SortDirectory("name")
    eq(A.db.directorySort.descending, true, "click again reverses")
    eq(#A:DirectoryRows("brav"), 1, "search")
    -- the window
    for i = 1, 30 do Save(("Player-1-1%07d"):format(i), "Alt" .. i, 200, i, i) end
    A:OpenDirectory()
    local d = A.ledgerUI.directory
    yes(d:IsShown(), "Characters tab shown")
    yes(d.prev.disabled, "no page before")
    no(d.next.disabled, "a page after")
    Click(d.next)
    eq(A.directoryPage, 1)
    Type(d.search, "alt1")
    eq(A.directoryPage, 0, "search goes back to page 1")
    Click(d.headers.level)
    eq(A.db.directorySort.key, "level")
    Click(d.rows[1])
    yes(A.savedView, "row opens the saved capture")
end)

Test("opening a saved capture doesn't read anyone; refresh needs them nearby", function()
    Fresh()
    SetTarget(OTHER)
    A:Audit("target")
    Answer("target")
    SetTarget(nil)
    Wait(6)
    A:OpenSaved(OTHER.guid)
    eq(#REQUESTS, 1)
    A:Refresh()
    eq(#REQUESTS, 1, "not nearby: nothing sent")
    yes(A.status:find("Target this player", 1, true))
    SetTarget(OTHER)
    A:Refresh()
    eq(#REQUESTS, 2)
end)

Test("tabs and the history tab", function()
    Fresh()
    for i = 1, 12 do Save(UNITS.player.guid, "Visadrix", 1000 + i * 100, i * 10, 5) end
    A:Audit("player")
    local ui = A.ledgerUI
    Click(ui.tabs.activity)
    yes(ui.activity:IsShown())
    Click(ui.tabs.history)
    yes(ui.history:IsShown())
    eq(ui.history.rows[2].delta:GetText(), "+ " .. A.Coins(10), "increase between captures")
    Click(ui.history.next)
    eq(A.historyPage, 1)
    Click(ui.tabs.ledger)
    yes(ui.body:IsShown())
    Click(ui.save)
    Click(ui.copy)
    yes(A.reportWindow:IsShown())
end)

Test("the report: disclaimers, every statistic, tall enough", function()
    Fresh()
    A:Audit("player")
    A:OpenReport()
    local text = A.reportWindow.edit:GetText()
    yes(text:find("not proof of innocence or wrongdoing", 1, true))
    yes(text:find("A DIFFERENCE DOES NOT NECESSARILY INDICATE WRONGDOING", 1, true))
    for _, f in ipairs(A.FIELDS) do yes(text:find(f[3], 1, true), "report has " .. f[3]) end
    local lines = 1
    for _ in text:gmatch("\n") do lines = lines + 1 end
    yes(A.reportWindow.edit:GetHeight() >= lines * 14, "box tall enough for every line")
end)

---------------------------------------------------------------------------
-- Forever IRS's saved history
---------------------------------------------------------------------------
local IRS = { version = 3, autoInspect = true, characters = {
    ["Player-1-0000000A"] = { firstSeen = 500, snapshots = {
        { at = 600, build = "1.60.1.70291", name = "Oldtimer", realm = "Forever", class = "Rogue", level = 60,
            values = { acquired = { number = 777 }, peak = { display = "12||TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0||t" } } },
        { at = "700", build = "1.60.1.70291", name = "Oldtimer", values = { acquired = { number = 800 } } },
        { at = 800, build = "1.60.1.70291", name = "Oldtimer", values = {} },
    } },
    ["bogus"] = { snapshots = { { at = 1, values = { acquired = { number = 1 } } } } },
} }

Test("Forever IRS history comes in at login, once, without doubles", function()
    Fresh({ irs = IRS })
    local h = A:History("Player-1-0000000A")
    eq(#h, 2, "usable captures (a time saved as text is kept), the empty one dropped")
    eq(A.Numeric(h[1], "peak"), 120000, "old coin text read")
    eq(A.db.characters["Player-1-0000000A"].firstSeen, 500)
    eq(A.db.characters.bogus, nil)
    yes(A.db.importedIRS)
    yes(LogHas("imported 1 new character"))
    local ok, chars, snaps = A:ImportIRS()
    yes(ok)
    eq(chars, 0)
    eq(snaps, 0, "nothing doubled")
    -- next login with Forever IRS still on: not again by itself
    Fresh({ irs = IRS, db = ARSForeverDB })
    no(LogHas("imported"), "not again at login")
end)

Test("without Forever IRS: the import button is greyed out", function()
    Fresh()
    A:OpenOptions("data")
    yes(A.optionsUI.import.disabled)
    no(A:ImportIRS(), "nothing to import")
    yes(LogHas("Enable Forever IRS"))
end)

---------------------------------------------------------------------------
-- Options, minimap button, welcome window, slash commands
---------------------------------------------------------------------------
Test("every options control has hover help and works", function()
    Fresh()
    A:OpenOptions()
    local ui = A.optionsUI
    for key, c in pairs(ui) do
        if c.__kind ~= "FontString" then
            yes(c.tip and c.__scripts.OnEnter, "hover help on " .. key)
        end
    end
    for _, key in ipairs({ "autoInspect", "inspectButton", "minimapButton", "showSplash" }) do
        local was = A.db[key]
        Click(ui[key])
        eq(A.db[key], not was, key .. " switches")
        Click(ui[key])
        eq(A.db[key], was)
    end
    Click(ui.minimapButton)
    no(A.minimapButton:IsShown(), "minimap button hidden at once")
    Click(ui.minimapButton)
    ui.scale:SetValue(120)
    eq(A.db.scale, 1.2, "size applies")
    Click(ui.moveLedger)
    A.options:ShowTab("data")
    Click(ui.openList)
    yes(A.directoryMode)
    Click(ui.check)
    Click(ui.status)
end)

Test("Restore defaults asks first, then resets", function()
    Fresh()
    A:OpenOptions()
    A.db.autoInspect, A.db.scale, A.db.minimapAngle = false, 1.4, 99
    Save("Player-1-0000000A", "Alpha", 100, 500, 300)
    Click(A.optionsUI.restore)
    eq(A.db.autoInspect, false, "not before the confirm")
    yes(A.confirmWindow:IsShown())
    Click(A.confirmWindow.yes)
    eq(A.db.autoInspect, true)
    eq(A.db.scale, 1)
    eq(A.db.minimapAngle, 99, "kept")
    eq(#A:History("Player-1-0000000A"), 1, "history kept")
end)

Test("Delete saved history asks first", function()
    Fresh()
    Save("Player-1-0000000A", "Alpha", 100, 500, 300)
    A:OpenOptions("data")
    no(A.optionsUI.clear.disabled)
    Click(A.optionsUI.clear)
    eq(#A:History("Player-1-0000000A"), 1)
    Click(A.confirmWindow.yes)
    eq(next(A.db.characters), nil)
end)

Test("minimap button: left opens the ledger, right the options", function()
    Fresh()
    Click(A.minimapButton, "LeftButton")
    yes(A.ledger:IsShown())
    Click(A.minimapButton, "LeftButton")
    no(A.ledger:IsShown(), "toggles")
    Click(A.minimapButton, "RightButton")
    yes(A.options:IsShown())
end)

Test("welcome window: once per version", function()
    Fresh()
    RunTimers()
    yes(A.splash and A.splash:IsShown(), "shown on first login")
    eq(A.db.lastSeenVersion, A.NEWS[1].version)
    Click(A.splash.check)
    eq(A.db.showSplash, false)
    Fresh({ db = { lastSeenVersion = "0.9.0", showSplash = false } })
    RunTimers()
    eq(A.splash, nil, "off: not shown")
    Fresh({ db = { lastSeenVersion = A.NEWS[1].version } })
    RunTimers()
    eq(A.splash, nil, "already seen")
end)

Test("every slash command runs", function()
    Fresh()
    SetTarget(OTHER)
    for _, c in ipairs({ "", "me", "target", "refresh", "verify", "history", "list", "status", "check", "options",
        "config", "news", "import", "close", "auto off", "auto on", "reset", "scale 1.2", "scale 9", "scale reset",
        "scale", "help", "bogus" }) do
        SlashCmdList.ARSFOREVER(c)
    end
    eq(A.db.scale, 1, "scale reset")
    yes(LogHas("/ars history"), "help lists commands")
end)

Test("/ars check lists every statistic and flags missing or renamed ones", function()
    Fresh()
    STAT_NAMES[328] = "Gold total"
    STAT_NAMES[334] = nil
    local missing, different = A:Check()
    eq(missing, 1)
    eq(different, 1)
    yes(LogHas("328 Total gold acquired"))
end)

---------------------------------------------------------------------------
-- The files themselves
---------------------------------------------------------------------------
Test("What's new matches the changelog", function()
    Fresh()
    local top = ReadFile("CHANGELOG.md"):match("\n?## (%d+%.%d+%.%d+)")
    eq(A.NEWS[1].version, top)
end)

Test("the .toc: icon, version, files", function()
    local toc = ReadFile("ARSForever.toc")
    yes(toc:find("## IconTexture: Interface\\AddOns\\ARSForever\\Media\\Icon\n", 1, true), "icon")
    yes(toc:find("## Version: @project-version@", 1, true), "version from the tag")
    yes(io.open("Media/Icon.tga", "rb"), "icon file")
    for _, f in ipairs(TOC_FILES) do yes(io.open(f), f .. " exists") end
end)

Test("no Blizzard templates in shipped files", function()
    for _, f in ipairs(TOC_FILES) do
        local src = ReadFile(f)
        for _, t in ipairs({ "UIPanelButtonTemplate", "UICheckButtonTemplate", "UIPanelScrollFrameTemplate",
            "BasicFrameTemplate", "ButtonFrameTemplate", "SearchBoxTemplate", "PanelTabButtonTemplate", "BackdropTemplate",
            "ColumnDisplayButton" }) do
            no(src:find(t, 1, true), f .. " uses " .. t)
        end
        -- chat only through Print (Core.lua's one print call is Print itself)
        local calls = 0
        for _ in src:gmatch("[^%w_.:]print%(") do calls = calls + 1 end
        eq(calls, f == "Core.lua" and 1 or 0, f .. " calls print directly")
    end
end)

Test("only API that Forever has", function()
    Fresh()
    for _, name in ipairs({ "GetPetHappiness", "GetSpecialization", "IsPlayerSpell", "GetCoinTextureString" }) do
        eq(_G[name], nil, name .. " is not in Forever")
    end
end)

Test("no banned words in any tracked file", function()
    local words = { "clau" .. "de", "anth" .. "ropic" }
    local list = io.popen("git ls-files --cached --others --exclude-standard")
    local n = 0
    for path in list:lines() do
        local src = ReadFile(path):lower()
        for _, w in ipairs(words) do no(src:find(w, 1, true), path .. " mentions " .. w) end
        n = n + 1
    end
    list:close()
    yes(n > 0, "files listed")
end)
