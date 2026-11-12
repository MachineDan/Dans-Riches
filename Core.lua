-- Dan's Riches: core
-- Remembers every character's gold (per realm) and the display settings.
--
-- DansRichesDB = {
--     classColors = true,          -- color names by class in the tooltip
--     showTotal = true,            -- add a Total line under the characters
--     version = 2,
--     realms = {
--         ["PvP"] = {                  -- see ns.RealmKey()
--             ["Healy Dan"] = { money = 123456, class = "PRIEST", level = 60,
--                               faction = "Alliance", shown = true, updated = 1700000000 },
--         },
--     },
-- }
local _, ns = ...

-- Other files register login work here (the tooltip hook, the options page).
ns.onLogin = {}

ns.TITLE = "Dan's Riches"
ns.DEFAULTS = { classColors = true, showTotal = true }

function ns.Print(msg)
    print("|cffffd100Dan's Riches:|r " .. msg)
end

-- nil = gold not known yet (shown as a grey "?")
function ns.MoneyText(copper)
    if copper == nil then return "|cff888888?|r" end
    if GetMoneyString then return GetMoneyString(copper, true) end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return tostring(copper)
end

-- WoW Forever characters have a first name and a surname ("Healy Dan").
-- UnitName("player") returns them separately; we want the full name.
function ns.PlayerFullName()
    local name, surname = UnitName("player")
    if name and surname and surname ~= "" then
        local consts = Constants and Constants.CharacterNameSeparatorConsts
        return name .. (consts and consts.CHARACTERNAME_SURNAME_SEPARATOR or " ") .. surname
    end
    return name
end

-- WoW Forever names are unique per region and ruleset, and GetRealmName() is the
-- server you happen to be on this session ("CAMWOW EU5 Realm 8 PvP"), which can
-- change between logins. So characters are grouped by ruleset there ("PvP"),
-- the same way Syndicator does it. Elsewhere it's the realm name.
local function RulesetName()
    local rules, R = C_GameRules, Enum and Enum.GameRule
    if not (rules and rules.IsGameRuleActive and R) then return nil end
    local function On(rule) return rule ~= nil and rules.IsGameRuleActive(rule) end
    local pvp, rp = On(R.PvPRuleset), On(R.RPRuleset)
    if pvp and rp then return "RPPvP" end
    if pvp then return "PvP" end
    if rp then return "RP" end
    if On(R.HardcoreRuleset) then return "HC" end
    return "PvE"
end

function ns.RealmKey()
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        local ok, ruleset = pcall(RulesetName)
        if ok and ruleset then return ruleset end
    end
    return GetRealmName()
end

