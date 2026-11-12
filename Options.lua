-- Dan's Riches: options page (Esc > Options > AddOns > Dan's Riches) and slash commands
local _, ns = ...

local ROW_HEIGHT = 26
local panel, scroll, content
local checks = {}
local rows, headers = {}, {}

local SETTINGS = {
    { key = "classColors", label = "Class colors",
      desc = "Color each character's name by class in the tooltip and in the list below." },
    { key = "showTotal", label = "Show total",
      desc = "Add a Total line with all the shown characters' gold together." },
    { key = "sortByGold", label = "Richest first",
      desc = "Sort characters by gold. Turn it off to put them in your own order with the arrows in the list below.",
      set = function(on) ns.SetSortByGold(on) end },
}

local function PlayClickSound(on)
    if PlaySound and SOUNDKIT then
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
end

---------------------------------------------------------------------------
-- Character list
---------------------------------------------------------------------------
local RefreshList

local function GetHeader(i)
    local header = headers[i]
    if not header then
        header = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetJustifyH("LEFT")
        headers[i] = header
    end
    return header
end

local function GetRow(i)
    local row = rows[i]
    if row then return row end

    row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_HEIGHT)

    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.06)
    highlight:Hide()
    row:EnableMouse(true)
    row:SetScript("OnEnter", function() highlight:Show() end)
    row:SetScript("OnLeave", function() highlight:Hide() end)

    row.check = CreateFrame("CheckButton", "DansRichesRow" .. i, row, "UICheckButtonTemplate")
    row.check:SetSize(24, 24)
    row.check:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        row.char.shown = on
        PlayClickSound(on)
    end)
    row.check:HookScript("OnEnter", function() highlight:Show() end)
    row.check:HookScript("OnLeave", function() highlight:Hide() end)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.name:SetJustifyH("LEFT")

    row.level = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.level:SetPoint("LEFT", row.name, "RIGHT", 8, 0)

    -- Up/down arrows for the own order (hidden while sorting by gold)
    row.down = CreateFrame("Button", nil, row, "UIPanelScrollDownButtonTemplate")
    row.down:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.up = CreateFrame("Button", nil, row, "UIPanelScrollUpButtonTemplate")
    row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
    local function Move(delta)
        ns.Move(row.realm, row.charName, delta)
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
        RefreshList()
    end
    row.up:SetScript("OnClick", function() Move(-1) end)
    row.down:SetScript("OnClick", function() Move(1) end)
    for _, arrow in ipairs({ row.up, row.down }) do
        arrow:HookScript("OnEnter", function() highlight:Show() end)
        arrow:HookScript("OnLeave", function() highlight:Hide() end)
    end

    row.money = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.money:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.money:SetJustifyH("RIGHT")

    rows[i] = row
    return row
end

RefreshList = function()
    if not content then return end
    for _, row in ipairs(rows) do row:Hide() end
    for _, header in ipairs(headers) do header:Hide() end

    local y, rowCount, headerCount = 0, 0, 0
    local width = content:GetWidth()
    for _, realm in ipairs(ns.Realms()) do
        headerCount = headerCount + 1
        local header = GetHeader(headerCount)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y - 6)
        header:SetText(realm == ns.RealmKey() and (realm .. "  |cff888888(this realm)|r") or realm)
        header:Show()
        y = y - 26

        local list = ns.Characters(realm)
        local ownOrder = not ns.db.sortByGold
        for index, entry in ipairs(list) do
            rowCount = rowCount + 1
            local row = GetRow(rowCount)
            row.realm, row.charName, row.char = realm, entry.name, entry.char
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            row:SetWidth(width)
            row.check:SetChecked(entry.char.shown ~= false)
            row.name:SetText(ns.NameText(entry.name, entry.char))
            row.level:SetText(entry.char.level and ("Level " .. entry.char.level) or "")
            row.money:SetText(ns.MoneyText(entry.char.money))
            row.up:SetShown(ownOrder)
            row.down:SetShown(ownOrder)
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #list)
            row.money:ClearAllPoints()
            if ownOrder then
                row.money:SetPoint("RIGHT", row.up, "LEFT", -10, 0)
            else
                row.money:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            end
            row:Show()
            y = y - ROW_HEIGHT
        end
        y = y - 6
    end
    content:SetHeight(math.max(-y, 1))
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function Refresh()
    ns.SaveThisCharacter()
    for key, check in pairs(checks) do check:SetChecked(ns.db[key] == true) end
    RefreshList()
end

local function AddCheck(setting, y)
    local check = CreateFrame("CheckButton", "DansRichesOpt_" .. setting.key, panel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    local label = check.Text or _G[check:GetName() .. "Text"]
    label:SetFontObject("GameFontNormal")
    label:SetText(setting.label)

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 28, -2)
    desc:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.72, 0.72, 0.72)
    desc:SetText(setting.desc)

    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if setting.set then setting.set(on) else ns.db[setting.key] = on end
        PlayClickSound(on)
        RefreshList() -- class colors show in the list too
    end)
    checks[setting.key] = check
end

local function Reset()
    ns.ResetSettings()
    Refresh()
    ns.Print("Settings reset; every character is shown again.")
end

ns.OnLogin(function()
    panel = CreateFrame("Frame", "DansRichesOptionsPanel", UIParent)
    panel.name = ns.TITLE

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.TITLE)

    local intro = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    intro:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("Hover your backpack to see how much gold your characters on this realm have.")

    local y = -70
    for _, setting in ipairs(SETTINGS) do
        AddCheck(setting, y)
        y = y - 56
    end

    local listTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    listTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y - 8)
    listTitle:SetText("Characters")

    local listDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    listDesc:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -6)
    listDesc:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    listDesc:SetJustifyH("LEFT")
    listDesc:SetTextColor(0.72, 0.72, 0.72)
    listDesc:SetText("Ticked characters show up in the tooltip. Every character is added here when you log in on them, and their gold is updated while you play them.")

    local inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y - 58)
    inset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 48)

    scroll = CreateFrame("ScrollFrame", "DansRichesScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 4)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
        RefreshList()
    end)

    local defaults = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    defaults:SetSize(120, 24)
    defaults:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 14)
    defaults:SetText("Defaults")
    defaults:SetScript("OnClick", Reset)

    panel:SetScript("OnShow", Refresh)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        panel.category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
        Settings.RegisterAddOnCategory(panel.category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)

-- The game doesn't let addons open the Options window in combat, so say so instead.
local function OpenOptions()
    if InCombatLockdown() then
        ns.Print("Can't open the options during combat. Try again when combat ends.")
    elseif panel and panel.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(panel.category:GetID())
    elseif panel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel) -- the first call only opens the window
    end
end

SLASH_DANSRICHES1 = "/riches"
SLASH_DANSRICHES2 = "/dansriches"
SlashCmdList.DANSRICHES = function(msg)
    local cmd = strtrim((msg or ""):lower())
    if cmd == "" or cmd == "options" or cmd == "config" then
        OpenOptions()
    elseif cmd == "reset" then
        Reset()
    else
        ns.Print("Commands: |cffffd100/riches|r options, |cffffd100/riches reset|r")
    end
end

-- Exposed for the offline tests.
ns.RefreshOptions = Refresh
ns.optionRows = rows
ns.optionChecks = checks
