--[[
    MedaButtonBag - SettingsPanel.lua
    Configuration UI for the button bag
]]

local addonName, MedaButtonBag = ...

-- SettingsPanel module
local SettingsPanel = {}
MedaButtonBag.SettingsPanel = SettingsPanel

-- UI Constants
local PANEL_WIDTH = 400
local PANEL_HEIGHT = 500
local SECTION_SPACING = 20
local ITEM_SPACING = 10
local LABEL_WIDTH = 140

-- Get MedaUI library for theming
local MedaUI = LibStub("MedaUI-1.0")
local THEME = MedaUI:GetTheme()

-- Main panel frame
local panel = nil
local scrollFrame = nil
local scrollContent = nil

-- Forward declarations
local CreateSection, CreateLabeledWidget, RefreshButtonList

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Create a section header
local function CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText(text)
    header:SetTextColor(unpack(THEME.gold))
    return header
end

-- Create a label
local function CreateLabel(parent, text, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint(point, relativeTo, relativePoint, x, y)
    label:SetText(text)
    label:SetTextColor(unpack(THEME.text))
    label:SetJustifyH("LEFT")
    label:SetWidth(LABEL_WIDTH)
    return label
end

-- Create a horizontal divider
local function CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 10, yOffset)
    divider:SetPoint("TOPRIGHT", -10, yOffset)
    divider:SetHeight(1)
    divider:SetColorTexture(unpack(THEME.border))
    return divider
end

-- ============================================================================
-- Panel Creation
-- ============================================================================

