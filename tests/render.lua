-- Lays out ARS Forever's windows outside the game and writes them to JSON, so
-- tests/render.py can draw them as images for a visual check.
-- From the repo root:  lua5.1 tests/render.lua out.json && python3 tests/render.py out.json outdir
-- Not shipped (the tests folder is left out of the download).

ADDON_DIR = "."
dofile("tests/wowstub.lua")
local M = STUB_METHODS

---------------------------------------------------------------------------
-- Track layout on the fake frames
---------------------------------------------------------------------------
local baseSetPoint, baseSetSize = M.SetPoint, M.SetSize
function M:SetPoint(p, rel, rp, x, y)
    baseSetPoint(self, p, rel, rp, x, y)
    local a
    if type(rel) == "table" then
        a = { p = p, rel = rel, rp = rp or p, x = x or 0, y = y or 0 }
    elseif type(rel) == "string" then
        a = { p = p, rp = rel, x = rp or 0, y = x or 0 }
    else
        a = { p = p, rp = p, x = rel or 0, y = rp or 0 }
    end
    self.__pts = self.__pts or {}
    for i, old in ipairs(self.__pts) do
        if old.p == p then table.remove(self.__pts, i) break end
    end
    table.insert(self.__pts, a)
end
local baseClear = M.ClearAllPoints
function M:ClearAllPoints() baseClear(self) self.__pts = {} end
function M:SetAllPoints(rel)
    rel = type(rel) == "table" and rel or nil
    self.__pts = { { p = "TOPLEFT", rel = rel, rp = "TOPLEFT", x = 0, y = 0 },
        { p = "BOTTOMRIGHT", rel = rel, rp = "BOTTOMRIGHT", x = 0, y = 0 } }
end
function M:SetSize(w, h) baseSetSize(self, w, h) self.__w, self.__h = w, h end
function M:SetWidth(w) self.__w = (w ~= 0 or self.__kind ~= "FontString") and w or nil end
function M:SetHeight(h) self.__h = h end
function M:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a or 1 } end
function M:SetGradient(_, from) self.__color = { from.r, from.g, from.b, from.a or 1 } end
function M:SetTextColor(r, g, b) self.__tcolor = r and { r, g, b } or nil end
function M:SetJustifyH(j) self.__justify = j end
function M:SetFont(_, size) self.__fsize = size end
function M:SetFontObject(f) self.__font = "GameFontHighlightSmall" end
function M:SetScrollChild(ch)
    ch.__pts = { { p = "TOPLEFT", rel = self, rp = "TOPLEFT", x = 0, y = 0 } }
    ch.__scrollOf = self
end
function M:SetWordWrap(v) self.__wrap = v end
function M:SetFontString(fs) self.__fontString = fs end
local baseSetText = M.SetText
function M:SetText(t)
    baseSetText(self, t)
    if self.__fontString then self.__fontString.__text = self.__text end
end

local FONT_SIZES = { GameFontNormal = 12, GameFontHighlight = 12, GameFontNormalSmall = 10,
    GameFontHighlightSmall = 10, GameFontDisableSmall = 10, GameFontNormalLarge = 16, GameFontHighlightLarge = 16,
    GameFontDisable = 12, GameFontNormalHuge = 20 }
local function FontSize(o) return o.__fsize or FONT_SIZES[o.__font or ""] or 12 end
local function Plain(t)
    t = tostring(t or "")
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    t = t:gsub("|TInterface\\MoneyFrame\\UI%-GoldIcon[^|]*|t", "g"):gsub("|TInterface\\MoneyFrame\\UI%-SilverIcon[^|]*|t", "s")
        :gsub("|TInterface\\MoneyFrame\\UI%-CopperIcon[^|]*|t", "c"):gsub("|T.-|t", "  "):gsub("||", "|")
    return t
end
local function TextWidth(o) return #Plain(o.__text) * FontSize(o) * 0.56 end
function M:GetStringWidth() return TextWidth(self) end
function M:GetStringHeight()
    local size = FontSize(self)
    local w = self.__w
    if not w or w <= 0 then return size end
    local lines = math.max(1, math.ceil(TextWidth(self) / w))
    return lines * (size + 2)
end

---------------------------------------------------------------------------
-- Load the addon with some saved characters
---------------------------------------------------------------------------
local ADDON = "ARSForever"
local ns = LoadAddon(".")
local A = ns.ARS
for _, f in ipairs(A.FIELDS) do STAT_NAMES[f[2]] = f[3] end

local function Stats(t)
    local out = {}
    for _, f in ipairs(A.FIELDS) do out[f[2]] = t[f[1]] end
    return out
