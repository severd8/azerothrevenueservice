-- ARS Forever: the statistics the game keeps, reading them safely, and the
-- plain text report. No frames here. Based on Forever IRS's Statistics.lua and
-- Assessment.lua (MIT, see LICENSE).

local _, ns = ...
ns.ARS = ns.ARS or {}
local A = ns.ARS

-- Client builds whose statistic definitions (IDs, labels) were checked against
-- the game's Achievement data. Another build still works; it only gets a note.
A.DATA_BUILD = "1.60.1.70291"
A.DATA_BUILDS = { ["1.60.1.70124"] = true, ["1.60.1.70291"] = true }

A.DISCLAIMER = "Figures may be inaccurate, incomplete, or out of date. Game counters, resets and addon errors can affect them. Use them as a reference: they are not proof of innocence or wrongdoing."
A.DATA_SOURCE = "the game's statistics"
A.DATA_SOURCE_NOTICE = "ARS reads the game's statistics directly (the same numbers as the Statistics page). Values are saved as the game returned them and are not checked against anything else."
A.DATA_SOURCE_VERIFY = "A successful read only means the numbers arrived and could be read. It can't prove that the game's own counters are current, complete or correct."
A.INCOME_SOURCES = "Income breakdown: gold looted, quest rewards, vendor sales and auction earnings."
A.INCOME_TRANSFERS = "The breakdown doesn't list gifts, gold from alts or friends, or player trades (normal item sales, selling ports or summons, and so on)."
A.INCOME_DISCLAIMER = "A difference does not necessarily indicate wrongdoing."
A.INCOME_TOTAL_NOTE = "Total gold acquired is the game's own separate statistic; ARS doesn't add up the four income rows to get it. These counters are not a complete record of gold received."
A.NOT_PROFIT = "Gold acquired is everything that came in, not profit. Peak gold is a past high, not what the player has now."
A.ASSESSMENT_NOTE = "These counters are what the game reported. New characters, bank alts and specialists can look very different; missing counters and resets affect them too. ARS doesn't grade characters."

-- { key, statistic ID, label, is money, is a profession's highest rank }
-- All 36 IDs match the game's data in the builds in DATA_BUILDS.
A.FIELDS = {
    { "acquired", 328, "Total gold acquired", true },
    { "peak", 334, "Most gold ever owned", true },
    { "looted", 333, "Gold looted", true },
    { "quests", 326, "Quest rewards", true },
    { "vendors", 921, "Vendor sales", true },
    { "auctions", 919, "Auction earnings", true },
    { "daily", 753, "Average earned per day", true },
    { "travel", 1146, "Travel", true },
    { "postage", 1148, "Postage", true },
    { "barber", 1147, "Barber shops", true },
    { "respec", 1150, "Talent respecs", true },
    { "posted", 329, "Auctions posted" },
    { "purchases", 330, "Auction purchases" },
    { "largestSale", 332, "Largest auction sale", true },
    { "largestBid", 331, "Largest auction bid", true },
    { "questCount", 98, "Quests completed" },
    { "kills", 107, "Creatures killed" },
    { "dungeons", 932, "Dungeons entered" },
    { "deaths", 60, "Total deaths" },
    { "disenchanted", 181, "Items disenchanted" },
    { "disenchantMaterials", 183, "Disenchant materials" },
    { "fishCaught", 1518, "Fish caught" },
    { "flights", 349, "Flight paths taken" },
    { "honorableKills", 588, "Honorable kills" },
    { "firstAid", 281, "First Aid" }, { "cooking", 1524, "Cooking" }, { "fishing", 1519, "Fishing" },
    { "alchemy", 1527, "Alchemy", false, true }, { "blacksmithing", 1532, "Blacksmithing", false, true },
    { "enchanting", 1535, "Enchanting", false, true }, { "leatherworking", 1536, "Leatherworking", false, true },
    { "mining", 1537, "Mining", false, true }, { "herbalism", 1538, "Herbalism", false, true },
    { "skinning", 1541, "Skinning", false, true }, { "tailoring", 1542, "Tailoring", false, true },
    { "engineering", 1544, "Engineering", false, true },
}
A.BY_KEY = {}
for _, f in ipairs(A.FIELDS) do A.BY_KEY[f[1]] = f end

A.PROFESSION_KEYS = { "firstAid", "cooking", "fishing", "alchemy", "blacksmithing", "enchanting", "leatherworking",
    "mining", "herbalism", "skinning", "tailoring", "engineering" }
A.ACTIVITY_KEYS = { "questCount", "kills", "dungeons", "disenchanted", "disenchantMaterials", "fishCaught",
    "honorableKills", "flights", "deaths" }

function A.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) and true or false
end

