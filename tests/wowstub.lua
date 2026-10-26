-- A small fake of the game's API: enough to load ARS Forever outside the game
-- and drive it. Only what Forever has: globals Forever lacks are left out, so a
-- call to one fails here too.

LOG = {}
local realPrint = print
function print(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    LOG[#LOG + 1] = table.concat(t, " ")
end
REAL_PRINT = realPrint

BLOCKED = {}          -- protected actions attempted in combat
COMBAT = false
SECRET_MODE = false   -- unit identity comes back hidden, as Forever does in some places

-- Secret values: a marker that errors on arithmetic, ordering and joining
local SecretMT = {}
local function boom() error("attempted to use a secret value", 2) end
SecretMT.__add, SecretMT.__sub, SecretMT.__mul, SecretMT.__div = boom, boom, boom, boom
SecretMT.__lt, SecretMT.__le, SecretMT.__concat, SecretMT.__unm = boom, boom, boom, boom
SecretMT.__len = boom
SecretMT.__index = function() error("attempted to index a secret value", 2) end
SecretMT.__tostring = function() return "<secret>" end
function Secret(v) return setmetatable({}, SecretMT) end
function issecretvalue(v) return type(v) == "table" and getmetatable(v) == SecretMT end
local function maybeSecret(v) if SECRET_MODE and v ~= nil then return Secret(v) end return v end

ALL_FRAMES = {}
local Methods = {}
STUB_METHODS = Methods
-- Methods the addon adds to its own widgets: a real frame doesn't have them, so
-- calling one that was never added is an error here too (as in the game)
local ADDON_METHODS = { SetDisabled = true, SetOn = true, IsOn = true, SetHover = true, Paint = true,
    Refresh = true, Choose = true, SetContent = true, FitLogo = true, ShowTab = true }
local SECRET_OK = { SetText = true, SetFormattedText = true, SetValue = true, SetMinMaxValues = true, SetAlpha = true }
local PROTECTED_WHEN_COMBAT = { SetPoint = true, ClearAllPoints = true, SetSize = true, SetWidth = true,
    SetHeight = true, Show = true, Hide = true, SetAttribute = true, SetShown = true }
local MT = {
    __index = function(obj, k)
        local m = Methods[k]
        if m then
            if COMBAT and rawget(obj, "__protected") and PROTECTED_WHEN_COMBAT[k] then
                return function(self, ...)
                    BLOCKED[#BLOCKED + 1] = (self.__name or self.__kind) .. ":" .. k
                    return m(self, ...)
                end
            end
            if not SECRET_OK[k] then
                return function(self, ...)
                    for i = 1, select("#", ...) do
                        if issecretvalue((select(i, ...))) then error("secret passed to " .. k, 2) end
                    end
                    return m(self, ...)
                end
            end
            return m
        end
        if type(k) == "string" and k:sub(1, 2) == "__" then return nil end
        if ADDON_METHODS[k] then return nil end
        -- a field the addon never set (lowercase, like .disabled) is nil, as in the game
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        return function() end   -- any other method does nothing
    end,
}

function NewObj(kind, name, parent, template)
    local o = setmetatable({ __kind = kind, __name = name, __parent = parent, __scripts = {}, __children = {},
        __shown = true, __text = "", __template = template }, MT)
    if template and template:find("Secure") then o.__protected = true end
    if parent and parent.__children then table.insert(parent.__children, o) end
    if name then _G[name] = o end
    ALL_FRAMES[#ALL_FRAMES + 1] = o
    return o
end
local newObj = NewObj

function Methods:CreateTexture() return newObj("Texture", nil, self) end
function Methods:CreateFontString(_, _, template) local f = newObj("FontString", nil, self) f.__font = template return f end
function Methods:Show()
    local was = self.__shown
    self.__shown = true
    if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Methods:Hide()
    local was = self.__shown
    self.__shown = false
    if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local o = self
    while o do
        if not o.__shown then return false end
        o = o.__parent
    end
    return true
end
function Methods:SetScript(k, fn) self.__scripts[k] = fn end
function Methods:GetScript(k) return self.__scripts[k] end
function Methods:HookScript(k, fn)
    local old = self.__scripts[k]
    self.__scripts[k] = function(...) if old then old(...) end fn(...) end
end
function Methods:SetText(t)
    if issecretvalue(t) then self.__text = "<secret>" return end
    self.__text = t == nil and "" or tostring(t)
end
function Methods:GetText() return self.__text end
function Methods:SetFontString(fs) self.__fs = fs end
function Methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Methods:GetStringWidth() return #(self.__text or "") * 6 end
function Methods:GetStringHeight() return 12 end
function Methods:SetSize(w, h) self.__w, self.__h = w, h end
function Methods:SetWidth(w) self.__w = w end
function Methods:SetHeight(h) self.__h = h end
function Methods:GetWidth() return self.__w or 100 end
function Methods:GetHeight() return self.__h or 20 end
function Methods:SetScale(s) self.__scale = s end
function Methods:GetScale() return self.__scale or 1 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetFrameLevel() return 1 end
function Methods:SetPoint(...) self.__points = self.__points or {} table.insert(self.__points, { ... }) end
function Methods:GetPoint(i)
    local p = self.__points and self.__points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Methods:ClearAllPoints() self.__points = {} end
function Methods:GetName() return self.__name end
function Methods:GetObjectType() return self.__kind end
function Methods:RegisterEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:UnregisterEvent(e) if self.__events then self.__events[e] = nil end end
function Methods:IsEventRegistered(e) return self.__events and self.__events[e] or false end
function Methods:SetValue(v)
    self.__value = v
    if self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, v) end
end
function Methods:GetValue() return self.__value or 0 end
function Methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function Methods:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a } end
function Methods:SetVertexColor(r, g, b, a) self.__color = { r, g, b, a } end
function Methods:SetTextColor(r, g, b) self.__tcolor = { r, g, b } end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetAlpha() return self.__alpha or 1 end
function Methods:SetTexture(t) self.__texture = t end
function Methods:HasFocus() return self.__focus end
function Methods:SetFocus() self.__focus = true end
function Methods:ClearFocus()
    if self.__focus then
        self.__focus = false
        if self.__scripts.OnEditFocusLost then self.__scripts.OnEditFocusLost(self) end
    end
end
function Methods:GetCenter() return 500, 400 end
function Methods:EnableMouse(on) self.__mouse = on end

function CreateFrame(kind, name, parent, template) return newObj(kind, name, parent or UIParent, template) end

-- Clicks a button the way the game does
function Click(b, which)
    assert(b.__scripts.OnClick, "nothing to click")
    b.__scripts.OnClick(b, which or "LeftButton")
end

-- Types into an edit box
function Type(eb, text)
    eb:SetText(text)
    if eb.__scripts.OnTextChanged then eb.__scripts.OnTextChanged(eb, true) end
end

UIParent = newObj("Frame", "UIParent")
UIParent.__parent = nil
UIParent.__w, UIParent.__h = 1920, 1080
Minimap = newObj("Frame", "Minimap")
Minimap.__w, Minimap.__h = 140, 140

-- The tooltip remembers its lines
GameTooltip = newObj("GameTooltip", "GameTooltip")
GameTooltip.__lines = {}
function GameTooltip:SetOwner(o) self.__owner = o self.__lines = {} end
function GameTooltip:GetOwner() return self.__owner end
function GameTooltip:AddLine(t) self.__lines[#self.__lines + 1] = t end
function GameTooltip:SetText(t) self.__lines = { t } end
function GameTooltip:Hide() self.__owner = nil end

UISpecialFrames = {}
GameFontHighlightSmall = {}
SlashCmdList = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }
LOCALIZED_CLASS_NAMES_MALE = { PRIEST = "Priest", MAGE = "Mage", WARRIOR = "Warrior", HUNTER = "Hunter" }

function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
date = os.date
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

FAKE_TIME = 1000
SERVER_TIME = 1790000000
function GetTime() return FAKE_TIME end
function GetServerTime() return SERVER_TIME end
function GetBuildInfo() return BUILD_VERSION or "1.60.1", BUILD_NUMBER or "70532" end
function GetCVarBool() return false end
function GetCursorPosition() return 0, 0 end
function InCombatLockdown() return COMBAT end
MONEY = 1234567
function GetMoney() return MONEY end
function GetRealmName() return "Forever" end
C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }

TIMERS = {}
C_Timer = { After = function(_, fn) TIMERS[#TIMERS + 1] = fn end }
function RunTimers()
    local list = TIMERS
    TIMERS = {}
    for _, fn in ipairs(list) do fn() end
end

-- hooksecurefunc: runs the hook after the global
function hooksecurefunc(name, fn)
    local old = _G[name]
    assert(type(old) == "function", "hooksecurefunc on a missing function: " .. tostring(name))
    _G[name] = function(...)
        local r = { old(...) }
        fn(...)
        return unpack(r)
    end
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
UNITS = {
    player = { guid = "Player-1-00000001", name = "Visadrix", realm = "Forever", class = "Mage", classFile = "MAGE",
        level = 60, guild = "Coin Counters", player = true },
}
function SetTarget(u)
    UNITS.target = u
end
function UnitExists(u) return UNITS[u] ~= nil end
function UnitIsPlayer(u) return UNITS[u] ~= nil and UNITS[u].player == true end
function UnitGUID(u) local x = UNITS[u] return x and maybeSecret(x.guid) end
function UnitFullName(u) local x = UNITS[u] if x then return maybeSecret(x.name), maybeSecret(x.realm) end end
function UnitName(u) local x = UNITS[u] return x and maybeSecret(x.name) end
function UnitClass(u) local x = UNITS[u] if x then return maybeSecret(x.class), maybeSecret(x.classFile) end end
function UnitLevel(u) local x = UNITS[u] return x and x.level or 0 end
function UnitIsUnit(a, b) return maybeSecret(UNITS[a] ~= nil and UNITS[a] == UNITS[b]) end
function GetGuildInfo(u) local x = UNITS[u] return x and maybeSecret(x.guild) end
CAN_INSPECT = true
function CanInspect(u) return CAN_INSPECT and UNITS[u] ~= nil end

---------------------------------------------------------------------------
-- Statistics
---------------------------------------------------------------------------
STAT_NAMES = {}   -- the game's names for statistic IDs (filled by the tests)
STATS_SELF = {}   -- [id] = what GetStatistic returns
STATS_OTHER = {}  -- [guid] = { [id] = value }
STAT_SKIP = {}    -- [id] = true: returned as skipped
COMPARING = nil   -- the unit SetAchievementComparisonUnit was given
REQUESTS = {}     -- every comparison request sent
C_AchievementInfo = { IsValidAchievement = function(id) return STAT_NAMES[id] ~= nil end }
function GetAchievementInfo(id) if STAT_NAMES[id] then return id, STAT_NAMES[id] end end
function GetStatistic(id) return STATS_SELF[id], STAT_SKIP[id] end
function GetComparisonStatistic(id)
    local x = COMPARING and UNITS[COMPARING]
    local t = x and STATS_OTHER[x.guid] or {}
    return t[id], STAT_SKIP[id]
end
function SetAchievementComparisonUnit(u)
    COMPARING = u
    REQUESTS[#REQUESTS + 1] = u
    return true
end
function ClearAchievementComparisonUnit() COMPARING = nil end
-- The game's answer to a request
function Answer(unit)
    FireEvent("INSPECT_ACHIEVEMENT_READY", UNITS[unit or COMPARING].guid)
end

---------------------------------------------------------------------------
-- The Inspect window (loads on demand, like Blizzard_InspectUI)
---------------------------------------------------------------------------
function LoadInspectUI()
    InspectFrame = newObj("Frame", "InspectFrame", UIParent)
    InspectFrame.__shown = false
    function InspectFrame_Show(unit)
        InspectFrame.unit = unit
        InspectFrame:Show()
    end
    FireEvent("ADDON_LOADED", "Blizzard_InspectUI")
end

---------------------------------------------------------------------------
-- Running things
---------------------------------------------------------------------------
-- Runs the frames' OnUpdate scripts (only shown ones, as the game does)
function Tick(seconds)
    FAKE_TIME = FAKE_TIME + (seconds or 0.05)
    for _, f in ipairs(ALL_FRAMES) do
        local fn = f.__scripts.OnUpdate
        if fn and f:IsVisible() then fn(f, seconds or 0.05) end
    end
end

-- Passes time in one-second steps
function Wait(seconds)
    for _ = 1, seconds do Tick(1) end
end

function FireEvent(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end

TOC_FILES = {}
for line in io.lines((ADDON_DIR or ".") .. "/ARSForever.toc") do
    if line:match("%.lua%s*$") then TOC_FILES[#TOC_FILES + 1] = line:match("^%s*(.-)%s*$") end
end

-- Loads the addon's files in .toc order
function LoadAddon(dir)
    local ns = {}
    for _, f in ipairs(TOC_FILES) do
        local chunk = assert(loadfile((dir or ADDON_DIR or ".") .. "/" .. f))
        chunk("ARSForever", ns)
    end
    return ns
end