local function CreatePanel()
    if panel then return panel end

    -- Use MedaUI Panel
    panel = MedaUI:CreatePanel("MedaButtonBagSettings", PANEL_WIDTH, PANEL_HEIGHT, "MedaButtonBag Settings")
    panel:SetPoint("CENTER")
    panel:Hide()

    -- Allow ESC to close
    tinsert(UISpecialFrames, "MedaButtonBagSettings")

    local content = panel:GetContent()

    -- Create scroll frame for content
    scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

    -- Style the scrollbar
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 2, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 2, 16)
    end

    -- Scroll content frame
    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(PANEL_WIDTH - 40, 800)  -- Will be resized based on content
    scrollFrame:SetScrollChild(scrollContent)

    -- Track Y position for layout
    local yPos = -10

    -- ========================================================================
    -- General Section
    -- ========================================================================
    CreateSectionHeader(scrollContent, "General", yPos)
    yPos = yPos - 25

    -- Enable/Disable checkbox
    local enableCheck = MedaUI:CreateCheckbox(scrollContent, "Enable Button Collection")
    enableCheck:SetPoint("TOPLEFT", 10, yPos)
    enableCheck:SetChecked(MedaButtonBag.db.settings.enabled)
    enableCheck.OnValueChanged = function(self, checked)
        if MedaButtonBag.ButtonManager then
            MedaButtonBag.ButtonManager:SetEnabled(checked)
        end
    end
    yPos = yPos - 30

    -- Lock/Unlock checkbox
    local lockCheck = MedaUI:CreateCheckbox(scrollContent, "Lock Container (Auto-Hide)")
    lockCheck:SetPoint("TOPLEFT", 10, yPos)
    lockCheck:SetChecked(MedaButtonBag.db.settings.locked)
    lockCheck.OnValueChanged = function(self, checked)
        MedaButtonBag.db.settings.locked = checked
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:UpdateLockState()
        end
    end
    yPos = yPos - 30

    CreateDivider(scrollContent, yPos)
    yPos = yPos - SECTION_SPACING

    -- ========================================================================
    -- Layout Section
    -- ========================================================================
    CreateSectionHeader(scrollContent, "Layout", yPos)
    yPos = yPos - 30

    -- Columns slider
    local colLabel = CreateLabel(scrollContent, "Icons per Row:", "TOPLEFT", scrollContent, "TOPLEFT", 10, yPos)
    local colSlider = MedaUI:CreateSlider(scrollContent, 180, 1, 12, 1)
    colSlider:SetPoint("LEFT", colLabel, "RIGHT", 10, 0)
    colSlider:SetValue(MedaButtonBag.db.settings.columns)
    colSlider.OnValueChanged = function(self, value)
        MedaButtonBag.db.settings.columns = value
        if MedaButtonBag.ButtonManager then
            MedaButtonBag.ButtonManager:RefreshLayout()
        end
    end
    yPos = yPos - 40

    -- Max rows slider
    local rowLabel = CreateLabel(scrollContent, "Max Rows (0=∞):", "TOPLEFT", scrollContent, "TOPLEFT", 10, yPos)
    local rowSlider = MedaUI:CreateSlider(scrollContent, 180, 0, 10, 1)
    rowSlider:SetPoint("LEFT", rowLabel, "RIGHT", 10, 0)
    rowSlider:SetValue(MedaButtonBag.db.settings.rows)
    rowSlider.OnValueChanged = function(self, value)
        MedaButtonBag.db.settings.rows = value
        if MedaButtonBag.ButtonManager then
            MedaButtonBag.ButtonManager:RefreshLayout()
        end
    end
    yPos = yPos - 40

    -- Button size slider
    local sizeLabel = CreateLabel(scrollContent, "Button Size:", "TOPLEFT", scrollContent, "TOPLEFT", 10, yPos)
    local sizeSlider = MedaUI:CreateSlider(scrollContent, 180, 16, 48, 2)
    sizeSlider:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
    sizeSlider:SetValue(MedaButtonBag.db.settings.buttonSize)
    sizeSlider.OnValueChanged = function(self, value)
        MedaButtonBag.db.settings.buttonSize = value
        if MedaButtonBag.ButtonManager then
            MedaButtonBag.ButtonManager:UpdateButtonSizes()
        end
    end
    yPos = yPos - 40

    -- Padding slider
    local padLabel = CreateLabel(scrollContent, "Spacing:", "TOPLEFT", scrollContent, "TOPLEFT", 10, yPos)
    local padSlider = MedaUI:CreateSlider(scrollContent, 180, 0, 12, 1)
    padSlider:SetPoint("LEFT", padLabel, "RIGHT", 10, 0)
    padSlider:SetValue(MedaButtonBag.db.settings.padding)
    padSlider.OnValueChanged = function(self, value)
        MedaButtonBag.db.settings.padding = value
        if MedaButtonBag.ButtonManager then
            MedaButtonBag.ButtonManager:RefreshLayout()
        end
    end
    yPos = yPos - 30

    CreateDivider(scrollContent, yPos)
    yPos = yPos - SECTION_SPACING

    -- ========================================================================
    -- Appearance Section
    -- ========================================================================
    CreateSectionHeader(scrollContent, "Appearance", yPos)
    yPos = yPos - 30

    -- Background opacity slider
    local opacityLabel = CreateLabel(scrollContent, "Background Opacity:", "TOPLEFT", scrollContent, "TOPLEFT", 10, yPos)
    local opacitySlider = MedaUI:CreateSlider(scrollContent, 180, 0, 100, 5)
    opacitySlider:SetPoint("LEFT", opacityLabel, "RIGHT", 10, 0)
    opacitySlider:SetValue(MedaButtonBag.db.settings.bgOpacity * 100)
    opacitySlider.OnValueChanged = function(self, value)
        MedaButtonBag.db.settings.bgOpacity = value / 100
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:UpdateBackgroundColor()
        end
    end
    yPos = yPos - 40

    -- Background color picker
    local colorLabel = CreateLabel(scrollContent, "Background Color:", "TOPLEFT", scrollContent, "TOPLEFT", 10, yPos)
    local colorPicker = MedaUI:CreateColorPicker(scrollContent, 24, 24, false)
    colorPicker:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
    local bgColor = MedaButtonBag.db.settings.bgColor
    colorPicker:SetColor(bgColor[1], bgColor[2], bgColor[3], 1)
    colorPicker.OnColorChanged = function(self, r, g, b, a)
        MedaButtonBag.db.settings.bgColor = { r, g, b }
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:UpdateBackgroundColor()
        end
    end
    yPos = yPos - 30

    CreateDivider(scrollContent, yPos)
    yPos = yPos - SECTION_SPACING

    -- ========================================================================
    -- Behavior Section
    -- ========================================================================
    CreateSectionHeader(scrollContent, "Behavior", yPos)
    yPos = yPos - 30

    -- Auto-hide delay slider
    local delayLabel = CreateLabel(scrollContent, "Auto-Hide Delay:", "TOPLEFT", scrollContent, "TOPLEFT", 10, yPos)
    local delaySlider = MedaUI:CreateSlider(scrollContent, 180, 0, 2, 0.1)
    delaySlider:SetPoint("LEFT", delayLabel, "RIGHT", 10, 0)
    delaySlider:SetValue(MedaButtonBag.db.settings.autoHideDelay)
    delaySlider.OnValueChanged = function(self, value)
        MedaButtonBag.db.settings.autoHideDelay = value
    end
    yPos = yPos - 30

    CreateDivider(scrollContent, yPos)
    yPos = yPos - SECTION_SPACING

    -- ========================================================================
    -- Buttons Section
    -- ========================================================================
    CreateSectionHeader(scrollContent, "Collected Buttons", yPos)
    yPos = yPos - 25

    -- Button count label
    local countLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countLabel:SetPoint("TOPLEFT", 10, yPos)
    countLabel:SetTextColor(unpack(THEME.textDim))
    SettingsPanel.countLabel = countLabel
    yPos = yPos - 20

    -- Button list container
    local listContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    listContainer:SetPoint("TOPLEFT", 10, yPos)
    listContainer:SetSize(PANEL_WIDTH - 60, 150)
    listContainer:SetBackdrop(MedaUI:CreateBackdrop(true))
    listContainer:SetBackdropColor(unpack(THEME.backgroundDark))
    listContainer:SetBackdropBorderColor(unpack(THEME.border))
    SettingsPanel.listContainer = listContainer

    -- Button list scroll frame
    local listScroll = CreateFrame("ScrollFrame", nil, listContainer, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 5, -5)
    listScroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(PANEL_WIDTH - 90, 300)
    listScroll:SetScrollChild(listContent)
    SettingsPanel.listContent = listContent

    yPos = yPos - 160

    -- Rescan button
    local rescanBtn = MedaUI:CreateButton(scrollContent, "Rescan Buttons", 120, 26)
    rescanBtn:SetPoint("TOPLEFT", 10, yPos)
    rescanBtn:SetScript("OnClick", function()
        if MedaButtonBag.ButtonCollector then
            MedaButtonBag.ButtonCollector:Rescan()
        end
        RefreshButtonList()
    end)
    yPos = yPos - 35

    -- Reset position button
    local resetBtn = MedaUI:CreateButton(scrollContent, "Reset Position", 120, 26)
    resetBtn:SetPoint("TOPLEFT", 10, yPos)
    resetBtn:SetScript("OnClick", function()
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:ResetPosition()
        end
    end)
    yPos = yPos - 40

    -- Set content height
    scrollContent:SetHeight(math.abs(yPos) + 20)

    return panel