end
local G = 10000
STATS_SELF = Stats({ acquired = 48213 * G + 512, peak = 9120 * G, looted = 6021 * G, quests = 3410 * G, vendors = 5230 * G,
    auctions = 30122 * G, daily = 312 * G, travel = 410 * G, postage = 12 * G, barber = 3 * G, respec = 85 * G,
    posted = 1840, purchases = 512, largestSale = 1200 * G, largestBid = 450 * G, questCount = 812, kills = 23412,
    dungeons = 214, deaths = 96, disenchanted = 1420, disenchantMaterials = 2611, fishCaught = 340, flights = 602,
    honorableKills = 1210, firstAid = 300, cooking = 285, fishing = 150, enchanting = 300, tailoring = 300 })
UNITS.target = { guid = "Player-1-00000002", name = "Goldbeard", realm = "Forever", class = "Warrior", classFile = "WARRIOR",
    level = 60, guild = "Iron Vault", player = true }
STATS_OTHER["Player-1-00000002"] = Stats({ acquired = 152003 * G, peak = 61000 * G, looted = 2100 * G, quests = 900 * G,
    vendors = 1400 * G, auctions = 140210 * G, travel = 90 * G, postage = 41 * G, posted = 9100, purchases = 7400,
    largestSale = 5200 * G, largestBid = 3100 * G, questCount = 120, kills = 3010, dungeons = 12, deaths = 40,
    mining = 300, herbalism = 300 })

FireEvent("ADDON_LOADED", ADDON)
FireEvent("PLAYER_LOGIN")
-- A few earlier captures and other characters
local function Saved(guid, name, class, file, level, at, acq, peak)
    A:Save({ guid = guid, name = name, realm = "Forever", class = class, classFile = file, level = level, at = at,
        build = "1.60.1.70532", own = false, values = { acquired = { number = acq }, peak = { number = peak } },
        unavailable = {}, available = 2 })
end
for i = 1, 6 do
    Saved("Player-1-00000002", "Goldbeard", "Warrior", "WARRIOR", 60, SERVER_TIME - (7 - i) * 86400 * 3,
        (152003 - (7 - i) * 9000) * G, 61000 * G)
end
Saved("Player-1-00000003", "Coinpurse", "Priest", "PRIEST", 58, SERVER_TIME - 86400 * 2, 21000 * G, 4800 * G)
Saved("Player-1-00000004", "Mallory", "Hunter", "HUNTER", 44, SERVER_TIME - 86400 * 9, 3900 * G, 1200 * G)
Saved("Player-1-00000005", "Quillon", "Mage", "MAGE", 60, SERVER_TIME - 3600 * 5, 88000 * G, 30500 * G)

---------------------------------------------------------------------------
-- Resolve rectangles (WoW coordinates: y grows upward) and dump them
---------------------------------------------------------------------------
local SW, SH = 1400, 1000
local function Resolve(o, cache)
    if o == UIParent or o == nil then return { l = 0, r = SW, t = SH, b = 0 } end
    if cache[o] then return cache[o] end
    cache[o] = { l = 0, r = 0, t = 0, b = 0 }
    local l, r, t, b, cx, cy
    for _, a in ipairs(o.__pts or {}) do
        local rr = Resolve(a.rel or o.__parent, cache)
        local px = a.rp:find("LEFT") and rr.l or a.rp:find("RIGHT") and rr.r or (rr.l + rr.r) / 2
        local py = a.rp:find("TOP") and rr.t or a.rp:find("BOTTOM") and rr.b or (rr.t + rr.b) / 2
        px, py = px + a.x, py + a.y
        if a.p:find("LEFT") then l = px elseif a.p:find("RIGHT") then r = px else cx = px end
        if a.p:find("TOP") then t = py elseif a.p:find("BOTTOM") then b = py else cy = py end
    end
    local w, h = o.__w, o.__h
    if o.__kind == "FontString" then
        w = w or TextWidth(o)
        h = h or o:GetStringHeight()
    end
    w, h = w or 0, h or 0
    if l and r then w = r - l elseif l then r = l + w elseif r then l = r - w elseif cx then l, r = cx - w / 2, cx + w / 2 else l, r = 0, w end
    if t and b then h = t - b elseif t then b = t - h elseif b then t = b + h elseif cy then t, b = cy + h / 2, cy - h / 2 else t, b = h, 0 end
    local rect = { l = l, r = r, t = t, b = b }
    cache[o] = rect
    return rect
end

local function Visible(o, root)
    local f = o
    while f do
        if f.__shown == false then return false end
        if f == root then return true end
        f = f.__parent
    end
    return false
end

local function ScrollClip(o)
    local f = o.__parent
    while f do
        if f.__scrollOf then return f.__scrollOf end
        f = f.__parent
    end
