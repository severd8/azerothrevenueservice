-- ARS Forever: the options window (/ars options), built with Theme.Window.
-- Every control has hover help and applies the moment it changes.

local _, ns = ...
local A = ns.ARS
local T = ns.Theme
local C = T.C

local PAGE_W = T.WINDOW.PAGE_W
local refreshers = {}
A.OPTION_TABS = { "general", "data" }
A.optionsUI = {}   -- the controls, for the tests

local function Refresh()
    for _, fn in ipairs(refreshers) do fn() end
end

function A:RefreshOptions()
    if self.options and self.options:IsShown() then Refresh() end
end

-- "Are you sure?" with a themed window
function A:Confirm(text, yesLabel, onYes)
    local f = self.confirmWindow
    if not f then
        f = CreateFrame("Frame", "ARSForeverConfirm", UIParent)
        f:SetSize(380, 130)
        f:SetPoint("CENTER", 0, 80)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:Hide()
        table.insert(UISpecialFrames, "ARSForeverConfirm")   -- Escape is Cancel
        T.Fill(f, C.win)
        T.Border(f, C.edge)
        f.text = T.Text(f, "", "GameFontHighlight")
        f.text:SetPoint("TOPLEFT", 16, -16)
        f.text:SetWidth(348)
        f.text:SetWordWrap(true)
        f.no = T.FlatButton(f, "Cancel", 100)
        f.no:SetPoint("BOTTOMRIGHT", -16, 14)
        f.no:SetScript("OnClick", function() f:Hide() end)
        f.yes = T.FlatButton(f, "", 140)
        f.yes:SetPoint("RIGHT", f.no, "LEFT", -8, 0)
        self.confirmWindow = f
    end
    f.text:SetText(text)
    f.yes:SetText(yesLabel)
    f.yes:SetScript("OnClick", function()
        f:Hide()
        onYes()
    end)
    f:Show()
    f:Raise()
    return f
end

