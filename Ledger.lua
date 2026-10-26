-- ARS Forever: the ledger window (Ledger, Activity, History and Characters
-- tabs) and the copyable report, in the shared Forever look. Compact: the long
-- explanations are in the hover help.

local _, ns = ...
local A = ns.ARS
local T = ns.Theme
local C = T.C

local W, H = 560, 540
local HEADER, TABS_H, FOOTER, INFO_H = 56, 28, 40, 36
local ERROR_H = 50
local X0, PAGE_W = 12, 536
local COL_GAP = 10
local COL_W = (PAGE_W - 2 * COL_GAP) / 3
local ROW = 15
local DIR_ROWS, DIR_ROW_H = 11, 26
local HIST_ROWS = 9
local GAP_BAR_W = 120
local LOWER_Y = -150
local MISSING = "--"

local WHITE, GREY, GOLD, GREEN, RED = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }, { 1, 0.82, 0 }, { 0.3, 0.9, 0.3 }, { 1, 0.35, 0.3 }
local BAR_COLOR = { 0.35, 0.65, 0.9 }
local TAB_LIST = { { "ledger", "Ledger" }, { "activity", "Activity" }, { "history", "History" }, { "characters", "Characters" } }
-- Shorter names where the section heading already says what they are
local SHORT = { daily = "Earned per day", posted = "Posted", purchases = "Won", largestSale = "Largest sale",
    largestBid = "Largest bid", disenchanted = "Disenchants", questCount = "Quests", kills = "Kills",
    dungeons = "Dungeons", auctions = "Auctions", vendors = "Vendor sales", looted = "Looted", quests = "Quests" }

local w, ui