end

local function Esc(s) return (tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")) end
local function Num(n) return string.format("%.1f", n) end

local function FrameLevel(o)
    if not o or o == UIParent then return 0 end
    if o.__kind == "Texture" or o.__kind == "FontString" then return FrameLevel(o.__parent) end
    return (o.__parent and FrameLevel(o.__parent) or 0) + 1
end

local out = {}
local function Dump(name, root)
    local cache = {}
    local items = {}
    local index = {}
    for i, o in ipairs(ALL_FRAMES) do index[o] = i end
    for i, o in ipairs(ALL_FRAMES) do
        if o ~= root and Visible(o, root) and o.__pts and #o.__pts > 0 then
            local rc = Resolve(o, cache)
            local fields = { '"i":' .. i, '"kind":"' .. o.__kind .. '"',
                '"l":' .. Num(rc.l), '"r":' .. Num(rc.r), '"t":' .. Num(SH - rc.t), '"b":' .. Num(SH - rc.b),
                '"fl":' .. FrameLevel(o) }
            if o.__layer then fields[#fields + 1] = '"layer":"' .. o.__layer .. '"' end
            if o.__w and o.__kind == "FontString" then fields[#fields + 1] = '"fixedw":true' end
            if o.__wrap == false then fields[#fields + 1] = '"nowrap":true' end
            if o.__parent and index[o.__parent] then fields[#fields + 1] = '"p":' .. index[o.__parent] end
            if o.__color then fields[#fields + 1] = '"color":[' .. table.concat(o.__color, ",") .. "]" end
            if o.__tcolor then fields[#fields + 1] = '"tcolor":[' .. table.concat(o.__tcolor, ",") .. "]" end
            if o.__text and o.__text ~= "" and o.__kind ~= "Button" then fields[#fields + 1] = '"text":"' .. Esc(Plain(o.__text)) .. '"' end
            if o.__font then fields[#fields + 1] = '"font":"' .. o.__font .. '"' end
            fields[#fields + 1] = '"size":' .. FontSize(o)
            if o.__justify then fields[#fields + 1] = '"justify":"' .. o.__justify .. '"' end
            if o.__texture and o.__kind == "Texture" then fields[#fields + 1] = '"texture":"' .. Esc(o.__texture) .. '"' end
            if o.__alpha then fields[#fields + 1] = '"alpha":' .. tostring(o.__alpha) end
            local clip = ScrollClip(o)
            if clip then
                local cr = Resolve(clip, cache)
                fields[#fields + 1] = '"clip":[' .. Num(cr.l) .. "," .. Num(SH - cr.t) .. "," .. Num(cr.r) .. "," .. Num(SH - cr.b) .. "]"
            end
            items[#items + 1] = "{" .. table.concat(fields, ",") .. "}"
        end
    end
    local rc = Resolve(root, cache)
    out[#out + 1] = '{"name":"' .. name .. '","frame":[' .. Num(rc.l) .. "," .. Num(SH - rc.t) .. ","
        .. Num(rc.r) .. "," .. Num(SH - rc.b) .. '],"items":[' .. table.concat(items, ",") .. "]}"
end
RENDER_DUMP = Dump

---------------------------------------------------------------------------
-- Scenarios
---------------------------------------------------------------------------
-- Another player, read through an inspect request
A:Audit("target", "button")
Answer("target")
Dump("ledger-target", A.ledger)
local ui = A.ledgerUI
Click(ui.tabs.activity)
Dump("activity-target", A.ledger)
Click(ui.tabs.history)
Dump("history-target", A.ledger)
Click(ui.tabs.characters)
Dump("characters", A.ledger)
-- Yourself
A:Audit("player", "button")
Dump("ledger-me", A.ledger)
-- A failed read: the red strip
CAN_INSPECT = false
Wait(6)
A:Audit("target", "button")
Dump("ledger-error", A.ledger)
CAN_INSPECT = true
-- The report
A:Audit("player", "button")
A:OpenReport()
Dump("report", A.reportWindow)
A.reportWindow:Hide()
-- The options, the welcome window
if A.OpenOptions and A.options == nil then
    A:OpenOptions()
end
if A.options then
    for _, key in ipairs(A.OPTION_TABS or {}) do
        A.options:ShowTab(key)
        Dump("options-" .. key, A.options)
    end
    A.options:Hide()
end
if A.ShowSplash then
    A:ShowSplash()
    Dump("splash", A.splash)
end

local f = assert(io.open(arg and arg[1] or "tests/render-out.json", "w"))
f:write("[" .. table.concat(out, ",\n") .. "]")
f:close()
io.write("wrote " .. #out .. " views\n")
