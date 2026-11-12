-- Dan's Riches: core
-- Remembers every character's gold (per realm) and the display settings.
--
-- DansRichesDB = {
--     classColors = true,          -- color names by class in the tooltip
--     showTotal = true,            -- add a Total line under the characters
--     realms = {
--         ["Realm"] = {
--             ["Healy Dan"] = { money = 123456, class = "PRIEST", level = 60,
--                               faction = "Alliance", shown = true, updated = 1700000000 },
--         },
--     },
-- }
local _, ns = ...

ns.TITLE = "Dan's Riches"
ns.DEFAULTS = { classColors = true, showTotal = true }

function ns.Print(msg)
    print("|cffffd100Dan's Riches:|r " .. msg)
end

function ns.MoneyText(copper)
    copper = copper or 0
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

function ns.ResetSettings()
    for key, value in pairs(ns.DEFAULTS) do ns.db[key] = value end
    for _, chars in pairs(ns.db.realms) do
        for _, char in pairs(chars) do char.shown = true end
    end
end

-- Records the logged-in character's gold, class and level.
function ns.SaveThisCharacter()
    if not ns.db then return end
    local realm, name = GetRealmName(), ns.PlayerFullName()
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
    char.money = GetMoney()
    char.class = select(2, UnitClass("player")) or char.class
    char.level = UnitLevel("player") or char.level
    char.faction = UnitFactionGroup("player") or char.faction
    char.updated = time and time() or nil
end

function ns.IsCurrentCharacter(realm, name)
    return realm == GetRealmName() and name == ns.PlayerFullName()
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
    local current, list = GetRealmName(), {}
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

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ns.LoadSettings()
        ns.SaveThisCharacter()
        for _, fn in ipairs(ns.onLogin or {}) do
            local ok, err = pcall(fn)
            if not ok then geterrorhandler()(err) end
        end
    else
        ns.SaveThisCharacter()
    end
end)

-- Other files register login work here (the tooltip hook, the options page).
ns.onLogin = {}
function ns.OnLogin(fn)
    ns.onLogin[#ns.onLogin + 1] = fn
end
