-- ARS Forever (Azeroth Revenue Service): gold statistics for you and the
-- players you inspect, with saved snapshots. Settings, saved history, the
-- requests to the game, the Inspect window hooks, the minimap button, /ars and
-- events. The windows are in Ledger.lua, Options.lua and Splash.lua.
-- Based on Forever IRS by wowplayer95 (MIT, see LICENSE).

local ADDON, ns = ...
ns.ARS = ns.ARS or {}
local A = ns.ARS
local T = ns.Theme
local IsSecret = A.IsSecret

local function Print(msg) print(T.CHAT_PREFIX .. ": " .. msg) end
A.Print = Print

A.SCHEMA = 1
A.MAX_SNAPSHOTS = 20
A.REQUEST_GAP = 5      -- seconds between our requests to the game
A.REQUEST_WAIT = 15    -- how long to wait for an answer

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
A.DEFAULTS = {
    autoInspect = true,      -- open beside the Inspect window
    inspectButton = true,    -- the ARS button on the Inspect window
    minimapButton = true,
    minimapAngle = 210,
    showSplash = true,       -- welcome / what's new after updates
    scale = 1,               -- the ledger window's size
    directorySort = { key = "peak", descending = true },
}
A.RANGES = { scale = { 0.6, 1.6 }, minimapAngle = { -360, 360 } }
A.SORT_KEYS = { name = true, level = true, peak = true, acquired = true, lastSeen = true, count = true }
-- What Restore defaults puts back. The rest are kept on purpose (a test checks
-- every default is in one list or the other).
A.RESTORE_KEYS = { "autoInspect", "inspectButton", "minimapButton", "showSplash", "scale" }
A.KEPT_KEYS = { minimapAngle = "where you dragged the minimap button",
    directorySort = "the Characters tab's sort order" }

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x) end
    return t
end
A.Copy = Copy

local ANCHORS = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local function Short(v, limit, fallback)
    if type(v) ~= "string" or #v > limit then return fallback end
    return (v:gsub("%c", " "))
end

local function Timestamp(v)
    local n = A.Number(v)
    if n and n >= 1 and n <= 4102444800 and n % 1 == 0 then return n end
end

-- A saved capture, checked field by field. nil when nothing usable is left.
function A.CleanSnapshot(raw, guid)
    if type(raw) ~= "table" or type(raw.values) ~= "table" then return nil end
    local at = Timestamp(raw.at)
    if not at then return nil end
    local s = { guid = guid, name = Short(raw.name, 128, "Unknown"), realm = Short(raw.realm, 128, ""),
        class = Short(raw.class, 64, ""), classFile = Short(raw.classFile, 32), guild = Short(raw.guild, 256),
        level = A.Number(raw.level), at = at, build = Short(raw.build, 64, "unknown"), own = raw.own == true,
        values = {}, unavailable = {}, available = 0 }
    if s.level and (s.level < 1 or s.level > 1000 or s.level % 1 ~= 0) then s.level = nil end
    if s.own then s.wallet = A.Number(raw.wallet) end
    for _, f in ipairs(A.FIELDS) do
        local key, e = f[1], raw.values[f[1]]
        if type(e) == "table" then
            local n = A.Number(e.number)
            if n ~= nil then
                s.values[key] = { number = n }
            elseif type(e.display) == "string" and #e.display <= 400 then
                -- Forever IRS 0.1 saved coin text; read it again (time unchanged)
                s.values[key] = A.Entry((e.display:gsub("||", "|")), f[4])
            end
        end
        if s.values[key] then
            s.available = s.available + 1
        elseif type(raw.unavailable) == "table" and A.REASONS[raw.unavailable[key]] then
            s.unavailable[key] = raw.unavailable[key]
        end
    end
    if s.available > 0 or s.wallet ~= nil then return s end
end

local function ValidGUID(guid)
    return type(guid) == "string" and #guid <= 128 and guid:match("^Player%-%w[%w%-]*$") ~= nil
end

