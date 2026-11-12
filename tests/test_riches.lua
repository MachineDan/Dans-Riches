-- Offline checks for Dan's Riches with a fake WoW API.
-- Run from the repo root: luajit tests/test_riches.lua
local T = dofile("tests/fake_wow.lua")
local Expect, Fire, Hover, NewFrame, player, backpack = T.Expect, T.Fire, T.Hover, T.NewFrame, T.player, T.backpack

-- Saved data from earlier sessions: two alts on this realm, one elsewhere.
DansRichesDB = { realms = {
    Camelot = {
        ["Frosty Dan"] = { money = 900000, class = "MAGE", level = 60, shown = true },
        ["Hidden Dan"] = { money = 100, class = "MAGE", level = 10, shown = false },
    },
    Elsewhere = { ["Far Dan"] = { money = 1, class = "MAGE", level = 1, shown = true } },
} }

local ns = T.LoadAddon()
Fire("PLAYER_LOGIN")

-- Login ----------------------------------------------------------------------------------------
local me = DansRichesDB.realms.Camelot["Healy Dan"]
Expect(me ~= nil, "current character saved under its full Forever name")
Expect(me and me.money == 50000 and me.class == "PRIEST" and me.level == 42 and me.shown == true, "current character data")
Expect(DansRichesDB.classColors == true and DansRichesDB.showTotal == true, "defaults filled in")

-- Tooltip --------------------------------------------------------------------------------------
local lines = Hover()
Expect(lines[1].left == "Backpack" and lines[2].left == "16 free slots", "Blizzard's lines kept first")
Expect(lines[4].left == "Your Riches", "header after a blank line")
Expect(lines[5].left == "|cff3fc7ebFrosty Dan|r" and lines[5].right == "900000c", "richest first, class colored")
Expect(lines[6].left == "|cffffffffHealy Dan|r" and lines[6].right == "50000c", "current character listed")
Expect(lines[7].left == "Total" and lines[7].right == "950000c", "total of shown characters only")
Expect(#lines == 7, "hidden character and other realm left out (got " .. #lines .. " lines)")
Expect(GameTooltip.shown, "tooltip re-shown after adding lines")

-- Hovering again doesn't duplicate (tooltip is rebuilt by Blizzard every time)
Expect(#Hover() == 7, "no duplicate lines on second hover")

-- Gold changes are picked up
player.money = 60000
Fire("PLAYER_MONEY")
Expect(me.money == 60000, "PLAYER_MONEY updates saved gold")

-- Class colors off, total off
DansRichesDB.classColors = false
DansRichesDB.showTotal = false
lines = Hover()
Expect(lines[5].left == "Frosty Dan", "plain name with class colors off")
Expect(#lines == 6, "no total line when turned off")

-- Only one shown character: no total even when on
DansRichesDB.showTotal = true
DansRichesDB.realms.Camelot["Frosty Dan"].shown = false
lines = Hover()
Expect(#lines == 5 and lines[5].left == "Healy Dan", "single character, no total")

-- Nothing shown: tooltip untouched
me.shown = false
Expect(#Hover() == 2, "no section when every character is hidden")

-- Quick keybind mode: Blizzard skips its tooltip, so we must not add to someone else's
me.shown = true
local other = NewFrame()
GameTooltip:SetOwner(other)
GameTooltip:AddLine("Some other tooltip")
GameTooltip:Show()
T.SetKeybindMode(true)
lines = Hover()
T.SetKeybindMode(false)
Expect(#lines == 1 and GameTooltip.owner == other, "another frame's tooltip left alone")

-- Options page ---------------------------------------------------------------------------------
me.shown, DansRichesDB.realms.Camelot["Frosty Dan"].shown = true, true
DansRichesDB.classColors = true
ns.RefreshOptions()
local rows = ns.optionRows
local visible = {}
for _, row in ipairs(rows) do if row.shown then visible[#visible + 1] = row end end
Expect(#visible == 4, "options list every character on every realm (got " .. #visible .. ")")
Expect(visible[1].charName == "Frosty Dan" and visible[1].realm == "Camelot", "this realm first, richest first")
Expect(visible[4].realm == "Elsewhere", "other realms after")
Expect(visible[3].check.checked == false, "hidden character unticked")
Expect(visible[1].name.text == "|cff3fc7ebFrosty Dan|r", "class colored in the list")
local myRow
for _, row in ipairs(visible) do if row.charName == "Healy Dan" then myRow = row end end
Expect(myRow.forget.enabled == false, "can't forget the character you're on")
Expect(visible[1].forget.enabled == true, "can forget an alt")

-- Untick a character in the list -> gone from the tooltip
visible[1].check.checked = false
visible[1].check.scripts.OnClick(visible[1].check)
Expect(DansRichesDB.realms.Camelot["Frosty Dan"].shown == false, "unticking hides the character")

-- Class colors checkbox
local cc = ns.optionChecks.classColors
cc.checked = false
cc.scripts.OnClick(cc)
Expect(DansRichesDB.classColors == false, "class colors checkbox saves")
Expect(visible[1].name.text == "Frosty Dan", "list redrawn without class colors")

-- Forget an alt
visible[4].forget.scripts.OnClick(visible[4].forget)
Expect(T.Popup() and T.Popup().which == "DANSRICHES_FORGET" and T.Popup().data.name == "Far Dan", "forget asks first")
StaticPopupDialogs.DANSRICHES_FORGET.OnAccept(nil, T.Popup().data)
Expect(DansRichesDB.realms.Elsewhere == nil, "forgetting the last character drops the realm")

-- Defaults
SlashCmdList.DANSRICHES("reset")
Expect(DansRichesDB.classColors == true and DansRichesDB.realms.Camelot["Frosty Dan"].shown == true, "reset restores defaults and shows everyone")

T.Done()