end

-- Refresh the button list display
function RefreshButtonList()
    if not SettingsPanel.listContent then return end

    -- Clear existing entries
    for _, child in ipairs({ SettingsPanel.listContent:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Get button list
    local buttons = {}
    if MedaButtonBag.ButtonManager then
        buttons = MedaButtonBag.ButtonManager:GetManagedButtonList()
    end

    -- Update count label
    if SettingsPanel.countLabel then
        SettingsPanel.countLabel:SetText(string.format("%d buttons collected", #buttons))
    end

    -- Create entries
    local yPos = 0
    for i, info in ipairs(buttons) do
        local row = CreateFrame("Frame", nil, SettingsPanel.listContent)
        row:SetPoint("TOPLEFT", 0, yPos)
        row:SetSize(PANEL_WIDTH - 95, 20)

        -- Alternate row colors
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        -- Button name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", 5, 0)
        nameText:SetText(info.name or info.key)
        nameText:SetTextColor(unpack(THEME.text))
        nameText:SetWidth(180)
        nameText:SetJustifyH("LEFT")

        -- Source label
        local sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sourceText:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
        sourceText:SetText(info.source == "libdbicon" and "LibDBIcon" or "Native")
        sourceText:SetTextColor(unpack(THEME.textDim))

        yPos = yPos - 20
    end

    SettingsPanel.listContent:SetHeight(math.max(100, math.abs(yPos)))
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Show the settings panel
function SettingsPanel:Show()
    local p = CreatePanel()
    RefreshButtonList()
    p:Show()
end

-- Hide the settings panel
function SettingsPanel:Hide()
    if panel then
        panel:Hide()
    end
end

-- Toggle the settings panel
function SettingsPanel:Toggle()
    if panel and panel:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Check if panel is shown
function SettingsPanel:IsShown()
    return panel and panel:IsShown()
end
