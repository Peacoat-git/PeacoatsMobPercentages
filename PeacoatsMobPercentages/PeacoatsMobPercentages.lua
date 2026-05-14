-- PeacoatsMobPercentages
-- Shows the forces (trash) % contribution on NPC tooltips inside supported dungeons.
-- Features: font size control, enable/disable toggle, above/below placement.
-- WoW API: 12.0.5

local ADDON_NAME = "PeacoatsMobPercentages"
local ICON_PATH  = "Interface\\AddOns\\PeacoatsMobPercentages\\Media\\icon"

-- Shared namespace (Data.lua writes npcData / zoneData here)
PeacoatsMobPct = {}

-- Module-level reference to the settings category object.
-- Stored here so the slash command can call Settings.OpenToCategory(categoryRef)
-- rather than passing a string (which throws "outside of expected range" error).
local settingsCategory = nil

-- ── Default saved variables ────────────────────────────────────────────────────

local DEFAULTS = {
    enabled   = true,
    fontSize  = 12,      -- GameTooltipText baseline is 12pt
    placement = "below", -- "above" | "below"
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function applyDefaults()
    PeacoatsMobPctDB = PeacoatsMobPctDB or {}
    for k, v in pairs(DEFAULTS) do
        if PeacoatsMobPctDB[k] == nil then
            PeacoatsMobPctDB[k] = v
        end
    end
end

local function cfg()
    return PeacoatsMobPctDB
end

-- ── NPC ID extraction ─────────────────────────────────────────────────────────

local function getNPCID(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end
    -- GUID format: "Creature-0-REALM-SERVER-ZONE-NPCID-SPAWNUID"
    local npcID = tonumber(select(6, strsplit("-", guid)))
    return npcID
end

-- ── Forces line text ──────────────────────────────────────────────────────────

local function buildForcesText(data)
    local pct = (data.count / data.total) * 100
    return string.format("|cff00ff96Forces: %.2f%%|r", pct)
end

-- ── "Above" injection ─────────────────────────────────────────────────────────
-- WoW has no API to insert a line at an arbitrary tooltip position.
-- Standard technique (TipTac, idTip, etc.):
--   1. Snapshot all line texts + colours
--   2. ClearLines()
--   3. AddLine() our custom line first
--   4. Re-add all original lines in order

local function injectAbove(tooltip, forcesText)
    local numLines = tooltip:NumLines()
    if numLines == 0 then return end

    local tooltipName = tooltip:GetName()
    local lines = {}

    for i = 1, numLines do
        local left  = _G[tooltipName .. "TextLeft"  .. i]
        local right = _G[tooltipName .. "TextRight" .. i]

        local lr, lg, lb = 1, 1, 1
        local rr, rg, rb = 1, 1, 1
        local leftText, rightText, leftWrap

        if left  then leftText  = left:GetText();  lr, lg, lb = left:GetTextColor();  leftWrap = left:GetWrapped() end
        if right then rightText = right:GetText(); rr, rg, rb = right:GetTextColor() end

        lines[i] = {
            leftText = leftText, rightText = rightText,
            leftR = lr, leftG = lg, leftB = lb,
            rightR = rr, rightG = rg, rightB = rb,
            leftWrap = leftWrap or false,
        }
    end

    tooltip:ClearLines()
    tooltip:AddLine(forcesText)

    for i = 1, numLines do
        local l = lines[i]
        if l.rightText and l.rightText ~= "" then
            tooltip:AddDoubleLine(
                l.leftText or "", l.rightText,
                l.leftR, l.leftG, l.leftB,
                l.rightR, l.rightG, l.rightB)
        elseif l.leftText and l.leftText ~= "" then
            tooltip:AddLine(l.leftText, l.leftR, l.leftG, l.leftB, l.leftWrap)
        end
    end
end

-- ── Font-size application ─────────────────────────────────────────────────────

local function applyFontSize(tooltip, lineIndex)
    local fs = cfg().fontSize
    if fs == DEFAULTS.fontSize then return end
    local fontString = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
    if not fontString then return end
    local fontPath, _, flags = fontString:GetFont()
    if fontPath then fontString:SetFont(fontPath, fs, flags or "") end
end

-- ── Main tooltip hook ─────────────────────────────────────────────────────────

local function OnTooltipSetUnit(tooltip)
    if not cfg().enabled then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" then return end

    local currentZone = C_Map.GetBestMapForUnit("player")
    if not currentZone or not PeacoatsMobPct.zoneData[currentZone] then return end

    local _, unit = tooltip:GetUnit()
    if not unit then return end
    if not UnitExists(unit) or UnitIsPlayer(unit) then return end

    local npcID = getNPCID(unit)
    if not npcID then return end

    local data = PeacoatsMobPct.npcData[npcID]
    if not data or data.count == 0 then return end

    local forcesText = buildForcesText(data)

    if cfg().placement == "above" then
        injectAbove(tooltip, forcesText)
        applyFontSize(tooltip, 1)
    else
        tooltip:AddLine(forcesText)
        applyFontSize(tooltip, tooltip:NumLines())
    end

    tooltip:Show()
end

-- ── Settings panel (Interface > AddOns) ──────────────────────────────────────
-- Layout constants – tweak these to control spacing between elements.

local PAD_LEFT      = 16   -- left margin for all elements
local PAD_ICON_H    = 70   -- vertical space consumed by the icon/title header block
local SEC_GAP       = 18   -- gap above each section header
local SEC_HDR_H     = 20   -- height of a section header FontString
local DESC_H        = 18   -- height of a one-line description FontString
local CB_H          = 32   -- height of a CheckButton widget
local SLIDER_H      = 50   -- height of an OptionsSlider widget (thumb + labels)
local RADIO_H       = 24   -- height of each radio button row

local function createSettingsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Peacoat's Mob Percentages"

    -- ── Header: icon + title ──────────────────────────────────────────────

    local iconWidget = panel:CreateTexture(nil, "ARTWORK")
    iconWidget:SetSize(48, 48)
    iconWidget:SetPoint("TOPLEFT", PAD_LEFT, -12)
    iconWidget:SetTexture(ICON_PATH)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", iconWidget, "TOPRIGHT", 10, -4)
    title:SetText("Peacoat's Mob Percentages")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Shows forces % on NPC tooltips inside supported Mythic+ dungeons.")

    -- Running cursor; starts below the header block
    local y = -(PAD_ICON_H)

    -- ── Section: General ──────────────────────────────────────────────────

    y = y - SEC_GAP
    local sectionEnable = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionEnable:SetPoint("TOPLEFT", PAD_LEFT, y)
    sectionEnable:SetText("General")

    y = y - SEC_HDR_H
    local enableCB = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    enableCB:SetPoint("TOPLEFT", PAD_LEFT, y)
    enableCB.Text:SetText("Enable Peacoat's Mob Percentages")
    enableCB.tooltipText = "Toggle the addon on or off. A UI reload is recommended after changing this."
    enableCB:SetChecked(cfg().enabled)
    enableCB:SetScript("OnClick", function(self)
        cfg().enabled = self:GetChecked()
        StaticPopupDialogs["PEACOATSMOBPCT_RELOAD"] = {
            text = "Peacoat's Mob Percentages: Reload the UI now to apply the enable/disable change?",
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("PEACOATSMOBPCT_RELOAD")
    end)

    -- ── Section: Font Size ────────────────────────────────────────────────

    y = y - CB_H - SEC_GAP
    local sectionFont = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionFont:SetPoint("TOPLEFT", PAD_LEFT, y)
    sectionFont:SetText("Font Size")

    y = y - SEC_HDR_H
    local fontDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fontDesc:SetPoint("TOPLEFT", PAD_LEFT, y)
    fontDesc:SetText("Adjust the size of the Forces % line. Default is 12 (matches standard tooltip text).")

    y = y - DESC_H - 4
    local fontSlider = CreateFrame("Slider", "PeacoatsMobPctFontSlider", panel, "OptionsSliderTemplate")
    fontSlider:SetPoint("TOPLEFT", PAD_LEFT + 4, y)
    fontSlider:SetMinMaxValues(8, 20)
    fontSlider:SetValueStep(1)
    fontSlider:SetObeyStepOnDrag(true)
    fontSlider:SetValue(cfg().fontSize)
    fontSlider:SetWidth(220)
    _G[fontSlider:GetName() .. "Low"]:SetText("8")
    _G[fontSlider:GetName() .. "High"]:SetText("20")
    _G[fontSlider:GetName() .. "Text"]:SetText("Size: " .. cfg().fontSize .. " pt")
    fontSlider:SetScript("OnValueChanged", function(self, val)
        local v = math.floor(val + 0.5)
        cfg().fontSize = v
        _G[self:GetName() .. "Text"]:SetText("Size: " .. v .. " pt")
    end)

    -- ── Section: Line Placement ───────────────────────────────────────────

    y = y - SLIDER_H - SEC_GAP
    local sectionPlace = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionPlace:SetPoint("TOPLEFT", PAD_LEFT, y)
    sectionPlace:SetText("Line Placement")

    y = y - SEC_HDR_H
    local placeDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    placeDesc:SetPoint("TOPLEFT", PAD_LEFT, y)
    placeDesc:SetText("Choose where the Forces % line appears relative to existing tooltip content.")

    y = y - DESC_H - 6
    local rbBelow = CreateFrame("CheckButton", "PeacoatsMobPctRbBelow", panel, "UIRadioButtonTemplate")
    rbBelow:SetPoint("TOPLEFT", PAD_LEFT, y)
    _G[rbBelow:GetName() .. "Text"]:SetText("Below  –  appended after all existing tooltip lines  (default)")

    y = y - RADIO_H
    local rbAbove = CreateFrame("CheckButton", "PeacoatsMobPctRbAbove", panel, "UIRadioButtonTemplate")
    rbAbove:SetPoint("TOPLEFT", PAD_LEFT, y)
    _G[rbAbove:GetName() .. "Text"]:SetText("Above  –  prepended before existing tooltip lines")

    local function updateRadios()
        if cfg().placement == "above" then
            rbAbove:SetChecked(true)
            rbBelow:SetChecked(false)
        else
            rbBelow:SetChecked(true)
            rbAbove:SetChecked(false)
        end
    end
    updateRadios()

    rbBelow:SetScript("OnClick", function() cfg().placement = "below"; updateRadios() end)
    rbAbove:SetScript("OnClick", function() cfg().placement = "above"; updateRadios() end)

    -- ── Sync on open ──────────────────────────────────────────────────────

    panel:SetScript("OnShow", function()
        enableCB:SetChecked(cfg().enabled)
        fontSlider:SetValue(cfg().fontSize)
        _G["PeacoatsMobPctFontSliderText"]:SetText("Size: " .. cfg().fontSize .. " pt")
        updateRadios()
    end)

    -- Register and STORE the category object so /pmp can open it correctly.
    -- Settings.OpenToCategory() requires the category object, NOT a string name.
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(settingsCategory)
end

-- ── Slash command /pmp ────────────────────────────────────────────────────────

local function registerSlash()
    SLASH_PEACOATSMOBPCT1 = "/pmp"
    SlashCmdList["PEACOATSMOBPCT"] = function(msg)
        msg = (msg or ""):lower():match("^%s*(.-)%s*$")

        if msg == "" then
            -- OpenToCategory requires the numeric category ID, not the table itself.
            -- The category table returned by RegisterCanvasLayoutCategory contains an
            -- 'ID' field which is the integer C_SettingsUtil.OpenSettingsPanel expects.
            if settingsCategory then
                Settings.OpenToCategory(settingsCategory:GetID())
            end
        elseif msg == "enable" then
            cfg().enabled = true
            print("|cff00ff96PeacoatsMobPct:|r Enabled.")
        elseif msg == "disable" then
            cfg().enabled = false
            print("|cff00ff96PeacoatsMobPct:|r Disabled.")
        elseif msg == "above" then
            cfg().placement = "above"
            print("|cff00ff96PeacoatsMobPct:|r Placement → Above.")
        elseif msg == "below" then
            cfg().placement = "below"
            print("|cff00ff96PeacoatsMobPct:|r Placement → Below.")
        elseif msg:match("^size%s+(%d+)$") then
            local size = tonumber(msg:match("^size%s+(%d+)$"))
            if size and size >= 8 and size <= 20 then
                cfg().fontSize = size
                print("|cff00ff96PeacoatsMobPct:|r Font size set to " .. size .. "pt.")
            else
                print("|cff00ff96PeacoatsMobPct:|r Font size must be between 8 and 20.")
            end
        else
            print("|cff00ff96Peacoat's Mob Percentages|r – commands:")
            print("  |cffffff00/pmp|r               Open settings panel")
            print("  |cffffff00/pmp enable|r         Enable the addon")
            print("  |cffffff00/pmp disable|r        Disable the addon")
            print("  |cffffff00/pmp above|r          Place forces line above tooltip")
            print("  |cffffff00/pmp below|r          Place forces line below tooltip")
            print("  |cffffff00/pmp size <8-20>|r    Set forces line font size")
        end
    end
end

-- ── Addon init ────────────────────────────────────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName ~= ADDON_NAME then return end

    applyDefaults()
    createSettingsPanel()
    registerSlash()

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetUnit)

    self:UnregisterEvent("ADDON_LOADED")
    print("|cff00ff96Peacoat's Mob Percentages|r loaded.  Type |cffffff00/pmp|r for options.")
end)
