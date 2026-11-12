-- Offline checks for the "offline characters show 0 gold" bug.
-- Run from the repo root: luajit tests/test_money.lua
local T = dofile("tests/fake_wow.lua")
local Expect, Fire, Hover, player = T.Expect, T.Fire, T.Hover, T.player

-- WoW Forever: names are unique per region; the server name changes between sessions.
RegionalUniqueNamesEnabled = function() return true end
Enum = { GameRule = { PvPRuleset = 1, RPRuleset = 2, HardcoreRuleset = 3 } }
C_GameRules = { IsGameRuleActive = function(rule) return rule == 1 end }
player.realm = "CAMWOW EU5 Realm 8 PvP"

-- What 1.0.0 saved: gold 0 for everyone, grouped by server name (the real file).
DansRichesDB = { showTotal = true, classColors = true, realms = {
    ["CAMWOW EU5 Realm 8 PvP"] = {
        ["Professor Dan"] = { money = 0, class = "WARLOCK", level = 6, faction = "Horde", shown = true },
        ["Healy Dan"] = { money = 0, class = "PRIEST", level = 27, faction = "Horde", shown = false },
    },
} }

-- Syndicator's data for the same account (the real values, trimmed).
SYNDICATOR_DATA = { Characters = {
    ["Healy Dan-PvP"] = { money = 52928, details = { character = "Healy Dan", realm = "PvP", realmNormalized = "PvP", className = "PRIEST", faction = "Horde" } },
    ["Droo Dan-PvP"] = { money = 42, details = { character = "Droo Dan", realm = "PvP", realmNormalized = "PvP", className = "DRUID", faction = "Horde" } },
    ["Professor Dan-PvP"] = { money = 213, details = { character = "Professor Dan", realm = "PvP", realmNormalized = "PvP", className = "WARLOCK", faction = "Horde" } },
} }

-- Logging in on Professor Dan; GetMoney() says 0 for the first few seconds.
player.first, player.surname, player.class, player.level = "Professor", "Dan", "WARLOCK", 6
player.money = 0

local ns = T.LoadAddon()
Fire("PLAYER_LOGIN")

local db = DansRichesDB
local pvp = db.realms.PvP
Expect(db.realms["CAMWOW EU5 Realm 8 PvP"] == nil, "old server-name group moved")
Expect(pvp ~= nil, "characters grouped by ruleset (PvP)")
Expect(pvp and pvp["Healy Dan"].money == 52928, "offline Healy's bad 0 replaced by Syndicator's gold")
Expect(pvp and pvp["Healy Dan"].shown == false, "Healy's hidden setting kept through the move")
Expect(pvp and pvp["Droo Dan"] and pvp["Droo Dan"].money == 42 and pvp["Droo Dan"].class == "DRUID", "never-seen Droo imported from Syndicator")
Expect(pvp and pvp["Professor Dan"].money == 213, "while GetMoney() is still 0, the known gold stays (got " .. tostring(pvp["Professor Dan"].money) .. ")")
Expect(db.version == 2, "migration recorded")

-- The real gold arrives a few seconds later
T.RunTimers(3)
Expect(pvp["Professor Dan"].money == 213, "still waiting, nothing overwritten")
player.money = 70
T.RunTimers(1)
Expect(pvp["Professor Dan"].money == 70, "gold saved once GetMoney() reports it")
Expect(pvp["Professor Dan"].fromSyndicator == nil, "own reading replaces the imported one")
Expect(T.RunTimers() == 0, "retry stops once the gold is known")

-- Spending down to 0 is a real 0 (the game reported a money change)
player.money = 0
Fire("PLAYER_MONEY")
Expect(pvp["Professor Dan"].money == 0, "PLAYER_MONEY can save a real 0")

-- Logging out doesn't touch gold
player.money = 70
Fire("PLAYER_MONEY")
player.money = 0
Fire("PLAYER_LOGOUT")
Expect(pvp["Professor Dan"].money == 70, "logout can't wipe gold")
player.money = 70

-- Tooltip on Forever: everyone in the PvP group, hidden Healy left out
local lines = Hover()
Expect(lines[4].left == "Your Riches", "tooltip header says Your Riches")
Expect(lines[5].left:find("Professor Dan") and lines[5].right == "70c", "Professor first")
Expect(lines[6].left:find("Droo Dan") and lines[6].right == "42c", "Droo shown from imported data")
Expect(lines[7].left == "Total" and lines[7].right == "112c", "total")

-- A second login: Syndicator's (possibly stale) value never overrides our own
SYNDICATOR_DATA.Characters["Droo Dan-PvP"].money = 99999
ns.ImportSyndicator()
Expect(pvp["Droo Dan"].money == 42, "known gold not overwritten by later imports")

-- A brand new character with truly 0 gold: after 30 s it's recorded as 0
DansRichesDB = { realms = {} }
player.first, player.money = "Newbie", 0
SYNDICATOR_DATA = nil
local ns2 = T.LoadAddon()
Fire("PLAYER_LOGIN")
Expect(DansRichesDB.realms.PvP["Newbie Dan"].money == nil, "unknown at first")
Expect(ns2.MoneyText(nil):find("?", 1, true), "unknown gold shows as ?")
T.RunTimers()
Expect(DansRichesDB.realms.PvP["Newbie Dan"].money == 0, "0 accepted after 30 seconds")

T.Done()