-- A whole, safe number, or nil (never a secret)
function A.Number(v)
    if A.IsSecret(v) then return nil end
    local n = tonumber(v)
    if n and n == n and n >= 0 and n <= 9007199254740991 then return n end
end

-- Text that is safe to show and save: no escape codes, no control characters
function A.Plain(v)
    if v == nil or A.IsSecret(v) then return "" end
    return (tostring(v):gsub("|", "||"):gsub("%c", " "))
end

function A.Quantity(n)
    if n == nil then return "Unavailable" end
    return (string.format("%.0f", math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- "12g 3s 4c" (plain) or coloured letters
function A.Money(n, plain)
    if n == nil then return "Unavailable" end
    n = math.floor(n)
    local g, s, c = math.floor(n / 10000), math.floor(n / 100) % 100, n % 100
    if plain then return A.Quantity(g) .. "g " .. s .. "s " .. c .. "c" end
    return "|cffffd17a" .. A.Quantity(g) .. "g|r |cffcbd5e1" .. s .. "s|r |cffcb9977" .. c .. "c|r"
end

-- The game's way of showing money: coin icons, empty denominations left out
function A.Coins(n)
    if n == nil then return "--" end
    n = math.floor(n)
    local letters = type(GetCVarBool) == "function" and GetCVarBool("colorblindMode")
    local parts = {}
    for i, unit in ipairs({ { 10000, "Gold", "g" }, { 100, "Silver", "s" }, { 1, "Copper", "c" } }) do
        local amount = math.floor(n / unit[1])
        if i > 1 then amount = amount % 100 end
        if amount > 0 or (i == 3 and #parts == 0) then
            local shown = i == 1 and A.Quantity(amount) or tostring(amount)
            parts[#parts + 1] = shown .. (letters and unit[3] or ("|TInterface\\MoneyFrame\\UI-" .. unit[2] .. "Icon:0:0:2:0|t"))
        end
    end
    return table.concat(parts, " ")
end

local function PlainIcon(icon)
    local name = icon:lower()
    if name:find("gold", 1, true) then return "g " end
    if name:find("silver", 1, true) then return "s " end
    if name:find("copper", 1, true) then return "c " end
    return " [icon] "
end

-- "1,234" / "1.234" / "1 234" as a whole number; nothing ambiguous
local function IntegerText(text)
    text = text:gsub("\194\160", " "):gsub("\226\128\175", " "):match("^%s*(.-)%s*$")
    if text:match("^%d+$") then return A.Number(text) end
    local first, sep, rest = text:match("^(%d%d?%d?)([,. ])(.*)$")
    if not first then return nil end
    local digits = first
    while true do
        local group = rest:sub(1, 3)
        if not group:match("^%d%d%d$") then return nil end
        digits = digits .. group
        if #rest == 3 then return A.Number(digits) end
        if rest:sub(4, 4) ~= sep then return nil end
        rest = rest:sub(5)
    end
end
A.IntegerText = IntegerText

-- The game can return money as coin-icon text; turn it into copper
function A.ParseMoney(raw)
    local n = A.Number(raw)
    if n then return n % 1 == 0 and n or nil end
    if type(raw) ~= "string" or #raw > 400 then return nil end
    local text = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local units = { gold = "g", silver = "s", copper = "c" }
    local function token(icon, atlas)
        local name = icon:lower():gsub("\\", "/")
        local metal
        if atlas then metal = name:match("^:?coin%-(%a+):")
        else metal = name:match("^interface/moneyframe/ui%-(%a+)icon:") end
        return units[metal] and ("\001" .. units[metal] .. "\002") or "?"
    end
    text = text:gsub("|T(.-)|t", function(i) return token(i, false) end)
        :gsub("|A(.-)|a", function(i) return token(i, true) end)
    local values = { g = 10000, s = 100, c = 1 }
    local total, last, pos, count = 0, 10001, 1, 0
    while true do
        local first, finish, unit = text:find("\001([gsc])\002", pos)
        if not first then break end
        local amount = IntegerText(text:sub(pos, first - 1))
        local mult = values[unit]
        if amount == nil or mult >= last or (unit ~= "g" and amount > 99) then return nil end
        total = total + amount * mult
        last, pos, count = mult, finish + 1, count + 1
    end
    if count > 0 and text:sub(pos):match("^%s*$") then return A.Number(total) end
end

-- One saved value: { number = n }, { display = text } (shown but never used
-- in sums), or nil
function A.Entry(raw, money)
    if A.IsSecret(raw) then return nil end
    local n
    if money then
        n = A.ParseMoney(raw)
    else
        n = A.Number(raw)
        if n and n % 1 ~= 0 then n = nil end
        if not n and type(raw) == "string" then n = IntegerText(raw) end
    end
    if n ~= nil then return { number = n } end
    if type(raw) ~= "string" or #raw > 400 or not raw:find("%d") then return nil end
    return { display = A.Plain(raw) }
end

A.REASONS = {
    notReported = "The game returned no value. This is not a confirmed zero.",
    unsupported = "This client doesn't have this statistic.",
    skipped = "The game marked this statistic as hidden.",
    unreadable = "The game returned a value that couldn't be read safely.",
    readError = "The game couldn't read this counter.",
    apiUnavailable = "This client's statistics functions are missing.",
}
function A.Reason(s, key)
    local r = s and s.unavailable and s.unavailable[key]
    return A.REASONS[r] or "No readable value was saved for this statistic. This is not a confirmed zero."
end

-- "not reported" / "unavailable" for a missing value; never 0
function A.MissingWord(s, key)
    return s and s.unavailable and s.unavailable[key] == "notReported" and "Not reported" or "Unavailable"
end

function A.Value(s, key, plain)
    local e = s and s.values and s.values[key]
    if not e then return A.MissingWord(s, key) end
    if e.number ~= nil then
        return A.BY_KEY[key] and A.BY_KEY[key][4] and A.Money(e.number, plain) or A.Quantity(e.number)
    end
    local d = e.display or "Unavailable"
    if plain then
        return (d:gsub("|T(.-)|t", PlainIcon):gsub("|A(.-)|a", PlainIcon):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+$", ""))
    end
    return d
end

function A.Numeric(s, key)
    return s and s.values and s.values[key] and s.values[key].number
end

-- Peak minus acquired (never below 0), and acquired as a share of peak (0-1)
function A.Gap(s)
    local peak, total = A.Numeric(s, "peak"), A.Numeric(s, "acquired")
    if peak == nil or total == nil then return nil end
    return math.max(0, peak - total), peak > 0 and math.min(1, total / peak) or nil
end

function A.Build()
    local version, build = GetBuildInfo()
    return tostring(version or "unknown") .. "." .. tostring(build or "unknown")
end

function A.Supported()
    local version = GetBuildInfo()
    return type(version) == "string" and version:match("^1%.60%.") ~= nil
end

-- Where a capture's numbers come from and whether its build was checked.
-- warning: something is really wrong (another game branch, functions missing).
-- An unchecked build only gets a note (Forever IRS showed it in red, so every
-- capture after a patch looked like an error).
function A.SourceStatus(s)
    local client = s and s.build or A.Build()
    local selfAPI = type(GetStatistic) == "function"
    local comparisonAPI = type(GetComparisonStatistic) == "function"
    local supported = type(client) == "string" and client:match("^1%.60%.") ~= nil
    local checked = A.DATA_BUILDS[client] == true
    local apiMissing = not s and (not selfAPI or not comparisonAPI)
    local reason, note
    if not supported then reason = "This client isn't WoW: Forever 1.60, which ARS is made for."
    elseif apiMissing then reason = "One or more of the game's statistics functions are missing." end
    if not checked then
        note = "This game build (" .. tostring(client) .. ") is newer than the last one whose statistic list was checked ("
            .. A.DATA_BUILD .. "). /ars check lists every statistic the addon reads."
    end
    return { client = client, definitions = checked and client or A.DATA_BUILD, supported = supported,
        selfAPI = selfAPI, comparisonAPI = comparisonAPI, checked = checked,
        warning = reason ~= nil, reason = reason, note = note }
end

-- How a finished capture went, compared with the one before it
function A.CheckCapture(s, previous)
    local r = { numeric = 0, displayOnly = 0, missing = 0, compared = 0, changed = 0, lost = 0 }
    if not previous or previous.guid ~= s.guid then r.baseline = "first"
    elseif previous.build ~= s.build then r.baseline = "build"
    elseif previous.own ~= s.own then r.baseline = "source" end
    for _, f in ipairs(A.FIELDS) do
        local key = f[1]
        local v = A.Numeric(s, key)
        if v ~= nil then r.numeric = r.numeric + 1
        elseif s.values[key] then r.displayOnly = r.displayOnly + 1
        else r.missing = r.missing + 1 end
        if not r.baseline then
            local old = A.Numeric(previous, key)
            if old ~= nil then
                if v ~= nil then
                    r.compared = r.compared + 1
                    if old ~= v then r.changed = r.changed + 1 end
                else
                    r.lost = r.lost + 1
                end
            end
        end
    end
    return r
end

-- Reads every statistic. subject: { guid, name, realm, class, level, guild }.
-- own: your own (GetStatistic) or the inspected player's (GetComparisonStatistic).
function A.Read(subject, own)
    local getter = own and GetStatistic or GetComparisonStatistic
    local s = { guid = subject.guid, name = subject.name, realm = subject.realm, class = subject.class,
        classFile = subject.classFile, level = subject.level, guild = subject.guild, build = A.Build(),
        at = GetServerTime(), own = own and true or false, values = {}, unavailable = {}, available = 0 }
    for _, f in ipairs(A.FIELDS) do
        local key, id = f[1], f[2]
        local valid = true
        if C_AchievementInfo and type(C_AchievementInfo.IsValidAchievement) == "function" then
            local ok, yes = pcall(C_AchievementInfo.IsValidAchievement, id)
            valid = ok and not A.IsSecret(yes) and yes and true or false
        end
        if valid and type(getter) == "function" then
            local ok, raw, skip = pcall(getter, id)
            -- (checked before anything truth-tests raw or skip)
            local hidden = ok and (A.IsSecret(raw) or A.IsSecret(skip))
            if ok and not hidden and not skip then
                s.values[key] = A.Entry(raw, f[4])
                s.unavailable[key] = (raw == nil or raw == "" or raw == "--" or raw == "-") and "notReported" or "unreadable"
            else
                s.unavailable[key] = not ok and "readError" or hidden and "unreadable" or "skipped"
            end
        else
            s.unavailable[key] = not valid and "unsupported" or "apiUnavailable"
        end
        if s.values[key] then
            s.available = s.available + 1
            s.unavailable[key] = nil
        end
    end
    if own and type(GetMoney) == "function" then
        local ok, n = pcall(GetMoney)
        if ok then s.wallet = A.Number(n) end
    end
    return s
end

-- Professions, highest first, missing last
function A.Professions(s)
    local rows = {}
    for _, key in ipairs(A.PROFESSION_KEYS) do
        rows[#rows + 1] = { key = key, label = A.BY_KEY[key][3], highest = A.BY_KEY[key][5] == true, n = A.Numeric(s, key) }
    end
    table.sort(rows, function(a, b)
        if a.n == nil and b.n ~= nil then return false end
        if b.n == nil and a.n ~= nil then return true end
        if a.n ~= b.n then return a.n > b.n end
        return a.label < b.label
    end)
    return rows
end

-- A plain count of what was recorded; no grades, no guesses about play style
function A.Assess(s)
    local known, total, positive = 0, 0, 0
    local evidence = {}
    for _, key in ipairs({ "questCount", "kills", "dungeons", "honorableKills", "disenchanted", "disenchantMaterials", "fishCaught" }) do
        local n = A.Numeric(s, key)
        total = total + 1
        if n ~= nil then
            known = known + 1
            if n > 0 then positive = positive + 1 end
        end
        evidence[#evidence + 1] = A.BY_KEY[key][3] .. ": " .. A.Value(s, key, true)
    end
    local rankKnown, rankPositive = 0, 0
    for _, key in ipairs(A.PROFESSION_KEYS) do
        local rank = A.Numeric(s, key)
        total = total + 1
        if rank ~= nil then known, rankKnown = known + 1, rankKnown + 1 end
        if rank and rank > 0 then positive, rankPositive = positive + 1, rankPositive + 1 end
    end
    evidence[#evidence + 1] = "Professions: " .. rankPositive .. " with a rank above zero; " .. rankKnown .. " / "
        .. #A.PROFESSION_KEYS .. " readable. Past ranks can include unlearned professions."
    evidence[#evidence + 1] = "Auctions: " .. A.Value(s, "posted", true) .. " posted; " .. A.Value(s, "purchases", true) .. " bought."
    return {
        title = known > 0 and "Recorded activity" or "Activity counters unavailable",
        summary = known > 0 and (positive .. " of the " .. known .. " readable activity counters are above zero. Missing values are not zero.")
            or "This capture has no readable activity counters. Missing values are not zero.",
        known = known, total = total, positive = positive, evidence = evidence,
        coverage = known .. " / " .. total .. " activity counters readable",
    }
end

local function When(at) return type(at) == "number" and date("%Y-%m-%d %H:%M", at) or "--" end

-- The copyable text report. check: optional { title, detail } of the last read.
function A.Report(s, check)
    if not s then return "No capture loaded." end
    local src = A.SourceStatus(s)
    local lines = { "ARS Forever (Azeroth Revenue Service) - character statistics", "",
        A.INCOME_DISCLAIMER:upper(), A.INCOME_SOURCES, A.INCOME_TRANSFERS, "",
        "Accuracy: " .. A.DISCLAIMER, "",
        A.Plain(s.name) .. (s.realm and s.realm ~= "" and (" - " .. A.Plain(s.realm)) or ""),
        "Captured: " .. When(s.at) .. " - client " .. A.Plain(s.build),
        "Source: " .. A.DATA_SOURCE .. (s.own and " (your own character)" or " (inspected player)"),
    }
    if src.reason then lines[#lines + 1] = "WARNING: " .. src.reason end
    if src.note then lines[#lines + 1] = "Note: " .. src.note end
    lines[#lines + 1] = A.DATA_SOURCE_VERIFY
    if check then
        lines[#lines + 1] = "Read: " .. check.title
        lines[#lines + 1] = check.detail
    end
    lines[#lines + 1] = "Current gold: " .. (s.own and A.Money(s.wallet, true) or "not visible for other players")
    lines[#lines + 1] = ""
    for _, f in ipairs(A.FIELDS) do
        lines[#lines + 1] = f[3] .. (f[5] and " (highest recorded)" or "") .. ": " .. A.Value(s, f[1], true)
            .. (not s.values[f[1]] and (" (" .. A.Reason(s, f[1]) .. ")") or "")
    end
    local a = A.Assess(s)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Activity counters: " .. a.title
    lines[#lines + 1] = a.summary
    lines[#lines + 1] = a.coverage
    for _, e in ipairs(a.evidence) do lines[#lines + 1] = "- " .. e end
    lines[#lines + 1] = A.ASSESSMENT_NOTE
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Peak minus gold acquired (never below zero): " .. A.Money((A.Gap(s)), true)
    lines[#lines + 1] = A.INCOME_TOTAL_NOTE
    lines[#lines + 1] = A.NOT_PROFIT
    lines[#lines + 1] = "Missing data and counter resets can also affect the difference. Unavailable is not zero."
    return table.concat(lines, "\n")
end
