-- Offline checks for Dan's Riches with a fake WoW API.
-- Run from the repo root: luajit tests/test_riches.lua
local failures, checks = 0, 0
local function Expect(cond, msg)
    checks = checks + 1
    if not cond then
        failures = failures + 1
        io.write("FAIL " .. msg .. "\n")
    end
end

-- Fake frames ----------------------------------------------------------------------------------
local frames = {}
local FrameMethods = {}
function FrameMethods:SetScript(name, fn) self.scripts[name] = fn end
function FrameMethods:GetScript(name) return self.scripts[name] end
function FrameMethods:HookScript(name, fn)
    local old = self.scripts[name]
    self.scripts[name] = function(...) if old then old(...) end fn(...) end
end
function FrameMethods:RegisterEvent(e) self.events[e] = true end
function FrameMethods:Show() self.shown = true end
function FrameMethods:Hide() self.shown = false end
function FrameMethods:IsShown() return self.shown end
function FrameMethods:SetText(t) self.text = t end
function FrameMethods:GetText() return self.text end
function FrameMethods:SetChecked(on) self.checked = on and true or false end
function FrameMethods:GetChecked() return self.checked end
function FrameMethods:SetEnabled(on) self.enabled = on end
function FrameMethods:GetName() return self.name end
function FrameMethods:GetWidth() return self.width or 500 end
function FrameMethods:SetWidth(w) self.width = w end
function FrameMethods:SetHeight(h) self.height = h end
function FrameMethods:CreateFontString() return NewFrame() end
function FrameMethods:CreateTexture() return NewFrame() end
local function NoOp() end
local FrameMeta = { __index = function(_, k)
    if FrameMethods[k] then return FrameMethods[k] end
    if k ~= "Text" and k:match("^%u") then return NoOp end
end }
function NewFrame(name)
    local f = setmetatable({ scripts = {}, events = {}, shown = true, name = name }, FrameMeta)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = function(kind, name)
    if kind == "CheckButton" and name then NewFrame(name .. "Text") end
    return NewFrame(name)
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- Fake game state -------------------------------------------------------------------------------
local player = { first = "Healy", surname = "Dan", realm = "Camelot", class = "PRIEST", level = 42, money = 50000 }
UnitName = function() return player.first, player.surname end
GetRealmName = function() return player.realm end
UnitClass = function() return "Priest", player.class end
UnitLevel = function() return player.level end
UnitFactionGroup = function() return "Alliance" end
GetMoney = function() return player.money end
GetMoneyString = function(c) return c .. "c" end
time = os.time
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
print = function() end
geterrorhandler = function() return function(e) error(e) end end
InCombatLockdown = function() return false end
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
RAID_CLASS_COLORS = {
    PRIEST = { WrapTextInColorCode = function(_, t) return "|cffffffff" .. t .. "|r" end },
    MAGE = { WrapTextInColorCode = function(_, t) return "|cff3fc7eb" .. t .. "|r" end },
}
SlashCmdList = {}
StaticPopupDialogs = {}
local popup
StaticPopup_Show = function(which, a, b, data) popup = { which = which, text = a, data = data } end
hooksecurefunc = function(t, k, fn)
    if type(t) == "string" then t, k, fn = _G, t, k end
    local old = t[k]
    t[k] = function(...) local r = old(...) fn(...) return r end
end

-- Blizzard's backpack button and the shared tooltip
GameTooltip = NewFrame("GameTooltip")
GameTooltip.lines = {}
function GameTooltip:SetOwner(o) self.owner = o; self.lines = {}; self.shown = false end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = { left = t } end
function GameTooltip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { left = l, right = r } end
local backpack = NewFrame("MainMenuBarBackpackButton")
keybindMode = false
function backpack:OnEnterInternal()
    if keybindMode then return end
    GameTooltip:SetOwner(self)
    GameTooltip:AddLine("Backpack")
    GameTooltip:AddLine("16 free slots")
    GameTooltip:Show()
end
backpack.scripts.OnEnter = function(self) self:OnEnterInternal() end -- like the XML method="BagSlotOnEnter"

local function Hover()
    backpack.scripts.OnEnter(backpack)
    return GameTooltip.lines
end

-- Saved data from earlier sessions: two alts on this realm, one elsewhere.
DansRichesDB = { realms = {
    Camelot = {
        ["Frosty Dan"] = { money = 900000, class = "MAGE", level = 60, shown = true },
        ["Hidden Dan"] = { money = 100, class = "MAGE", level = 10, shown = false },
    },
    Elsewhere = { ["Far Dan"] = { money = 1, class = "MAGE", level = 1, shown = true } },
} }

local ns = {}
for _, file in ipairs({ "Core.lua", "Tooltip.lua", "Options.lua" }) do
    assert(loadfile(file))("DansRiches", ns)
end
Fire("PLAYER_LOGIN")

-- Login ----------------------------------------------------------------------------------------
local me = DansRichesDB.realms.Camelot["Healy Dan"]
Expect(me ~= nil, "current character saved under its full Forever name")
Expect(me and me.money == 50000 and me.class == "PRIEST" and me.level == 42 and me.shown == true, "current character data")
Expect(DansRichesDB.classColors == true and DansRichesDB.showTotal == true, "defaults filled in")

-- Tooltip --------------------------------------------------------------------------------------
local lines = Hover()
Expect(lines[1].left == "Backpack" and lines[2].left == "16 free slots", "Blizzard's lines kept first")
Expect(lines[4].left == "Dan's Riches", "header after a blank line")
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
keybindMode = true
lines = Hover()
keybindMode = false
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
Expect(popup and popup.which == "DANSRICHES_FORGET" and popup.data.name == "Far Dan", "forget asks first")
StaticPopupDialogs.DANSRICHES_FORGET.OnAccept(nil, popup.data)
Expect(DansRichesDB.realms.Elsewhere == nil, "forgetting the last character drops the realm")

-- Defaults
SlashCmdList.DANSRICHES("reset")
Expect(DansRichesDB.classColors == true and DansRichesDB.realms.Camelot["Frosty Dan"].shown == true, "reset restores defaults and shows everyone")

io.write(string.format("%d checks, %d failures\n", checks, failures))
os.exit(failures == 0 and 0 or 1)