-- A switch bound to a setting. enabledWhen: optional, greys it out when false.
local function Switch(parent, key, text, tip, x, y, enabledWhen)
    local b = T.LabeledSwitch(parent, text, x, y)
    b:SetScript("OnClick", function(self)
        if self.disabled then return end
        A.db[key] = not A.db[key]
        A:Changed()
    end)
    T.Tooltip(b, text, tip)
    b.tip = tip
    refreshers[#refreshers + 1] = function()
        b:SetOn(A.db[key])
        if enabledWhen then b:SetDisabled(not enabledWhen()) end
    end
    A.optionsUI[key] = b
    return b
end

local function Button(parent, text, width, tip, onClick, enabledWhen)
    local b = T.FlatButton(parent, text, width, 22)
    T.Disabler(b, { b })
    b:SetScript("OnClick", function(self) if not self.disabled then onClick() end end)
    T.Tooltip(b, text, tip)
    b.tip = tip
    if enabledWhen then
        refreshers[#refreshers + 1] = function() b:SetDisabled(not enabledWhen()) end
    end
    return b
end

local function BuildGeneral(p)
    local ui = A.optionsUI
    local card = T.Card(p, "Inspect window", 0, 0, PAGE_W, 92)
    Switch(card, "autoInspect", "Open beside the Inspect window",
        "When you inspect a player, the ledger opens beside the Inspect window and reads their statistics. Off: use the ARS button or /ars instead.",
        16, -32)
    Switch(card, "inspectButton", "ARS button on the Inspect window",
        "A small ARS button under the Inspect window that opens the ledger for the player inspected.", 16, -60)

    card = T.Card(p, "Ledger window", 0, -100, PAGE_W, 76)
    local s = T.Slider(card, "Size", 16, -30, 300, function() return math.floor(A.db.scale * 100 + 0.5) end,
        function(v) A.db.scale = v / 100 A:Changed() end, 60, 160, "%", 5)
    T.Tooltip(s, "Size", "How big the ledger window is drawn. It never grows bigger than your screen.")
    s.tip = "size"
    refreshers[#refreshers + 1] = s.Refresh
    ui.scale = s
    local reset = Button(card, "Move to the middle", 150, "Puts the ledger back in the middle of the screen, if it's been dragged somewhere awkward.", function()
        A:Command("reset")
    end)
    reset:SetPoint("TOPLEFT", 360, -36)
    ui.moveLedger = reset

    card = T.Card(p, "More", 0, -184, PAGE_W, 92)
    Switch(card, "minimapButton", "Minimap button",
        "The ARS button on the minimap. Left-click: your target's ledger (or yours). Right-click: these options. Drag it to move it.", 16, -32)
    Switch(card, "showSplash", "Welcome screen after updates",
        "Opens the welcome window once after each update, with what's new. /ars news opens it anytime.", 16, -60)

    ui.restore = Button(p, "Restore defaults", 150,
        "Puts every setting on this page back to how it started. Your saved characters, the minimap button's place and the Characters tab's sort order are kept.",
        function()
            A:Confirm("Put every setting on this page back to how it started? Saved characters are kept.", "Restore defaults", function()
                A:RestoreDefaults()
            end)
        end)
    ui.restore:SetPoint("TOPLEFT", 0, -290)
end

local function BuildData(p)
    local ui = A.optionsUI
    local card = T.Card(p, "Saved characters", 0, 0, PAGE_W, 100)
    local count = T.Note(card, "", 16, -32, PAGE_W - 32)
    count:SetFontObject(GameFontHighlight)
    refreshers[#refreshers + 1] = function()
        local n, caps = A:CharacterCount()
        count:SetText(("%d characters, %d captures, on this computer only. The newest %d captures of each are kept.")
            :format(n, caps, A.MAX_SNAPSHOTS))
    end
    ui.count = count
    ui.openList = Button(card, "Open the list", 130, "Opens the ledger's Characters tab.", function() A:OpenDirectory() end)
    ui.openList:SetPoint("TOPLEFT", 16, -64)
    ui.clear = Button(card, "Delete saved history", 160,
        "Deletes every saved character and capture. Settings are kept. This can't be undone.",
        function()
            A:Confirm("Delete every saved character and capture? This can't be undone.", "Delete history", function()
                A:ClearHistory()
                A.Print("saved history deleted.")
            end)
        end, function() return next(A.db.characters) ~= nil end)
    ui.clear:SetPoint("TOPLEFT", 154, -64)

    card = T.Card(p, "From Forever IRS", 0, -108, PAGE_W, 108)
    local note = T.Note(card, "", 16, -30, PAGE_W - 32)
    refreshers[#refreshers + 1] = function()
        if A:IRSData() then
            note:SetText(A.db.importedIRS and "Forever IRS's history has been brought in. Bringing it in again only adds captures that are missing."
                or "Forever IRS's history is loaded and can be brought in now.")
        else
            note:SetText("To bring in Forever IRS's saved history, turn Forever IRS on in the AddOns list and log in (it happens by itself on that login). Then you can turn it off.")
        end
    end
    ui.irsNote = note
    ui.import = Button(card, "Bring in Forever IRS history", 210,
        "Adds Forever IRS's saved characters and captures to ARS's. Nothing is lost or doubled. Greyed out while Forever IRS isn't turned on.",
        function() A:ImportIRS() Refresh() end, function() return A:IRSData() ~= nil end)
    ui.import:SetPoint("TOPLEFT", 16, -72)

    card = T.Card(p, "Checks", 0, -224, PAGE_W, 84)
    T.Note(card, "These print to your chat window.", 16, -30)
    ui.check = Button(card, "Check statistics", 140,
        "Lists every statistic the addon reads, by ID, with the game's own name for it, so missing or renamed ones show up. Same as /ars check.",
        function() A:Check() end)
    ui.check:SetPoint("TOPLEFT", 16, -50)
    ui.status = Button(card, "Status", 90, "Versions, whether the game's statistics functions are there, and what's happening now. Same as /ars status.",
        function() A:Status() end)
    ui.status:SetPoint("TOPLEFT", 164, -50)
end

local function Build()
    A.options = T.Window({
        name = "ARSForeverOptions",
        hint = "/ars options opens this window",
        version = function() return A:Version() end,
        tabs = {
            { key = "general", label = "General", icon = "Interface\\Icons\\INV_Misc_Gear_01", build = BuildGeneral },
            { key = "data", label = "Saved data", icon = "Interface\\Icons\\INV_Misc_Book_09", build = BuildData },
        },
        onShow = Refresh,
        onTab = Refresh,
    })
end

function A:OpenOptions(tab)
    if not self.options then Build() end
    self.options:Show()
    self.options:Raise()
    self.options:ShowTab(tab or self.options.currentTab or "general")
    Refresh()
end
