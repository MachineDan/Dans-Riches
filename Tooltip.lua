-- Dan's Riches: backpack tooltip
-- Adds your characters on this realm and their gold under the backpack button's tooltip.
local _, ns = ...

function ns.AddToTooltip(tooltip)
    if not ns.db then return end
    ns.SaveThisCharacter() -- so the current character's line is always up to date

    local rows, total = {}, 0
    for _, entry in ipairs(ns.Characters(ns.RealmKey())) do
        if entry.char.shown ~= false then
            rows[#rows + 1] = entry
            total = total + (entry.char.money or 0)
        end
    end
    if #rows == 0 then return end

    tooltip:AddLine(" ")
    local gold = NORMAL_FONT_COLOR
    tooltip:AddLine("Your Riches", gold and gold.r or 1, gold and gold.g or 0.82, gold and gold.b or 0)
    for _, entry in ipairs(rows) do
        tooltip:AddDoubleLine(ns.NameText(entry.name, entry.char), ns.MoneyText(entry.char.money), 1, 1, 1, 1, 1, 1)
    end
    if ns.db.showTotal and #rows > 1 then
        tooltip:AddDoubleLine("Total", ns.MoneyText(total), gold and gold.r or 1, gold and gold.g or 0.82, gold and gold.b or 0, 1, 1, 1)
    end
    tooltip:Show() -- resize to fit the new lines
end

local function AfterBackpackTooltip(button)
    if GameTooltip:GetOwner() == button and GameTooltip:IsShown() then
        ns.AddToTooltip(GameTooltip)
    end
end

ns.OnLogin(function()
    local button = MainMenuBarBackpackButton
    if not button then return end
    -- Blizzard's backpack OnEnter calls self:OnEnterInternal(), which builds the
    -- tooltip ("Backpack", free slots) and shows it. Hooking it puts our lines after
    -- Blizzard's every time the tooltip is built, without touching Blizzard code.
    if type(button.OnEnterInternal) == "function" then
        hooksecurefunc(button, "OnEnterInternal", AfterBackpackTooltip)
    else
        button:HookScript("OnEnter", AfterBackpackTooltip)
    end
end)