function ns.ClassColored(text, classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color and color.WrapTextInColorCode then return color:WrapTextInColorCode(text) end
    if color and color.colorStr then return "|c" .. color.colorStr .. text .. "|r" end
    return text
end

-- A character's name as the tooltip and options page show it.
function ns.NameText(name, char)
    if ns.db and ns.db.classColors then return ns.ClassColored(name, char and char.class) end
    return name
end

function ns.LoadSettings()
    local db = type(DansRichesDB) == "table" and DansRichesDB or {}
    DansRichesDB = db
    for key, value in pairs(ns.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    if type(db.realms) ~= "table" then db.realms = {} end
    ns.db = db
end

-- 1.0.0 grouped Forever characters by server name and could save 0 gold (see
-- ns.ReadMoney). Move them under the ruleset and drop the bad zeros so the
-- Syndicator import below can fill them in.
local DATA_VERSION = 2
function ns.Migrate()
    local db = ns.db
    if (db.version or 1) >= DATA_VERSION then return end
    local key, server = ns.RealmKey(), GetRealmName()
    if server and key ~= server and db.realms[server] then
        local into = db.realms[key] or {}
        db.realms[key] = into
        for name, char in pairs(db.realms[server]) do
            if not into[name] then into[name] = char end
        end
        db.realms[server] = nil
    end
    for _, chars in pairs(db.realms) do
        for _, char in pairs(chars) do
            if char.money == 0 then char.money = nil end
        end
    end
    db.version = DATA_VERSION
end

-- Syndicator (Baganator's data addon) remembers every character's gold too.
-- Characters it knows and we don't, or whose gold we never got, are taken from
-- it, so alts you haven't logged into since installing Dan's Riches still show.
function ns.ImportSyndicator()
    local data = rawget(_G, "SYNDICATOR_DATA")
    local list = type(data) == "table" and data.Characters
    if type(list) ~= "table" then return 0 end
    local count = 0
    for _, entry in pairs(list) do
        local d = type(entry) == "table" and entry.details
        local realm = d and (d.realmNormalized or d.realm)
        if d and d.character and realm and type(entry.money) == "number" then
            local chars = ns.db.realms[realm]
            if not chars then
                chars = {}
                ns.db.realms[realm] = chars
            end
            local char = chars[d.character]
            if not char then
                char = { shown = true }
                chars[d.character] = char
            end
            if char.money == nil then
                char.money = entry.money
                char.class = char.class or d.className
                char.faction = char.faction or d.faction
                char.fromSyndicator = true
                count = count + 1
            end
        end
    end
    return count
end

function ns.ResetSettings()
    for key, value in pairs(ns.DEFAULTS) do ns.db[key] = value end
    for _, chars in pairs(ns.db.realms) do
        for _, char in pairs(chars) do char.shown = true end
    end
end

-- GetMoney() returns 0 for a while after logging in (TradeSkillMaster works
-- around the same thing), and saving that would wipe the character's real gold.
-- So gold only counts once it's above 0, the game reports a money change, or
-- 30 seconds have passed (then 0 really is 0).
ns.moneyReady = false
local MONEY_WAIT = 30

function ns.ReadMoney()
    local money = GetMoney()
    if money and money > 0 then ns.moneyReady = true end
    if ns.moneyReady then return money end
    return nil
end

-- Records the logged-in character's gold, class and level.
function ns.SaveThisCharacter()
    if not ns.db then return end
    local realm, name = ns.RealmKey(), ns.PlayerFullName()
    if not realm or not name or name == "" or name == UNKNOWNOBJECT then return end
    local chars = ns.db.realms[realm]
    if not chars then
        chars = {}
        ns.db.realms[realm] = chars
    end
    local char = chars[name]
    if not char then
        char = { shown = true }
        chars[name] = char
    end
    local money = ns.ReadMoney()
    if money then
        char.money = money
        char.fromSyndicator = nil
        char.updated = time and time() or nil
    end
    char.class = select(2, UnitClass("player")) or char.class
    char.level = UnitLevel("player") or char.level
    char.faction = UnitFactionGroup("player") or char.faction
end

function ns.IsCurrentCharacter(realm, name)
    return realm == ns.RealmKey() and name == ns.PlayerFullName()
end

-- Characters of one realm, richest first: { { name = ..., char = {...} }, ... }
function ns.Characters(realm)
    local list = {}
    local chars = ns.db and ns.db.realms[realm]
    if chars then
        for name, char in pairs(chars) do list[#list + 1] = { name = name, char = char } end
    end
    table.sort(list, function(a, b)
        local ma, mb = a.char.money or 0, b.char.money or 0
        if ma ~= mb then return ma > mb end
        return a.name < b.name
    end)
    return list
end

-- Realm names, the current one first, then the rest alphabetically.
function ns.Realms()
    local current, list = ns.RealmKey(), {}
    for realm in pairs(ns.db.realms) do
        if realm ~= current then list[#list + 1] = realm end
    end
    table.sort(list)
    if ns.db.realms[current] then table.insert(list, 1, current) end
    return list
end

function ns.Forget(realm, name)
    local chars = ns.db.realms[realm]
    if not chars then return end
    chars[name] = nil
    if next(chars) == nil then ns.db.realms[realm] = nil end
end

-- Try again every second until the gold is known (see ns.ReadMoney).
local function WaitForMoney(tries)
    ns.SaveThisCharacter()
    if ns.moneyReady then return end
    if tries >= MONEY_WAIT or not (C_Timer and C_Timer.After) then
        ns.moneyReady = true
        ns.SaveThisCharacter()
        return
    end
    C_Timer.After(1, function() WaitForMoney(tries + 1) end)
end

-- No PLAYER_LOGOUT save: gold is already current from PLAYER_MONEY, and the
-- game can report 0 while logging out.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ns.LoadSettings()
        ns.Migrate()
        WaitForMoney(0)
        ns.ImportSyndicator()
        for _, fn in ipairs(ns.onLogin) do
            local ok, err = pcall(fn)
            if not ok then geterrorhandler()(err) end
        end
    else
        if event == "PLAYER_MONEY" then ns.moneyReady = true end
        ns.SaveThisCharacter()
    end
end)

function ns.OnLogin(fn)
    ns.onLogin[#ns.onLogin + 1] = fn
end
