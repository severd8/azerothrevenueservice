-- ARS Forever: welcome / "What's new" window. Shows once after each update
-- (and on first install), unless turned off. /ars news opens it anytime.

local _, ns = ...
local A = ns.ARS
local T = ns.Theme
local C = T.C

local WIDTH, HEIGHT = 620, 520
local BANNER_H = 120
local MAX_NEWS = 6

local splash

function A:CurrentNewsVersion()
    return self.NEWS and self.NEWS[1] and self.NEWS[1].version
end

local ORANGE, GOLD, BLUE, GREY = "|cffff9a2a", "|cffffd100", "|cff8fd3ff", "|cffbbbbbb"

local function BuildText()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local top = A.NEWS and A.NEWS[1]
    if top then
        add(GOLD .. "v" .. top.version .. "|r " .. GREY .. "(" .. top.date .. ")|r")
        add(" ")
    end
    add(ORANGE .. "# Quick start|r")
    add("- |cffffffffInspect a player|r and the ledger opens beside the Inspect window")
    add("- " .. BLUE .. "/ars|r  your target's ledger (or yours)      " .. BLUE .. "/ars history|r  saved characters")
    add("- " .. BLUE .. "/ars options|r  options      " .. BLUE .. "/ars news|r  this window again")
    add("- Gold acquired isn't profit, and peak gold isn't what someone has now.")
    add(" ")
    add(ORANGE .. "# What's new|r")
    local count = 0
    for _, entry in ipairs(A.NEWS or {}) do
        for _, item in ipairs(entry.items) do
            if count >= MAX_NEWS then break end
            add("- " .. GOLD .. "v" .. entry.version .. "|r  " .. item)
            count = count + 1
        end
        if count >= MAX_NEWS then break end
    end
    add(" ")
    add(ORANGE .. "# Support|r")
    add("Found a bug? Report it on GitHub (link on the CurseForge page).")
    add("Enjoying the addon? Tips on Ko-fi keep it updated: ko-fi.com/tauntmasterforever")
    return table.concat(lines, "\n")
end

local function Build()
    splash = CreateFrame("Frame", "ARSForeverSplash", UIParent)
    A.splash = splash
    splash:SetSize(WIDTH, HEIGHT)
    splash:SetPoint("CENTER", 0, 40)
    splash:SetFrameStrata("DIALOG")
    splash:SetToplevel(true)
    splash:SetClampedToScreen(true)
    splash:SetMovable(true)
    splash:EnableMouse(true)
    splash:RegisterForDrag("LeftButton")
    splash:SetScript("OnDragStart", splash.StartMoving)
    splash:SetScript("OnDragStop", splash.StopMovingOrSizing)
    splash:Hide()
    table.insert(UISpecialFrames, "ARSForeverSplash")   -- Escape closes it
    T.Fill(splash, C.win)
    T.Border(splash, C.edge)

    local banner = splash:CreateTexture(nil, "BORDER")
    banner:SetPoint("TOPLEFT", 1, -1)
    banner:SetPoint("TOPRIGHT", -1, -1)
    banner:SetHeight(BANNER_H)
    T.HeaderGradient(banner)
    local line = splash:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", banner, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", banner, "BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(unpack(C.edge))

    local logo = splash:CreateTexture(nil, "ARTWORK")
    logo:SetSize(96, 96)
    logo:SetPoint("TOPLEFT", 18, -12)
    logo:SetTexture(T.LOGO)
    local title = T.Text(splash, T.NAME, "GameFontNormalHuge", { 0.95, 0.9, 0.78 }, 30)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 18, -18)
    local sub = T.Text(splash, "Azeroth Revenue Service: gold statistics for WoW: Forever", "GameFontNormal", C.orange)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -10)

    local x = T.FlatButton(splash, "X", 24, 24)
    x:SetPoint("TOPRIGHT", -12, -12)
    x:SetScript("OnClick", function() splash:Hide() end)

    -- The text scrolls with the mouse wheel
    local area = CreateFrame("Frame", nil, splash)
    area:SetPoint("TOPLEFT", 22, -(BANNER_H + 16))
    area:SetPoint("BOTTOMRIGHT", -16, 50)
    local scroll = T.ScrollArea(area, HEIGHT - BANNER_H - 66)
    local text = T.Text(scroll.child, "", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetWidth(WIDTH - 60)
    text:SetSpacing(3)
    splash.text, splash.scroll = text, scroll

    local sep = splash:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT", 1, 40)
    sep:SetPoint("BOTTOMRIGHT", -1, 40)
    sep:SetHeight(1)
    sep:SetColorTexture(unpack(C.line))

    local sw, label = T.LabeledSwitch(splash, "Show this after updates", 16, -(HEIGHT - 28))
    label:SetFontObject(GameFontHighlightSmall)
    sw:SetScript("OnClick", function(self)
        A.db.showSplash = not A.db.showSplash
        self:SetOn(A.db.showSplash)
        if A.RefreshOptions then A:RefreshOptions() end
    end)
    T.Tooltip(sw, "Show this after updates", "Opens this window once after each update. /ars news opens it anytime.")
    splash.check = sw

    local done = T.FlatButton(splash, "Close", 90)
    done:SetPoint("BOTTOMRIGHT", -14, 10)
    done:SetScript("OnClick", function() splash:Hide() end)
    local notes = T.Text(splash, "Full release notes on CurseForge", "GameFontNormalSmall", C.orange)
    notes:SetPoint("RIGHT", done, "LEFT", -12, 0)
end

function A:ShowSplash()
    if not splash then Build() end
    splash.text:SetText(BuildText())
    splash.scroll:SetContent(WIDTH - 60, (splash.text:GetStringHeight() or 0) + 10)
    splash.check:SetOn(self.db.showSplash)
    self.db.lastSeenVersion = self:CurrentNewsVersion()
    splash:Show()
    splash:Raise()
end

-- On login: once per new version (and on first install), a few seconds in
function A:MaybeShowSplash()
    local current = self:CurrentNewsVersion()
    if not current or not self.db.showSplash or self.db.lastSeenVersion == current then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(4, function() A:ShowSplash() end)
    else
        self:ShowSplash()
    end
end