local function Color(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

-- A one-line text at x, y (from the parent's top left), width wide
local function Label(parent, template, x, y, width, justify, color)
    local fs = T.Text(parent, "", template or "GameFontHighlightSmall", color)
    fs:SetPoint("TOPLEFT", x, y)
    if width then fs:SetWidth(width) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Fill(parent, x, y, width, height, color)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetPoint("TOPLEFT", x, y)
    t:SetSize(width, height)
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return t
end

local function Heading(parent, title, x, y, width)
    local fs = Label(parent, "GameFontNormalSmall", x, y, width, "LEFT", C.orange)
    fs:SetText(title:upper())
    Fill(parent, x, y - 15, width, 1, C.line)
    return fs
end

local function HideTip(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end

-- Hover help on any frame: a title and lines ({ text, r, g, b } or text)
local function Help(frame, title, lines)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(type(title) == "function" and title() or title)
        local list = type(lines) == "function" and lines() or lines
        for _, l in ipairs(list) do
            if type(l) == "table" then GameTooltip:AddLine(l[1], l[2], l[3], l[4], true)
            else GameTooltip:AddLine(l, 1, 1, 1, true) end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", HideTip)
end

local function ClassColor(s)
    if type(s) ~= "table" or type(RAID_CLASS_COLORS) ~= "table" then return nil end
    local token = s.classFile
    if not token and type(s.class) == "string" and s.class ~= "" then
        for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
            if type(names) == "table" then
                for k, v in pairs(names) do if v == s.class then token = k end end
            end
        end
        token = token or s.class:upper():gsub("%s", "")
    end
    local c = token and RAID_CLASS_COLORS[token]
    return c and { c.r, c.g, c.b }
end

local function Identity(s)
    local parts = { "Level " .. (s.level and tostring(s.level) or "??") .. " " .. A.Plain(s.class) }
    if s.guild and s.guild ~= "" then parts[#parts + 1] = "<" .. A.Plain(s.guild) .. ">" end
    if s.realm and s.realm ~= "" then parts[#parts + 1] = A.Plain(s.realm) end
    return table.concat(parts, "  -  ")
end

local function When(at, fmt)
    return type(at) == "number" and date(fmt or "%b %d, %H:%M", at) or MISSING
end

local function Ago(at)
    local m = math.max(0, math.floor((GetServerTime() - at) / 60))
    if m < 1 then return "just now" elseif m < 60 then return m .. "m ago" elseif m < 2880 then return math.floor(m / 60) .. "h ago" end
    return math.floor(m / 1440) .. "d ago"
end

-- A statistic's value in a font string: coins for money, grey "--" when missing
local function Show(fs, s, key)
    local e = s and s.values and s.values[key]
    if e and e.number ~= nil and A.BY_KEY[key][4] then fs:SetText(A.Coins(e.number))
    elseif e then fs:SetText(A.Value(s, key))
    else fs:SetText(MISSING) end
    Color(fs, e and WHITE or GREY)
end

local INCOME_KEYS = { acquired = true, peak = true, looted = true, quests = true, vendors = true, auctions = true }

-- Hover on a statistic: its full name, where it came from, or why it's missing
local function Explain(self)
    local key = self.key
    if not key then return end
    local s = A.snapshot
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(A.BY_KEY[key][3])
    local e = s and s.values[key]
    if e then
        GameTooltip:AddLine(e.number ~= nil and "As the game reported it when this was captured."
            or "Shown as text: this format couldn't be turned into a number safely.", 1, 1, 1, true)
    else
        GameTooltip:AddLine(A.MissingWord(s, key) .. ": " .. A.Reason(s, key), 1, 1, 1, true)
    end
    if INCOME_KEYS[key] then
        GameTooltip:AddLine(A.NOT_PROFIT, 0.8, 0.85, 0.9, true)
        GameTooltip:AddLine(A.INCOME_SOURCES, 1, 1, 1, true)
        if key == "acquired" then GameTooltip:AddLine(A.INCOME_TOTAL_NOTE, 0.8, 0.85, 0.9, true) end
        GameTooltip:AddLine(A.INCOME_TRANSFERS, 1, 1, 1, true)
        GameTooltip:AddLine(A.INCOME_DISCLAIMER, 1, 0.82, 0, true)
    end
    if key == "travel" or key == "postage" or key == "barber" or key == "respec" then
        GameTooltip:AddLine("Only these kinds of spending are counted, not all of it.", 0.8, 0.8, 0.8, true)
    end
    if A.BY_KEY[key][5] then GameTooltip:AddLine("Highest rank recorded; the profession may have been unlearned since.", 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

-- One striped line: gold name, white value on the right, hover explains it
local function Line(parent, x, y, width, index, valueW)
    local r = CreateFrame("Frame", nil, parent)
    r:SetPoint("TOPLEFT", x, y)
    r:SetSize(width, ROW)
    if index % 2 == 1 then Fill(r, 0, 0, width, ROW, { 1, 1, 1, 0.04 }) end
    valueW = valueW or 80
    r.name = Label(r, "GameFontNormalSmall", 4, -2, width - valueW - 8, "LEFT", C.gold)
    r.value = Label(r, "GameFontHighlightSmall", width - valueW - 4, -2, valueW, "RIGHT")
    r:EnableMouse(true)
    r:SetScript("OnEnter", Explain)
    r:SetScript("OnLeave", HideTip)
    return r
end

local function Section(parent, title, x, y, width, keys, full)
    Heading(parent, title, x, y, width)
    local rows = {}
    for i, key in ipairs(keys) do
        local r = Line(parent, x, y - 20 - (i - 1) * ROW, width, i)
        r.key = key
        r.name:SetText(not full and SHORT[key] or A.BY_KEY[key][3])
        rows[key] = r.value
    end
    ui.groups[#ui.groups + 1] = rows
    return rows
end

local function Button(parent, text, width, onClick, tip)
    local b = T.FlatButton(parent, text, width, 22)
    b:SetScript("OnClick", function(self) if not self.disabled then onClick(self) end end)
    if tip then T.Tooltip(b, text, tip) end
    T.Disabler(b, { b })
    return b
end

---------------------------------------------------------------------------
-- The report window
---------------------------------------------------------------------------
local function MakeReport()
    if A.reportWindow then return A.reportWindow end
    local f = CreateFrame("Frame", "ARSForeverReport", UIParent)
    f:SetSize(520, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()
    table.insert(UISpecialFrames, "ARSForeverReport")
    T.Fill(f, C.win)
    T.Border(f, C.edge)
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(26)
    T.HeaderStrip(head, "Copy report")
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() f:StartMoving() end)
    head:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local note = Label(f, "GameFontHighlightSmall", 14, -36, 490)
    note:SetText("Press Ctrl+A, then Ctrl+C to copy. Nothing is posted to chat.")
    local holder = CreateFrame("Frame", nil, f)
    holder:SetPoint("TOPLEFT", 14, -56)
    holder:SetPoint("BOTTOMRIGHT", -14, 44)
    T.Fill(holder, C.field)
    T.Border(holder, C.fieldEdge)
    local area = CreateFrame("Frame", nil, holder)
    area:SetPoint("TOPLEFT", 6, -6)
    area:SetPoint("BOTTOMRIGHT", -4, 6)
    local scroll = T.ScrollArea(area, 308)
    local edit = CreateFrame("EditBox", nil, scroll.child)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetPoint("TOPLEFT")
    edit:SetWidth(460)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    local close = T.FlatButton(f, "Close", 90)
    close:SetPoint("BOTTOMRIGHT", -14, 12)
    close:SetScript("OnClick", function() f:Hide() end)
    f.edit, f.scroll = edit, scroll
    A.reportWindow = f
    return f
end

function A:OpenReport()
    local f = MakeReport()
    local text = A.Report(self.snapshot, self.snapshot and self:VerificationView())
    local lines = 1
    for _ in text:gmatch("\n") do lines = lines + 1 end
    -- Tall enough for every line (Forever IRS's box was a fixed 800 and cut
    -- long reports off), plus room for long lines that wrap
    local height = lines * 14 + 60
    f.edit:SetHeight(height)
    f.scroll:SetContent(460, height)
    f.edit:SetText(text)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
function A:RefreshAge()
    if not ui then return end
    Color(ui.age, self.pending and GOLD or C.muted)
    if self.directoryMode then ui.age:SetText("Saved on this computer") return end
    if self.pending then
        local left = self.pending.queuedUntil and math.ceil(self.pending.queuedUntil - GetTime()) or 0
        ui.age:SetText(left > 0 and ("Asking in " .. left .. "s...") or "Reading...")
        return
    end
    local s = self.snapshot
    ui.age:SetText(s and ("Captured " .. Ago(s.at)) or "Nothing read yet")
end

local function SetEnabled(b, on) b:SetDisabled(not on) end

local function RenderHistory()
    local h = ui.history
    local s = A.snapshot
    local all = s and A:History(s.guid) or {}
    local pages = math.max(1, math.ceil(#all / HIST_ROWS))
    A.historyPage = math.max(0, math.min(A.historyPage or 0, pages - 1))
    h.caption:SetText(("Saved captures: %d of %d kept, newest first"):format(#all, A.MAX_SNAPSHOTS):upper())
    for i, row in ipairs(h.rows) do
        local pos = #all - (A.historyPage * HIST_ROWS + i - 1)
        local snap = all[pos]
        if snap then
            row.time:SetText(When(snap.at))
            for _, k in ipairs({ "peak", "acquired" }) do
                local v = A.Numeric(snap, k)
                row[k]:SetText(A.Coins(v))
                Color(row[k], v ~= nil and WHITE or GREY)
            end
            local prev = all[pos - 1]
            local a, b = A.Numeric(snap, "acquired"), A.Numeric(prev, "acquired")
            local delta = prev and prev.build == snap.build and a and b and a >= b and a - b or nil
            row.delta:SetText(delta and ("+ " .. A.Coins(delta)) or MISSING)
            Color(row.delta, delta and GREEN or GREY)
            row.frame:Show()
        else
            row.frame:Hide()
        end
    end
    h.page:SetText(A.historyPage + 1 .. " / " .. pages)
    SetEnabled(h.prev, A.historyPage > 0)
    SetEnabled(h.next, A.historyPage < pages - 1)
end

local function RenderDirectory()
    local d = ui.directory
    local rows, total = A:DirectoryRows(A.directoryQuery)
    local pages = math.max(1, math.ceil(#rows / DIR_ROWS))
    A.directoryPage = math.max(0, math.min(A.directoryPage or 0, pages - 1))
    d.caption:SetText(#rows .. " / " .. total .. " characters")
    local sort = A.db.directorySort
    for key, b in pairs(d.headers) do
        local on = sort.key == key
        Color(b.label, on and C.gold or C.muted)
        b.arrow:SetShown(on)
        if on then b.arrow:SetTexCoord(0, 1, sort.descending and 0 or 1, sort.descending and 1 or 0) end
    end
    for i, row in ipairs(d.rows) do
        local e = rows[A.directoryPage * DIR_ROWS + i]
        row.guid = e and e.guid or nil
        if e then
            local s = e.snapshot
            row.name:SetText(A.Plain(s.name) .. (s.own and " (you)" or ""))
            Color(row.name, ClassColor(s) or WHITE)
            row.realm:SetText(A.Plain(s.realm) .. (s.class ~= "" and ("  -  " .. A.Plain(s.class)) or ""))
            row.level:SetText(s.level and tostring(s.level) or MISSING)
            row.peak:SetText(A.Coins(e.peak))
            Color(row.peak, e.peak ~= nil and WHITE or GREY)
            row.acquired:SetText(A.Coins(e.acquired))
            Color(row.acquired, e.acquired ~= nil and WHITE or GREY)
            row.lastSeen:SetText(When(e.lastSeen, "%b %d"))
            row.count:SetText(tostring(e.count))
            row:Show()
        else
            row:Hide()
        end
    end
    d.empty:SetText(total == 0 and "No saved characters yet. Open your own ledger or inspect a player to save one."
        or "No saved characters match this search.")
    d.empty:SetShown(#rows == 0)
    d.page:SetText(A.directoryPage + 1 .. " / " .. pages)
    SetEnabled(d.prev, A.directoryPage > 0)
    SetEnabled(d.next, A.directoryPage < pages - 1)
end

function A:Render()
    if not ui or not w:IsShown() then return end
    local directory = self.directoryMode == true
    local tab = directory and "characters" or (self.tab ~= "characters" and self.tab or "ledger")
    local check = self:VerificationView()
    local showError = not directory and check.tone == "error"
    local height = H + (showError and ERROR_H or 0)
    if w:GetHeight() ~= height then
        w:SetHeight(height)
        self:FitLedger()
    end
    ui.content:ClearAllPoints()
    ui.content:SetPoint("TOPLEFT", 0, -(HEADER + TABS_H + 8 + (showError and ERROR_H or 0)))
    ui.content:SetPoint("BOTTOMRIGHT", 0, FOOTER + INFO_H)
    ui.err:SetShown(showError)
    ui.err.title:SetText(check.title)
    ui.err.detail:SetText(check.detail)
    for key, b in pairs(ui.tabs) do
        local on = key == tab
        b.selBg:SetShown(on)
        b.accent:SetShown(on)
        Color(b.label, on and C.gold or C.muted)
    end
    ui.status:SetText(A.Plain(self.status or ""))
    ui.auto:SetOn(self.db.autoInspect)
    self:RefreshAge()
    local src = A.SourceStatus(not directory and self.snapshot or nil)
    ui.source:SetText(src.reason and ("WARNING: " .. src.reason)
        or "From the game's statistics, not checked for accuracy.  \"--\" = not reported, not zero.")
    Color(ui.source, src.reason and RED or GREY)
    ui.ledger:SetShown(not directory)
    ui.directory:SetShown(directory)
    SetEnabled(ui.copy, not directory and self.snapshot ~= nil)
    SetEnabled(ui.save, not directory and self.snapshot ~= nil)
    if directory then
        ui.name:SetText("Saved characters")
        Color(ui.name, C.title)
        ui.identity:SetText("Click a column to sort; again to reverse.")
        RenderDirectory()
        return
    end
    local s = self.snapshot
    local who = s or self.subjectInfo
    ui.name:SetText(who and A.Plain(who.name) or "Character ledger")
    Color(ui.name, who and ClassColor(who) or C.title)
    ui.identity:SetText(who and Identity(who) or "Target a player, or open your own.")
    ui.walletTitle:SetText(self.savedView and "GOLD THEN" or "CURRENT GOLD")
    Show(ui.cards.acquired, s, "acquired")
    Show(ui.cards.peak, s, "peak")
    local wallet = s and s.own and s.wallet
    ui.cards.wallet:SetText(wallet and A.Coins(wallet) or MISSING)
    Color(ui.cards.wallet, wallet and WHITE or GREY)
    ui.walletNote:SetText(s and not s.own and "Hidden for other players" or "Your own characters only")
    for _, rows in ipairs(ui.groups) do for key, fs in pairs(rows) do Show(fs, s, key) end end
    local a = A.Assess(s)
    ui.band.title:SetText(a.title)
    Color(ui.band.title, a.known > 0 and WHITE or GREY)
    ui.band.coverage:SetText(a.known > 0 and (a.positive .. " of " .. a.known .. " above zero") or "")
    local gap, ratio = A.Gap(s)
    ui.gap:SetText(gap ~= nil and A.Coins(gap) or MISSING)
    Color(ui.gap, gap ~= nil and WHITE or GREY)
    ui.bar:SetWidth(math.max(0.001, ratio and (GAP_BAR_W - 4) * ratio or 0.001))
    ui.bar:SetShown(ratio ~= nil and ratio > 0)
    local over = ratio == 1 and A.Numeric(s, "acquired") > A.Numeric(s, "peak")
    ui.share:SetText(ratio and (math.floor(ratio * 100) .. (over and "%+" or "%") .. " of peak")
        or (gap ~= nil and "Peak is zero" or "A total is missing"))
    Color(ui.share, ratio and WHITE or GREY)
    local profs = A.Professions(s)
    local positive = {}
    for _, p in ipairs(profs) do if p.n and p.n > 0 then positive[#positive + 1] = p end end
    for i, row in ipairs(ui.professions) do
        local p = positive[i]
        row.key = p and p.key
        row.name:SetText(p and (p.label .. (p.highest and "*" or "")) or (i == 1 and "No ranks recorded" or ""))
        row.value:SetText(p and A.Quantity(p.n) or "")
    end
    ui.profNote:SetText(#positive > 4 and ("+" .. (#positive - 4) .. " more on Activity") or "* highest recorded")
    for i, row in ipairs(ui.allProfessions) do
        local p = profs[i]
        row.key = p.key
        row.name:SetText(p.label .. (p.highest and "*" or ""))
        Show(row.value, s, p.key)
    end
    local history = s and self:History(s.guid) or {}
    local entry = s and self.db.characters[s.guid]
    ui.saved.count:SetText(#history .. " / " .. A.MAX_SNAPSHOTS)
    ui.saved.first:SetText(entry and When(entry.firstSeen, "%b %d") or MISSING)
    ui.saved.last:SetText(s and When(s.at, "%b %d") or MISSING)
    ui.saved.build:SetText(s and A.Plain(s.build) or A.Build())
    ui.body:SetShown(tab == "ledger")
    ui.activity:SetShown(tab == "activity")
    ui.history:SetShown(tab == "history")
    if tab == "history" then RenderHistory() end
end

local function SelectTab(key)
    if key == "characters" then A:OpenDirectory() return end
    if A.directoryMode then
        A.status = A.snapshot and (A.snapshot.available .. " / " .. #A.FIELDS .. " statistics read") or ""
    end
    A.directoryMode, A.tab = false, key
    if key == "history" then A.historyPage = 0 end
    A:Render()
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function BuildTop(ledger)
    -- The three big numbers
    local defs = { { "acquired", "Gold acquired", "All time; not profit" },
        { "peak", "Most gold held", "A past high" }, { "wallet", "Current gold", "" } }
    for i, def in ipairs(defs) do
        local x = X0 + (i - 1) * (COL_W + COL_GAP)
        local card = T.Card(ledger, def[2], x, 0, COL_W, 58)
        ui.cards[def[1]] = Label(card, "GameFontHighlightLarge", 12, -24, COL_W - 20)
        local note = Label(card, "GameFontDisableSmall", 12, -42, COL_W - 20)
        note:SetText(def[3])
        if def[1] == "wallet" then
            ui.walletTitle, ui.walletNote = card.title, note
            Help(card, "Current gold", { "The gold in your bags when this was captured. The game doesn't show another player's gold." })
        else
            card.key = def[1]
            card:EnableMouse(true)
            card:SetScript("OnEnter", Explain)
            card:SetScript("OnLeave", HideTip)
        end
    end
    -- What was recorded, in plain counts (hover for the counters)
    local band = CreateFrame("Frame", nil, ledger)
    band:SetPoint("TOPLEFT", X0, -66)
    band:SetSize(PAGE_W, 16)
    band.title = Label(band, "GameFontHighlight", 4, -1, 260)
    band.coverage = Label(band, "GameFontDisableSmall", PAGE_W - 244, -2, 240, "RIGHT")
    Help(band, function() return A.Assess(A.snapshot).title end, function()
        local a = A.Assess(A.snapshot)
        local lines = { a.summary, { a.coverage, 0.8, 0.8, 0.8 }, { A.ASSESSMENT_NOTE, 0.8, 0.85, 0.9 } }
        for _, e in ipairs(a.evidence) do lines[#lines + 1] = { e, 0.8, 0.85, 0.9 } end
        return lines
    end)
    ui.band = band
    -- Peak against gold acquired
    local gl = CreateFrame("Frame", nil, ledger)
    gl:SetPoint("TOPLEFT", X0, -88)
    gl:SetSize(PAGE_W, 16)
    Label(gl, "GameFontNormalSmall", 4, -2, 130, "LEFT", C.gold):SetText("Peak minus acquired")
    ui.gap = Label(gl, "GameFontHighlightSmall", 130, -2, 120)
    local track = CreateFrame("Frame", nil, gl)
    track:SetPoint("TOPLEFT", 260, -1)
    track:SetSize(GAP_BAR_W, 14)
    T.Fill(track, C.field)
    T.Border(track, C.edge)
    ui.bar = track:CreateTexture(nil, "ARTWORK")
    ui.bar:SetPoint("TOPLEFT", 2, -2)
    ui.bar:SetSize(0.001, 10)
    ui.bar:SetColorTexture(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], 1)
    ui.share = Label(gl, "GameFontNormalSmall", 260 + GAP_BAR_W + 8, -2, PAGE_W - 272 - GAP_BAR_W, "RIGHT", WHITE)
    Help(gl, "Peak minus gold acquired", function()
        local lines = { "Most gold ever held minus all gold acquired, never below zero. The bar is acquired gold as a share of peak gold, up to 100%; 100%+ means acquired is more than peak." }
        if A.Gap(A.snapshot) == nil then lines[#lines + 1] = { "Needs both totals; one is missing from this capture.", 0.8, 0.8, 0.8 } end
        lines[#lines + 1] = { A.INCOME_TOTAL_NOTE, 0.8, 0.85, 0.9 }
        lines[#lines + 1] = A.INCOME_TRANSFERS
        lines[#lines + 1] = { A.INCOME_DISCLAIMER, 1, 0.82, 0 }
        return lines
    end)
    -- The disclaimer, big enough to be read; the rest when hovered
    local dis = CreateFrame("Frame", nil, ledger)
    dis:SetPoint("TOPLEFT", X0, -110)
    dis:SetSize(PAGE_W, 34)
    local d = Label(dis, "GameFontNormal", 4, 0, PAGE_W - 8, "LEFT", C.gold)
    d:SetFont(d:GetFont(), 14, "OUTLINE")
    d:SetText(A.INCOME_DISCLAIMER)
    ui.disclaimer = d
    local d2 = Label(dis, "GameFontHighlightSmall", 4, -20, PAGE_W - 8, "LEFT", C.muted)
    d2:SetText("Not proof of innocence or wrongdoing. Hover any number for what it includes.")
    Help(dis, "Reading these numbers", { A.NOT_PROFIT, A.INCOME_SOURCES, A.INCOME_TRANSFERS,
        { A.DISCLAIMER, 1, 0.82, 0 } })
end

local function BuildLedgerTab(body)
    local x1, x2, x3 = X0, X0 + COL_W + COL_GAP, X0 + 2 * (COL_W + COL_GAP)
    Section(body, "Income", x1, LOWER_Y, COL_W, { "looted", "quests", "vendors", "auctions", "daily" })
    Section(body, "Spending", x2, LOWER_Y, COL_W, { "travel", "postage", "barber", "respec" })
    Section(body, "Auctions", x3, LOWER_Y, COL_W, { "posted", "purchases", "largestSale", "largestBid" })
    local y2 = LOWER_Y - 104
    Section(body, "Gameplay", x1, y2, COL_W, { "questCount", "kills", "dungeons", "disenchanted" })
    Heading(body, "Professions", x2, y2, COL_W)
    for i = 1, 4 do ui.professions[i] = Line(body, x2, y2 - 20 - (i - 1) * ROW, COL_W, i, 40) end
    ui.profNote = Label(body, "GameFontDisableSmall", x2 + 4, y2 - 84, COL_W - 8)
    Heading(body, "Saved here", x3, y2, COL_W)
    for i, def in ipairs({ { "count", "Captures", "How many captures of this character are saved (the newest " .. A.MAX_SNAPSHOTS .. " are kept)." },
        { "first", "First seen", "The first capture saved on this computer, not when the character was made." },
        { "last", "Captured", "When the capture shown was taken." },
        { "build", "Game build", "The game version the capture was read with." } }) do
        local r = Line(body, x3, y2 - 20 - (i - 1) * ROW, COL_W, i, 90)
        r.name:SetText(def[2])
        Help(r, def[2], { def[3] })
        ui.saved[def[1]] = r.value
    end
end

local function BuildActivityTab(page)
    local half = (PAGE_W - COL_GAP) / 2
    Section(page, "Play history", X0, LOWER_Y, half, A.ACTIVITY_KEYS, true)
    local x2 = X0 + half + COL_GAP
    Heading(page, "Professions", x2, LOWER_Y, half)
    Label(page, "GameFontDisableSmall", x2 + half - 144, LOWER_Y, 140, "RIGHT"):SetText("* highest recorded")
    for i = 1, #A.PROFESSION_KEYS do ui.allProfessions[i] = Line(page, x2, LOWER_Y - 20 - (i - 1) * ROW, half, i) end
end

local HIST_COLS = { { "time", "Captured", 0, 140, "LEFT" }, { "peak", "Peak gold", 140, 125, "RIGHT" },
    { "acquired", "Gold acquired", 265, 135, "RIGHT" }, { "delta", "Increase", 400, 136, "RIGHT" } }

local function Pager(parent, y, onPrev, onNext, what)
    local prev = Button(parent, "<", 28, onPrev, "The " .. what .. " before.")
    prev:SetPoint("TOPLEFT", X0, y)
    local page = Label(parent, "GameFontHighlightSmall", X0 + 30, y - 5, 56, "CENTER")
    local nxt = Button(parent, ">", 28, onNext, "The " .. what .. " after.")
    nxt:SetPoint("TOPLEFT", X0 + 88, y)
    return prev, page, nxt
end

local function BuildHistoryTab(h)
    h.rows = {}
    h.caption = Heading(h, "", X0, LOWER_Y, PAGE_W)
    for _, c in ipairs(HIST_COLS) do
        Label(h, "GameFontNormalSmall", X0 + c[3] + 4, LOWER_Y - 22, c[4] - 8, c[5], C.gold):SetText(c[2])
    end
    for i = 1, HIST_ROWS do
        local row = CreateFrame("Frame", nil, h)
        row:SetPoint("TOPLEFT", X0, LOWER_Y - 38 - (i - 1) * 17)
        row:SetSize(PAGE_W, 17)
        if i % 2 == 1 then Fill(row, 0, 0, PAGE_W, 17, { 1, 1, 1, 0.04 }) end
        local cells = { frame = row }
        for _, c in ipairs(HIST_COLS) do cells[c[1]] = Label(row, "GameFontHighlightSmall", c[3] + 4, -3, c[4] - 8, c[5]) end
        h.rows[i] = cells
    end
    local y = LOWER_Y - 38 - HIST_ROWS * 17 - 6
    h.prev, h.page, h.next = Pager(h, y, function() A.historyPage = (A.historyPage or 0) - 1 RenderHistory() end,
        function() A.historyPage = (A.historyPage or 0) + 1 RenderHistory() end, "page")
    local note = Label(h, "GameFontDisableSmall", X0 + 130, y - 5, PAGE_W - 134, "RIGHT")
    note:SetText("Increase: gold acquired since the capture before")
    local hit = CreateFrame("Frame", nil, h)
    hit:SetPoint("TOPLEFT", X0 + 130, y)
    hit:SetSize(PAGE_W - 130, 22)
    Help(hit, "Increase", { "How much the gold acquired total went up since the capture before. Nothing is shown across a game update or when the total went down (a counter reset)." })
end

local DIR_COLS = { { "name", "Character", 0, 168, "LEFT" }, { "level", "Lvl", 168, 40, "CENTER" },
    { "peak", "Peak gold", 208, 104, "RIGHT" }, { "acquired", "Acquired", 312, 104, "RIGHT" },
    { "lastSeen", "Seen", 416, 70, "RIGHT" }, { "count", "Saves", 486, 50, "RIGHT" } }

local DIR_TIPS = { name = "Sort by name.", level = "Sort by level.", peak = "Sort by the most gold ever held.",
    acquired = "Sort by all gold acquired.", lastSeen = "Sort by when they were last captured.",
    count = "Sort by how many captures are saved." }

local function BuildDirectory(d)
    d.rows, d.headers = {}, {}
    d.search = T.EditBox(d, 240)
    d.search:SetPoint("TOPLEFT", X0, 0)
    d.search:SetMaxLetters(100)
    d.hint = Label(d.search, "GameFontDisableSmall", 6, -6, 220)
    d.hint:SetText("Search name, realm, guild or class")
    d.search:SetScript("OnTextChanged", function(self)
        A.directoryQuery = self:GetText()
        d.hint:SetShown(A.directoryQuery == "")
        A.directoryPage = 0
        RenderDirectory()
    end)
    T.Tooltip(d.search, "Search", "Shows only the characters whose name, realm, guild or class contains this text.")
    d.caption = Label(d, "GameFontHighlightSmall", PAGE_W - 200, -5, 200, "RIGHT")
    for _, c in ipairs(DIR_COLS) do
        local key = c[1]
        local b = CreateFrame("Button", nil, d)
        b:SetPoint("TOPLEFT", X0 + c[3], -30)
        b:SetSize(c[4], 20)
        T.Fill(b, C.card)
        b.label = Label(b, "GameFontNormalSmall", 4, -4, c[4] - 20, c[5])
        b.label:SetText(c[2])
        b.arrow = T.MenuArrow(b, 3)
        b:SetScript("OnClick", function() A:SortDirectory(key) RenderDirectory() end)
        T.Tooltip(b, c[2], DIR_TIPS[key] .. " Click again to reverse. Missing numbers always go last.")
        d.headers[key] = b
    end
    for i = 1, DIR_ROWS do
        local row = CreateFrame("Button", nil, d)
        row:SetPoint("TOPLEFT", X0, -52 - (i - 1) * DIR_ROW_H)
        row:SetSize(PAGE_W, DIR_ROW_H)
        if i % 2 == 1 then Fill(row, 0, 0, PAGE_W, DIR_ROW_H, { 1, 1, 1, 0.04 }) end
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.07)
        row:SetScript("OnClick", function(self) if self.guid then A:OpenSaved(self.guid) end end)
        row.name = Label(row, "GameFontHighlight", 6, -1, 160)
        row.realm = Label(row, "GameFontDisableSmall", 6, -14, 160)
        local function cell(k)
            for _, c in ipairs(DIR_COLS) do
                if c[1] == k then return Label(row, "GameFontHighlightSmall", c[3] + 4, -8, c[4] - 8, c[5]) end
            end
        end
        row.level, row.peak, row.acquired = cell("level"), cell("peak"), cell("acquired")
        row.lastSeen, row.count = cell("lastSeen"), cell("count")
        Color(row.lastSeen, C.muted)
        d.rows[i] = row
    end
    d.empty = Label(d, "GameFontDisable", 30, -140, PAGE_W - 60, "CENTER")
    d.empty:SetWordWrap(true)
    local y = -52 - DIR_ROWS * DIR_ROW_H - 6
    d.prev, d.page, d.next = Pager(d, y, function() A.directoryPage = (A.directoryPage or 0) - 1 RenderDirectory() end,
        function() A.directoryPage = (A.directoryPage or 0) + 1 RenderDirectory() end, "page")
    Label(d, "GameFontDisableSmall", X0 + 130, y - 5, PAGE_W - 134, "RIGHT")
        :SetText(A.MAX_SNAPSHOTS .. " captures kept per character, on this computer only")
    d:SetScript("OnHide", function() d.search:ClearFocus() end)
end

local function Build()
    w = CreateFrame("Frame", "ARSForeverLedger", UIParent)
    A.ledger = w
    w:SetSize(W, H)
    w:SetPoint("CENTER")
    w:SetFrameStrata("DIALOG")
    w:SetToplevel(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:EnableMouse(true)
    w:Hide()
    table.insert(UISpecialFrames, "ARSForeverLedger")
    T.Fill(w, C.win)
    T.Border(w, C.edge)
    ui = { groups = {}, cards = {}, professions = {}, allProfessions = {}, saved = {}, tabs = {} }

    -- Header: drag to move
    local header = CreateFrame("Frame", nil, w)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() w:StartMoving() end)
    header:SetScript("OnDragStop", function()
        w:StopMovingOrSizing()
        local point, _, relative, x, y = w:GetPoint()
        if type(point) == "string" and type(x) == "number" then
            A.db.position = { point = point, relative = relative or point, x = x, y = y }
        end
    end)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    T.HeaderGradient(hbg)
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("LEFT", 10, 0)
    logo:SetTexture(T.LOGO)
    ui.name = Label(header, "GameFontNormalLarge", 58, -10, 300, "LEFT", C.title)
    ui.name:SetFont(ui.name:GetFont(), 17, "")
    ui.identity = Label(header, "GameFontHighlightSmall", 58, -32, 300, "LEFT", C.muted)
    local x = T.FlatButton(header, "X", 22, 22)
    x:SetPoint("TOPRIGHT", -8, -8)
    x:SetScript("OnClick", function() w:Hide() end)
    local opts = T.FlatButton(header, "Options", 64, 22)
    opts:SetPoint("RIGHT", x, "LEFT", -4, 0)
    opts:SetScript("OnClick", function() A:OpenOptions() end)
    T.Tooltip(opts, "Options", "Open the options window.")
    ui.auto = T.SwitchWidget(header)
    ui.auto:SetPoint("TOPRIGHT", -112, -34)
    local autoLabel = Label(header, "GameFontHighlightSmall", W - 106, -35, 100)
    autoLabel:SetText("With Inspect")
    T.ClickableLabel(ui.auto, autoLabel)
    ui.auto:SetScript("OnClick", function()
        A.db.autoInspect = not A.db.autoInspect
        A:Changed()
    end)
    T.Tooltip(ui.auto, "Open with Inspect", "Opens this ledger beside the Inspect window whenever you inspect a player, and reads their statistics.")

    -- Tabs under the header
    local tabW = 100
    for i, def in ipairs(TAB_LIST) do
        local b = CreateFrame("Button", nil, w)
        b:SetSize(tabW, TABS_H)
        b:SetPoint("TOPLEFT", X0 + (i - 1) * (tabW + 4), -HEADER)
        b.selBg = b:CreateTexture(nil, "BACKGROUND")
        b.selBg:SetAllPoints()
        b.selBg:SetColorTexture(unpack(C.tabOn))
        b.accent = b:CreateTexture(nil, "ARTWORK")
        b.accent:SetPoint("BOTTOMLEFT")
        b.accent:SetPoint("BOTTOMRIGHT")
        b.accent:SetHeight(2)
        b.accent:SetColorTexture(unpack(C.accent))
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.05)
        b.label = Label(b, "GameFontHighlight", 0, -8, tabW, "CENTER")
        b.label:SetText(def[2])
        b:SetScript("OnClick", function() SelectTab(def[1]) end)
        ui.tabs[def[1]] = b
    end
    local tline = w:CreateTexture(nil, "BORDER")
    tline:SetPoint("TOPLEFT", 1, -(HEADER + TABS_H))
    tline:SetPoint("TOPRIGHT", -1, -(HEADER + TABS_H))
    tline:SetHeight(1)
    tline:SetColorTexture(unpack(C.line))

    -- Red strip, only when a read failed
    local err = CreateFrame("Frame", nil, w)
    err:SetPoint("TOPLEFT", X0, -(HEADER + TABS_H + 6))
    err:SetSize(PAGE_W, ERROR_H - 8)
    T.Fill(err, { 0.2, 0.04, 0.03, 1 })
    T.Border(err, C.accent)
    err.title = Label(err, "GameFontNormal", 10, -5, PAGE_W - 20, "LEFT", RED)
    err.detail = Label(err, "GameFontHighlightSmall", 10, -23, PAGE_W - 20, "LEFT", RED)
    ui.err = err

    ui.content = CreateFrame("Frame", nil, w)
    ui.ledger = CreateFrame("Frame", nil, ui.content)
    ui.ledger:SetAllPoints()
    BuildTop(ui.ledger)
    ui.body = CreateFrame("Frame", nil, ui.ledger)
    ui.body:SetAllPoints()
    BuildLedgerTab(ui.body)
    ui.activity = CreateFrame("Frame", nil, ui.ledger)
    ui.activity:SetAllPoints()
    BuildActivityTab(ui.activity)
    ui.history = CreateFrame("Frame", nil, ui.ledger)
    ui.history:SetAllPoints()
    BuildHistoryTab(ui.history)
    ui.directory = CreateFrame("Frame", nil, ui.content)
    ui.directory:SetAllPoints()
    BuildDirectory(ui.directory)

    -- Status (left) and age (right), then the source line, above the footer
    ui.status = Label(w, "GameFontHighlightSmall", 0, 0, PAGE_W - 150)
    ui.status:ClearAllPoints()
    ui.status:SetPoint("BOTTOMLEFT", X0 + 4, FOOTER + 20)
    ui.age = Label(w, "GameFontHighlightSmall", 0, 0, 150, "RIGHT")
    ui.age:ClearAllPoints()
    ui.age:SetPoint("BOTTOMRIGHT", -X0 - 4, FOOTER + 20)
    local srcHit = CreateFrame("Frame", nil, w)
    srcHit:SetPoint("BOTTOMLEFT", X0 + 4, FOOTER + 4)
    srcHit:SetSize(PAGE_W - 8, 14)
    ui.source = Label(srcHit, "GameFontDisableSmall", 0, 0, PAGE_W - 8)
    Help(srcHit, "Where the numbers come from", function()
        local st = A.SourceStatus(not A.directoryMode and A.snapshot or nil)
        local lines = { A.DATA_SOURCE_NOTICE,
            { "Game build: " .. tostring(st.client) .. "  -  statistic list checked for " .. st.definitions, 0.8, 0.8, 0.8 } }
        if st.reason then lines[#lines + 1] = { "WARNING: " .. st.reason, 1, 0.35, 0.3 } end
        if st.note then lines[#lines + 1] = { st.note, 0.8, 0.8, 0.8 } end
        lines[#lines + 1] = { A.DATA_SOURCE_VERIFY, 1, 0.82, 0 }
        lines[#lines + 1] = { A.DISCLAIMER, 1, 0.82, 0 }
        return lines
    end)

    -- Footer buttons: who on the left, the capture on the right
    local foot = CreateFrame("Frame", nil, w)
    foot:SetPoint("BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(FOOTER)
    T.Fill(foot, C.side)
    local fline = foot:CreateTexture(nil, "BORDER")
    fline:SetPoint("TOPLEFT")
    fline:SetPoint("TOPRIGHT")
    fline:SetHeight(1)
    fline:SetColorTexture(unpack(C.line))
    local me = Button(foot, "My character", 100, function() A:Audit("player", "button") end,
        "Read your own statistics and current gold.")
    me:SetPoint("LEFT", 12, 0)
    local target = Button(foot, "Target", 64, function() A:Audit("target", "button") end,
        "Read your target's statistics. They need to be a player close enough to inspect.")
    target:SetPoint("LEFT", me, "RIGHT", 6, 0)
    local refresh = Button(foot, "Refresh", 70, function() A:Refresh() end,
        "Read the player shown again. A saved player needs to be your target and nearby.")
    refresh:SetPoint("LEFT", target, "RIGHT", 6, 0)
    ui.save = Button(foot, "Save", 60, function()
        if not A.snapshot then A:Update("Read a character first.")
        elseif A:Save(A.snapshot) then A:Update("Saved.")
        else A:Update("This capture is already saved. Refresh to read the player again.") end
    end, "Captures save by themselves; this saves the one shown if it isn't yet. It doesn't read the player again.")
    ui.save:SetPoint("RIGHT", -12, 0)
    ui.copy = Button(foot, "Copy report", 96, function() A:OpenReport() end,
        "Opens the capture as plain text you can copy. Nothing is posted to chat.")
    ui.copy:SetPoint("RIGHT", ui.save, "LEFT", -6, 0)
    ui.me, ui.target, ui.refresh = me, target, refresh

    w:SetScript("OnHide", function()
        A:Cancel(nil)
        if A.reportWindow then A.reportWindow:Hide() end
    end)
    A.ledgerUI = ui
end

-- Size: the setting, but never bigger than the screen
function A:FitLedger()
    if not w then return end
    local h = w:GetHeight() or H
    local scale = math.min(self.db.scale, ((UIParent:GetWidth() or 1024) - 24) / W, ((UIParent:GetHeight() or 768) - 24) / h)
    w:SetScale(scale)
end

function A:ShowLedger(origin)
    if not w then Build() end
    self:FitLedger()
    w:ClearAllPoints()
    local p = self.db.position
    if origin == "inspect" and InspectFrame and InspectFrame:IsShown() then
        -- Always beside Inspect (Forever IRS stopped doing this once you'd
        -- dragged its window anywhere)
        w:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT", 12, 0)
    elseif p then
        if not pcall(w.SetPoint, w, p.point, UIParent, p.relative, p.x, p.y) then w:SetPoint("CENTER") end
    else
        w:SetPoint("CENTER")
    end
    w:Show()
    w:Raise()
    self:Render()
end