-- Oldest first, one per time and build, at most MAX_SNAPSHOTS (the newest)
local function Tidy(list)
    table.sort(list, function(a, b) return a.at < b.at or (a.at == b.at and a.build < b.build) end)
    local out = {}
    for _, s in ipairs(list) do
        local last = out[#out]
        if not last or last.at ~= s.at or last.build ~= s.build then out[#out + 1] = s end
    end
    while #out > A.MAX_SNAPSHOTS do table.remove(out, 1) end
    return out
end

-- Adds saved characters (ours or Forever IRS's) into db.characters.
-- Returns how many characters and captures were new.
function A:MergeCharacters(source)
    local chars, snaps = 0, 0
    if type(source) ~= "table" then return 0, 0 end
    for guid, e in pairs(source) do
        if ValidGUID(guid) and type(e) == "table" and type(e.snapshots) == "table" then
            local have = self.db.characters[guid]
            local list, seen = {}, {}
            for _, s in ipairs(have and have.snapshots or {}) do
                list[#list + 1] = s
                seen[s.at .. "|" .. s.build] = true
            end
            local added = 0
            for _, raw in pairs(e.snapshots) do
                local s = A.CleanSnapshot(raw, guid)
                if s and not seen[s.at .. "|" .. s.build] then
                    seen[s.at .. "|" .. s.build] = true
                    list[#list + 1] = s
                    added = added + 1
                end
            end
            list = Tidy(list)
            local last = list[#list]
            if last then
                if not have then chars = chars + 1 end
                snaps = snaps + added
                local first = Timestamp(e.firstSeen) or list[1].at
                if have and have.firstSeen then first = math.min(first, have.firstSeen) end
                self.db.characters[guid] = { snapshots = list, name = last.name, lastSeen = last.at,
                    firstSeen = math.min(first, list[1].at) }
            end
        end
    end
    return chars, snaps
end

function A:LoadSettings()
    local old = type(ARSForeverDB) == "table" and ARSForeverDB or {}
    local db = { schema = A.SCHEMA, characters = {} }
    self.db = db
    if type(old.schema) == "number" and old.schema > A.SCHEMA then
        -- Saved by a newer ARS: use it for this session but don't write over it
        self.sessionOnly = true
    end
    for k, def in pairs(A.DEFAULTS) do
        local v = old[k]
        if type(v) ~= type(def) then v = Copy(def) end
        db[k] = v
    end
    for k, r in pairs(A.RANGES) do
        if db[k] ~= db[k] then db[k] = A.DEFAULTS[k] end
        db[k] = math.max(r[1], math.min(r[2], db[k]))
    end
    local sort = db.directorySort
    if not A.SORT_KEYS[sort.key] or type(sort.descending) ~= "boolean" then db.directorySort = Copy(A.DEFAULTS.directorySort) end
    if type(old.lastSeenVersion) == "string" then db.lastSeenVersion = old.lastSeenVersion end
    db.importedIRS = old.importedIRS == true
    local p = old.position
    if type(p) == "table" and ANCHORS[p.point] and ANCHORS[p.relative] and type(p.x) == "number" and type(p.y) == "number"
        and p.x == p.x and p.y == p.y and math.abs(p.x) <= 10000 and math.abs(p.y) <= 10000 then
        db.position = { point = p.point, relative = p.relative, x = p.x, y = p.y }
    end
    self:MergeCharacters(old.characters)
    if not self.sessionOnly then ARSForeverDB = db end
end

-- Forever IRS's saved history (ForeverIRSDB). The game only loads it while
-- Forever IRS itself is enabled, so this works with both addons on.
function A:IRSData()
    local old = ForeverIRSDB
    if type(old) == "table" and type(old.characters) == "table" then return old.characters end
end

function A:ImportIRS(quiet)
    local data = self:IRSData()
    if not data then
        if not quiet then Print("Forever IRS's saved data isn't loaded. Enable Forever IRS in the AddOns list, log in, then try again.") end
        return false
    end
    local chars, snaps = self:MergeCharacters(data)
    self.db.importedIRS = true
    Print(("imported %d new character%s and %d capture%s from Forever IRS. You can turn Forever IRS off now.")
        :format(chars, chars == 1 and "" or "s", snaps, snaps == 1 and "" or "s"))
    if self.Refresh then self:Refresh() end
    return true, chars, snaps
end

function A:RestoreDefaults()
    for _, k in ipairs(A.RESTORE_KEYS) do self.db[k] = Copy(A.DEFAULTS[k]) end
    self:Changed()
end

-- A setting changed: bring everything that shows it up to date
function A:Changed()
    self:UpdateMinimapButton()
    self:UpdateInspectButton()
    if self.FitLedger then self:FitLedger() end
    if self.RefreshOptions then self:RefreshOptions() end
    if self.Render then self:Render() end
end

---------------------------------------------------------------------------
-- Saved history
---------------------------------------------------------------------------
function A:History(guid)
    local e = self.db and self.db.characters[guid]
    return e and e.snapshots or {}
end

-- Saves a capture. false when there's nothing in it or it's already saved.
function A:Save(s)
    if not s or (s.available == 0 and s.wallet == nil) then return false end
    local e = self.db.characters[s.guid]
    if not e then
        e = { firstSeen = s.at, snapshots = {} }
        self.db.characters[s.guid] = e
    end
    local last = e.snapshots[#e.snapshots]
    if last and last.at == s.at and last.build == s.build then return false end
    e.name, e.lastSeen = s.name, s.at
    e.snapshots[#e.snapshots + 1] = s
    while #e.snapshots > A.MAX_SNAPSHOTS do table.remove(e.snapshots, 1) end
    return true
end

function A:CharacterCount()
    local n, caps = 0, 0
    for _, e in pairs(self.db.characters) do
        n = n + 1
        caps = caps + #e.snapshots
    end
    return n, caps
end

function A:ClearHistory()
    self.db.characters = {}
    self.snapshot, self.subjectInfo = nil, nil
    self:Changed()
end

function A:SortDirectory(key)
    if not A.SORT_KEYS[key] then return end
    local sort = self.db.directorySort
    if sort.key == key then sort.descending = not sort.descending
    else sort.key, sort.descending = key, key ~= "name" end
    self.directoryPage = 0
end

-- The Characters tab's rows: each character's newest capture. Missing numbers
-- sort last either way; an older value never stands in for a missing one.
function A:DirectoryRows(query, key, descending)
    local sort = self.db.directorySort
    key = A.SORT_KEYS[key] and key or sort.key
    if descending == nil then descending = sort.descending end
    query = type(query) == "string" and query:lower():match("^%s*(.-)%s*$") or ""
    local rows, total = {}, 0
    for guid, e in pairs(self.db.characters) do
        local s = e.snapshots[#e.snapshots]
        if s then
            total = total + 1
            local text = table.concat({ s.name, s.realm, s.guild or "", s.class }, " "):lower()
            if query == "" or text:find(query, 1, true) then
                rows[#rows + 1] = { guid = guid, snapshot = s, count = #e.snapshots, lastSeen = s.at,
                    name = (s.name .. " " .. s.realm):lower(), level = s.level,
                    peak = A.Numeric(s, "peak"), acquired = A.Numeric(s, "acquired") }
            end
        end
    end
    table.sort(rows, function(a, b)
        local av, bv = a[key], b[key]
        if av == nil and bv ~= nil then return false end
        if bv == nil and av ~= nil then return true end
        if av ~= bv then
            if descending then return av > bv end
            return av < bv
        end
        if a.name ~= b.name then return a.name < b.name end
        return a.guid < b.guid
    end)
    return rows, total
end

---------------------------------------------------------------------------
-- Out of combat
---------------------------------------------------------------------------
-- Runs fn now, or when combat ends (one per key; a later one replaces it)
function A:RunOutOfCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return true
    end
    self.waiting = self.waiting or { keys = {}, fns = {} }
    local w = self.waiting
    if not w.fns[key] then w.keys[#w.keys + 1] = key end
    w.fns[key] = fn
    return false
end

function A:FlushWaiting()
    local w = self.waiting
    if not w then return end
    self.waiting = nil
    for _, key in ipairs(w.keys) do w.fns[key]() end
end

---------------------------------------------------------------------------
-- Requests to the game
---------------------------------------------------------------------------
A.nextRequest, A.externalUntil, A.serial = 0, 0, 0
local function Now() return GetTime() end

local function SafeString(v) if not IsSecret(v) and type(v) == "string" then return v end end

-- Who a unit is. nil, why when it can't be read (Forever hides identity in
-- some places; Forever IRS errored on those hidden values).
function A:Subject(unit)
    local exists = UnitExists(unit)
    if IsSecret(exists) then return nil, "hidden" end
    if not exists then return nil, "none" end
    local isPlayer = UnitIsPlayer(unit)
    if IsSecret(isPlayer) then return nil, "hidden" end
    if not isPlayer then return nil, "none" end
    local guid = UnitGUID(unit)
    if IsSecret(guid) then return nil, "hidden" end
    if type(guid) ~= "string" then return nil, "none" end
    local name, realm = UnitFullName(unit)
    if IsSecret(name) or IsSecret(realm) then return nil, "hidden" end
    local class, classFile = UnitClass(unit)
    local level = UnitLevel(unit)
    level = A.Number(level)
    if level and level < 1 then level = nil end   -- -1: a skull level
    local guild = type(GetGuildInfo) == "function" and SafeString((GetGuildInfo(unit))) or nil
    return { guid = guid, name = SafeString(name) or "Unknown",
        realm = SafeString(realm) or SafeString(GetRealmName()) or "",
        class = SafeString(class) or "", classFile = SafeString(classFile), level = level, guild = guild }
end

-- Is this unit you? By GUID (UnitIsUnit can be hidden on Forever)
local function IsMe(guid)
    local mine = UnitGUID("player")
    return not IsSecret(mine) and not IsSecret(guid) and guid == mine
end

local function SameGUID(unit, guid)
    local g = UnitGUID(unit)
    return not IsSecret(g) and g == guid
end

function A:Update(message)
    if message then self.status = message end
    if self.Render then self:Render() end
end

function A:Release()
    if self.ownsComparison then
        self.ownsComparison = false
        if type(ClearAchievementComparisonUnit) == "function" then
            self.internal = true
            pcall(ClearAchievementComparisonUnit)
            self.internal = false
        end
    end
end

function A:Cancel(message, release)
    if self.pending then
        self.verification = { state = message and "failed" or "cancelled",
            detail = message or "Request cancelled before an answer came." }
    end
    self.pending = nil
    self.serial = self.serial + 1
    if release ~= false then self:Release() end
    if message then self:Update(message) end
end

function A:Finish(s)
    local history = self:History(s.guid)
    self.verification = { state = "complete", snapshot = s, result = A.CheckCapture(s, history[#history]) }
    self.pending, self.snapshot = nil, s
    self:Release()
    if s.available > 0 or s.wallet ~= nil then
        self:Save(s)
        self:Update((self.sessionOnly and "Shown for this session only (saved by a newer ARS)" or "Saved")
            .. " - " .. s.available .. " / " .. #A.FIELDS .. " statistics read")
    else
        self:Update("The game returned no readable statistics. Try Refresh; /ars status shows what's available.")
    end
end

-- What the last read says, for the red error strip and the report
function A:VerificationView(snapshot)
    local s, v = snapshot or self.snapshot, self.verification
    if self.savedView or (s and (not v or v.snapshot ~= s)) then
        return { tone = "muted", title = "Saved snapshot - not read again",
            detail = "These numbers were saved earlier. Click Refresh with this player nearby to read them again." }
    end
    if self.pending then
        local left = self.pending.queuedUntil and math.max(0, math.ceil(self.pending.queuedUntil - Now()))
        return { tone = "neutral", title = left and "Waiting to ask the game" or "Reading statistics...",
            detail = left and ("The game allows one request every few seconds: asking in " .. left .. "s.")
                or "Waiting for the game's answer for this player." }
    end
    if v and (v.state == "failed" or v.state == "cancelled") then
        return { tone = v.state == "failed" and "error" or "neutral",
            title = v.state == "failed" and "Couldn't read the statistics" or "Request cancelled", detail = v.detail }
    end
    if not s or not v or v.state ~= "complete" then
        return { tone = "muted", title = "Nothing read yet", detail = "Use My character, Target or Refresh." }
    end
    local r = v.result
    if r.numeric == 0 then
        return { tone = r.displayOnly > 0 and "neutral" or "error",
            title = r.displayOnly > 0 and "Statistics came back as text only" or "No readable statistics came back",
            detail = r.displayOnly > 0 and (r.displayOnly .. " values are text the addon can't turn into numbers safely.")
                or "No statistics could be read. Your gold alone doesn't count; try Refresh." }
    end
    local cmp
    if r.baseline == "first" then cmp = "First capture of this character."
    elseif r.baseline == "build" then cmp = "The game was updated since the last capture; not compared."
    elseif r.baseline == "source" then cmp = "Read differently from the last capture; not compared."
    elseif r.compared == 0 then cmp = "Nothing to compare with the last capture."
    elseif r.changed > 0 then cmp = r.changed .. " of " .. r.compared .. " statistics changed since the last capture."
    else cmp = "Nothing changed since the last capture (that doesn't prove the numbers are fresh)." end
    if r.lost > 0 then cmp = cmp .. " " .. r.lost .. " that were readable before are missing now." end
    return { tone = r.numeric == #A.FIELDS and "positive" or "neutral",
        title = "Read " .. r.numeric .. " / " .. #A.FIELDS .. " statistics",
        detail = (s.own and "Read from your own character. " or "The game answered for this player. ") .. cmp }
end

local function Fail(message)
    A.verification = { state = "failed", detail = message }
    A:Update(message)
end

local function PendingStatus()
    local p = A.pending
    if not p then return end
    if p.queuedUntil then
        A:Update("Waiting to ask the game - " .. math.max(0, math.ceil(p.queuedUntil - Now())) .. "s")
    else
        A:Update("Reading statistics - " .. math.floor(Now() - p.started) .. "s")
    end
end

local function StartInspection()
    local p = A.pending
    if not p then return end
    -- A queued request checks everything again when it goes out
    if not SameGUID(p.unit, p.guid) then A:Cancel("Your target changed. Click Target to read the new one.") return end
    if InCombatLockdown() then A:Cancel("Leave combat, then click Refresh.") return end
    if type(SetAchievementComparisonUnit) ~= "function" or type(GetComparisonStatistic) ~= "function" or not A.comparisonHooks then
        A:Cancel("This client can't read another player's statistics.")
        return
    end
    local can = type(CanInspect) == "function" and CanInspect(p.unit, false)
    if IsSecret(can) or not can then A:Cancel("This player can't be inspected right now. Move closer and click Refresh.") return end
    if AchievementFrame and AchievementFrame:IsShown() and AchievementFrame.isComparison then
        A:Cancel("Close the achievement comparison window first.")
        return
    end
    local readyAt = math.max(A.nextRequest, A.externalUntil)
    if readyAt > Now() then
        p.queuedUntil = readyAt
        PendingStatus()
        return
    end
    p.queuedUntil, p.started, p.deadline = nil, Now(), Now() + A.REQUEST_WAIT
    A.nextRequest = Now() + A.REQUEST_GAP
    A.ownsComparison, A.internal = true, true
    local ok, result = pcall(SetAchievementComparisonUnit, p.unit)
    A.internal = false
    if not ok or result == false then A:Cancel("The game didn't take the request. Try again with this player nearby.") return end
    PendingStatus()
end

-- Reads a unit's statistics (yours at once, another player's through the
-- game's inspect request). origin: "command", "inspect", "button"...
function A:Audit(unit, origin)
    self:InstallAchievementGuard()
    origin = origin or "command"
    self.directoryMode, self.savedView = false, false
    local p = self.pending
    if p and p.unit == unit and SameGUID(unit, p.guid) then
        -- Same player already on the way: just show it
        self.origin = origin
        if self.ShowLedger then self:ShowLedger(origin) end
        if p.queuedUntil and Now() >= p.queuedUntil then StartInspection() else PendingStatus() end
        return
    end
    self:Cancel(nil)
    self.verification = nil
    if self.reportWindow then self.reportWindow:Hide() end
    local subject, why = self:Subject(unit)
    self.origin, self.unit, self.snapshot, self.subjectInfo = origin, unit, nil, subject
    self.tab = self.tab == "characters" and "ledger" or (self.tab or "ledger")
    if self.ShowLedger then self:ShowLedger(origin) end
    if not A.Supported() then Fail("ARS is made for WoW: Forever (1.60). This client isn't it.") return end
    if not subject then
        Fail(why == "hidden" and "The game is hiding who this player is here (it often does in instances). Try again somewhere else."
            or "Target a nearby player, then click Target. My character shows your own.")
        return
    end
    if InCombatLockdown() then Fail("Leave combat, then click Refresh.") return end
    if IsMe(subject.guid) then self:Finish(A.Read(subject, true)) return end
    self.pending = { guid = subject.guid, unit = unit, subject = subject }
    StartInspection()
end

-- /ars with nothing after it: your target if it's a player, else you
function A:AuditDefault(origin)
    local s = self:Subject("target")
    self:Audit(s and "target" or "player", origin)
end

function A:OpenDirectory()
    self:Cancel(nil)
    self.origin, self.directoryMode, self.tab = "directory", true, "characters"
    self.verification = nil
    if self.reportWindow then self.reportWindow:Hide() end
    self.status = "Each character's newest capture. Click a row to open it."
    if self.ShowLedger then self:ShowLedger("directory") end
end

function A:OpenSaved(guid)
    local h = self:History(guid)
    local s = h[#h]
    if not s then self:Update("Nothing saved for this character.") return false end
    self:Cancel(nil)
    self.origin, self.unit, self.snapshot, self.subjectInfo = "saved", nil, s, nil
    self.verification = nil
    if self.reportWindow then self.reportWindow:Hide() end
    self.directoryMode, self.savedView, self.tab, self.historyPage = false, true, "ledger", 0
    self.status = "Saved capture. Refresh needs this same player nearby."
    if self.ShowLedger then self:ShowLedger("saved") end
    return true
end

function A:Refresh()
    if self.directoryMode then if self.Render then self:Render() end return end
    if self.savedView and self.snapshot then
        for _, unit in ipairs({ "player", "target" }) do
            if SameGUID(unit, self.snapshot.guid) then self:Audit(unit) return end
        end
        self:Update("Target this player and stay nearby to read them again. The saved capture hasn't changed.")
        return
    end
    self:Audit(self.unit or "player", self.origin)
end

-- Notices when another addon (or the game's comparison window) takes the
-- shared comparison request, and steps aside.
function A:InstallComparisonHooks()
    if self.comparisonHooks or type(hooksecurefunc) ~= "function" or type(SetAchievementComparisonUnit) ~= "function"
        or type(ClearAchievementComparisonUnit) ~= "function" then return end
    local function displaced()
        if A.internal then return end
        A.ownsComparison = false
        A.externalUntil = Now() + A.REQUEST_GAP
        if A.pending then A:Cancel("Another addon took over the request. Click Refresh to try again.", false) end
    end
    if not self.setHook then self.setHook = pcall(hooksecurefunc, "SetAchievementComparisonUnit", displaced) end
    if not self.clearHook then self.clearHook = pcall(hooksecurefunc, "ClearAchievementComparisonUnit", displaced) end
    self.comparisonHooks = self.setHook and self.clearHook
end

-- The game's achievement comparison panel listens for inspect answers even
-- while hidden, and one meant for us made it error on its Summary page. It only
-- listens while shown now; its own scripts are untouched (HookScript only).
function A:InstallAchievementGuard()
    local cmp = AchievementFrameComparison
    if not A.Supported() or not cmp or self.guardFrame == cmp then return end
    local function sync(f)
        if f:IsVisible() then f:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
        else f:UnregisterEvent("INSPECT_ACHIEVEMENT_READY") end
    end
    cmp:HookScript("OnShow", sync)
    cmp:HookScript("OnHide", sync)
    self.guardFrame = cmp
    sync(cmp)
end

---------------------------------------------------------------------------
-- The Inspect window (HookScript and hooksecurefunc only: never opened,
-- closed or scripted by us)
---------------------------------------------------------------------------
function A:OnInspect(unit)
    if self.db.autoInspect and type(unit) == "string" then self:Audit(unit, "inspect") end
end

function A:HookInspect()
    if not InspectFrame or self.hookedInspect then return end
    self.hookedInspect = true
    InspectFrame:HookScript("OnShow", function(f) A:OnInspect(f.unit) end)
    -- Inspecting someone else while it's open doesn't show it again, so Forever
    -- IRS stayed on the first player; this catches the second.
    if type(InspectFrame_Show) == "function" then
        hooksecurefunc("InspectFrame_Show", function(unit)
            if InspectFrame:IsShown() then A:OnInspect(unit) end
        end)
    end
    InspectFrame:HookScript("OnHide", function()
        if A.origin == "inspect" then
            A:Cancel(nil)
            if A.ledger then A.ledger:Hide() end
        end
    end)
    local b = T.FlatButton(InspectFrame, "ARS", 54, 20)
    b:SetPoint("TOPRIGHT", InspectFrame, "BOTTOMRIGHT", -18, -2)
    b:SetScript("OnClick", function()
        if type(InspectFrame.unit) == "string" then A:Audit(InspectFrame.unit, "inspect") end
    end)
    T.Tooltip(b, T.NAME, "Show this player's gold statistics.")
    self.inspectButton = b
    self:UpdateInspectButton()
end

function A:UpdateInspectButton()
    if self.inspectButton then self.inspectButton:SetShown(self.db.inspectButton) end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
function A:PositionMinimapButton()
    local angle = math.rad(self.db.minimapAngle or 210)
    local radius = (Minimap:GetWidth() / 2) + 10
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function A:BuildMinimapButton()
    if self.minimapButton or not Minimap then return end
    local b = CreateFrame("Button", "ARSForeverMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(22, 22)
    icon:SetTexture(T.LOGO)
    icon:SetPoint("TOPLEFT", 5, -4)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then A:OpenOptions() else A:ToggleLedger() end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            A.db.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            A:PositionMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(T.NAME)
        GameTooltip:AddLine("Left-click: your target's ledger, or yours", 1, 1, 1)
        GameTooltip:AddLine("Right-click: options", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.minimapButton = b
    self:PositionMinimapButton()
    self:UpdateMinimapButton()
end

function A:UpdateMinimapButton()
    if self.minimapButton then self.minimapButton:SetShown(self.db.minimapButton) end
end

function A:ToggleLedger()
    if self.ledger and self.ledger:IsShown() then self.ledger:Hide() else self:AuditDefault("button") end
end

---------------------------------------------------------------------------
-- /ars
---------------------------------------------------------------------------
function A:Status()
    Print("version " .. tostring(self:Version()) .. ", client " .. A.Build() .. ", statistic list checked for " .. A.DATA_BUILD)
    for _, name in ipairs({ "GetStatistic", "GetComparisonStatistic", "SetAchievementComparisonUnit", "ClearAchievementComparisonUnit" }) do
        Print("  " .. name .. ": " .. (type(_G[name]) == "function" and "yes" or "|cffff5a4amissing|r"))
    end
    local p = self.pending
    if p then
        Print("  " .. (p.queuedUntil and "waiting to ask for " or "reading ") .. A.Plain(p.subject.name)
            .. (p.started and (" - " .. math.floor(Now() - p.started) .. "s") or ""))
    else
        Print("  " .. (self.status or "no request yet"))
    end
    local n, caps = self:CharacterCount()
    Print(("  %d saved characters, %d captures%s"):format(n, caps, self.sessionOnly and " (this session only)" or ""))
end

-- Every statistic ID the addon reads, with the client's own name for it, so
-- they can be checked in game
function A:Check()
    Print("the statistics ARS reads (ID, the addon's name, the game's name):")
    local missing, different = 0, 0
    for _, f in ipairs(A.FIELDS) do
        local id, label = f[2], f[3]
        local name
        if type(GetAchievementInfo) == "function" then
            local ok, _, n = pcall(GetAchievementInfo, id)
            if ok and not IsSecret(n) and type(n) == "string" then name = n end
        end
        local line
        if not name then
            missing = missing + 1
            line = "|cffff5a4anot found|r"
        elseif name:lower() == label:lower() then
            line = "|cff7fd17f" .. name .. "|r"
        else
            different = different + 1
            line = "|cffffb84d" .. name .. "|r"
        end
        Print(("  %d %s: %s"):format(id, label, line))
    end
    Print(("%d checked, %d not found, %d named differently (another language names them differently too)."):format(#A.FIELDS, missing, different))
    return missing, different
end

local function Help()
    Print("commands:")
    for _, l in ipairs({
        { "/ars", "your target's ledger (a player), or yours" },
        { "/ars me", "your own ledger" }, { "/ars target", "your target's ledger" },
        { "/ars history", "saved characters (also /ars list)" }, { "/ars refresh", "read the shown player again" },
        { "/ars auto on|off", "open beside the Inspect window" }, { "/ars options", "the options window" },
        { "/ars status", "versions and what's happening" }, { "/ars check", "every statistic the addon reads" },
        { "/ars scale 0.6-1.6|reset", "the ledger's size" }, { "/ars reset", "put the ledger back in the middle" },
        { "/ars news", "what's new" }, { "/ars import", "bring in Forever IRS's saved history" },
        { "/ars close", "close the ledger" },
    }) do Print("  |cffffd100" .. l[1] .. "|r  " .. l[2]) end
end

function A:Command(msg)
    local text = (msg or ""):lower():match("^%s*(.-)%s*$")
    if text == "" then self:AuditDefault("command")
    elseif text == "me" or text == "self" then self:Audit("player")
    elseif text == "target" then self:Audit("target")
    elseif text == "refresh" or text == "verify" then self:Refresh()
    elseif text == "history" or text == "list" then self:OpenDirectory()
    elseif text == "status" then self:Status()
    elseif text == "check" then self:Check()
    elseif text == "options" or text == "config" or text == "settings" then self:OpenOptions()
    elseif text == "news" then self:ShowSplash()
    elseif text == "import" then self:ImportIRS()
    elseif text == "close" then if self.ledger then self.ledger:Hide() end
    elseif text == "auto on" or text == "auto off" then
        self.db.autoInspect = text == "auto on"
        Print("open beside the Inspect window: " .. (self.db.autoInspect and "on" or "off"))
        self:Changed()
    elseif text == "reset" then
        self.db.position = nil
        if self.ledger then
            self.ledger:ClearAllPoints()
            self.ledger:SetPoint("CENTER")
        end
        Print("ledger moved back to the middle. Saved history is kept.")
    elseif text:match("^scale") then
        local v = text:match("^scale%s*(.-)$")
        local n = tonumber(v)
        if v == "reset" then self.db.scale = A.DEFAULTS.scale
        elseif n and n >= A.RANGES.scale[1] and n <= A.RANGES.scale[2] then self.db.scale = n
        elseif v ~= "" then Print("pick a size from 0.6 to 1.6, or /ars scale reset.") return end
        Print(("ledger size: %.2f"):format(self.db.scale))
        self:Changed()
    else
        Help()
    end
end

SLASH_ARSFOREVER1 = "/ars"
SLASH_ARSFOREVER2 = "/arsforever"
SlashCmdList.ARSFOREVER = function(msg) A:Command(msg) end

function A:Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local v = get and get(ADDON, "Version")
    if not v or v:find("@", 1, true) then return "dev" end
    return (v:gsub("^v", ""))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
A.events = events
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "INSPECT_ACHIEVEMENT_READY",
    "PLAYER_TARGET_CHANGED", "PLAYER_LOGOUT", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg == ADDON then
            A:LoadSettings()
            A:InstallComparisonHooks()
        end
        A:InstallAchievementGuard()
        A:HookInspect()
    elseif event == "PLAYER_LOGIN" then
        A:InstallComparisonHooks()
        A:InstallAchievementGuard()
        A:HookInspect()
        A:BuildMinimapButton()
        if not A.db.importedIRS and A:IRSData() then A:ImportIRS(true) end
        if A.MaybeShowSplash then A:MaybeShowSplash() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        A:FlushWaiting()
    elseif event == "INSPECT_ACHIEVEMENT_READY" then
        local p = A.pending
        -- A late answer to a cancelled request never fills a newer one
        if not p or p.queuedUntil or IsSecret(arg) or p.guid ~= arg then return end
        if Now() > p.deadline then A:Cancel("The answer came too late. Click Refresh to ask again.") return end
        if not SameGUID(p.unit, p.guid) then A:Cancel("The player changed. Click Target to read the new one.") return end
        if InCombatLockdown() then A:Cancel("Combat interrupted the request. Leave combat and click Refresh.") return end
        A:Finish(A.Read(p.subject, false))
    elseif event == "PLAYER_TARGET_CHANGED" then
        local p = A.pending
        if p and p.unit == "target" and not SameGUID("target", p.guid) then
            A:Cancel("Your target changed. Click Target to read the new one.")
        end
    elseif event == "PLAYER_LOGOUT" then
        A:Cancel(nil)
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        if A.FitLedger then A:FitLedger() end
    end
end)

-- Once a second: send a queued request, give up on a late one, update the age
local tick = 0
events:SetScript("OnUpdate", function(_, elapsed)
    tick = tick + elapsed
    if tick < 1 then return end
    tick = 0
    local p = A.pending
    if p then
        if p.queuedUntil then
            if Now() >= p.queuedUntil then StartInspection() else PendingStatus() end
        elseif Now() >= p.deadline then
            A:Cancel("No answer after " .. A.REQUEST_WAIT .. "s. Move closer and click Refresh (nothing is sent again by itself).")
        else
            PendingStatus()
        end
    elseif A.ledger and A.ledger:IsShown() and A.RefreshAge then
        A:RefreshAge()
    end
end)
