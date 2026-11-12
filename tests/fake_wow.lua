-- Fake WoW API shared by the offline tests. Returns helpers; sets globals.
local T = {}
local failures, checks = 0, 0
function T.Expect(cond, msg)
    checks = checks + 1
    if not cond then
        failures = failures + 1
        io.write("FAIL " .. msg .. "\n")
    end
end
function T.Done()
    io.write(string.format("%d checks, %d failures\n", checks, failures))
    os.exit(failures == 0 and 0 or 1)
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
backpack = NewFrame("MainMenuBarBackpackButton")
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


T.player, T.backpack, T.Fire, T.Hover, T.NewFrame = player, backpack, Fire, Hover, NewFrame
T.Popup = function() return popup end
T.SetKeybindMode = function(on) keybindMode = on end

-- Pending C_Timer.After callbacks; T.RunTimers() fires them one second at a time.
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function T.RunTimers(max)
    local n = 0
    while #timers > 0 and n < (max or 1000) do
        local fn = table.remove(timers, 1)
        fn()
        n = n + 1
    end
    return n
end

local originalOnEnter = backpack.OnEnterInternal
-- Loading again acts like a fresh session: the old copy's frames stop listening.
function T.LoadAddon()
    for _, frame in ipairs(frames) do frame.events = {} end
    backpack.OnEnterInternal = originalOnEnter
    local ns = {}
    for _, file in ipairs({ "Core.lua", "Tooltip.lua", "Options.lua" }) do
        assert(loadfile(file))("DansRiches", ns)
    end
    return ns
end

return T
