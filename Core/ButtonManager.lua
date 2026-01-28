--[[
    MedaButtonBag - ButtonManager.lua
    Manages button reparenting, layout, and state
]]

local addonName, MedaButtonBag = ...

local ButtonManager = {}
MedaButtonBag.ButtonManager = ButtonManager

-- Managed buttons (subset of collected that are actively in the bag)
ButtonManager.managedButtons = {}

-- Layout order (for consistent ordering)
ButtonManager.buttonOrder = {}

-- Check if collection is enabled
function ButtonManager:IsEnabled()
    return MedaButtonBag.db and MedaButtonBag.db.settings.enabled
end

-- Called when a new button is discovered
function ButtonManager:OnButtonDiscovered(key, info)
    if not self:IsEnabled() then return end

    -- Add to managed list
    self.managedButtons[key] = info

    -- Add to order list
    table.insert(self.buttonOrder, key)

    -- Sort by name for consistent ordering
    table.sort(self.buttonOrder, function(a, b)
        local infoA = self.managedButtons[a]
        local infoB = self.managedButtons[b]
        return (infoA.name or "") < (infoB.name or "")
    end)

    -- Collect the button (reparent to bag)
    self:CollectButton(key)

    -- Refresh layout
    self:RefreshLayout()
end

-- Called when a button is removed
function ButtonManager:OnButtonRemoved(key)
    -- Restore button to original location
    self:RestoreButton(key)

    -- Remove from managed list
    self.managedButtons[key] = nil

    -- Remove from order list
    for i, k in ipairs(self.buttonOrder) do
        if k == key then
            table.remove(self.buttonOrder, i)
            break
        end
    end

    -- Refresh layout
    self:RefreshLayout()
end

-- Collect a button (reparent to bag container)
function ButtonManager:CollectButton(key)
    local info = self.managedButtons[key]
    if not info or info.collected then return end

    local button = info.button
    if not button then return end

    -- Get the bag container
    local container = MedaButtonBag.ButtonBag and MedaButtonBag.ButtonBag:GetButtonContainer()
    if not container then
        MedaButtonBag:Debug("No container available for button:", key)
        return
    end

    -- Store original state for restoration
    info.originalParent = button:GetParent()
    info.originalPoint = { button:GetPoint() }
    info.originalSize = { button:GetSize() }
    info.originalScale = button:GetScale()
    info.originalFrameStrata = button:GetFrameStrata()
    info.originalFrameLevel = button:GetFrameLevel()

    -- Reparent to bag container
    button:SetParent(container)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(10)

    -- Normalize size
    local size = MedaButtonBag.db.settings.buttonSize
    button:SetSize(size, size)
    button:SetScale(1)

    -- Clear existing points (will be set by layout)
    button:ClearAllPoints()

    info.collected = true
    MedaButtonBag:Debug("Collected button:", key)
end

-- Restore a button to its original location
function ButtonManager:RestoreButton(key)
    local info = self.managedButtons[key]
    if not info or not info.collected then return end

    local button = info.button
    if not button then return end

    -- Restore parent
    if info.originalParent then
        button:SetParent(info.originalParent)
    end

    -- Restore position
    button:ClearAllPoints()
    if info.originalPoint and #info.originalPoint > 0 then
        button:SetPoint(unpack(info.originalPoint))
    end

    -- Restore size
    if info.originalSize then
        button:SetSize(unpack(info.originalSize))
    end

    -- Restore scale
    if info.originalScale then
        button:SetScale(info.originalScale)
    end

    -- Restore strata/level
    if info.originalFrameStrata then
        button:SetFrameStrata(info.originalFrameStrata)
    end
    if info.originalFrameLevel then
        button:SetFrameLevel(info.originalFrameLevel)
    end

    info.collected = false
    MedaButtonBag:Debug("Restored button:", key)
end

-- Calculate layout dimensions
function ButtonManager:CalculateLayout()
    local settings = MedaButtonBag.db.settings
    local buttonCount = #self.buttonOrder
    local columns = settings.columns
    local maxRows = settings.rows
    local buttonSize = settings.buttonSize
    local padding = settings.padding

    if buttonCount == 0 then
        return 0, 0, buttonSize + padding * 2, buttonSize + padding * 2
    end

    -- Calculate rows needed
    local rows = math.ceil(buttonCount / columns)
    if maxRows > 0 and rows > maxRows then
        rows = maxRows
    end

    -- Actual columns used (might be less than max if few buttons)
    local actualColumns = math.min(buttonCount, columns)

    -- Calculate container size
    local width = (actualColumns * buttonSize) + ((actualColumns + 1) * padding)
    local height = (rows * buttonSize) + ((rows + 1) * padding)

    return rows, actualColumns, width, height
end

-- Refresh the layout of all managed buttons
function ButtonManager:RefreshLayout()
    if not self:IsEnabled() then return end

    local settings = MedaButtonBag.db.settings
    local buttonSize = settings.buttonSize
    local padding = settings.padding
    local columns = settings.columns

    -- Position each button in grid
    for i, key in ipairs(self.buttonOrder) do
        local info = self.managedButtons[key]
        if info and info.collected and info.button then
            local button = info.button

            -- Calculate grid position (0-indexed)
            local index = i - 1
            local col = index % columns
            local row = math.floor(index / columns)

            -- Check if within row limit
            local maxRows = settings.rows
            if maxRows > 0 and row >= maxRows then
                -- Hide buttons that exceed row limit
                button:Hide()
            else
                -- Calculate pixel position
                local x = padding + (col * (buttonSize + padding))
                local y = -(padding + (row * (buttonSize + padding)))

                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", x, y)
                button:SetSize(buttonSize, buttonSize)
                button:Show()
            end
        end
    end

    -- Update container size
    local _, _, width, height = self:CalculateLayout()
    if MedaButtonBag.ButtonBag then
        MedaButtonBag.ButtonBag:UpdateContainerSize(width, height)
    end

    MedaButtonBag:Debug("Layout refreshed:", #self.buttonOrder, "buttons")
end

-- Update button sizes (called when settings change)
function ButtonManager:UpdateButtonSizes()
    local buttonSize = MedaButtonBag.db.settings.buttonSize

    for _, key in ipairs(self.buttonOrder) do
        local info = self.managedButtons[key]
        if info and info.collected and info.button then
            info.button:SetSize(buttonSize, buttonSize)
        end
    end

    self:RefreshLayout()
end

-- Restore all buttons to original locations
function ButtonManager:RestoreAllButtons()
    for key in pairs(self.managedButtons) do
        self:RestoreButton(key)
    end
end

-- Collect all discovered buttons
function ButtonManager:CollectAllButtons()
    if not self:IsEnabled() then return end

    local buttons = MedaButtonBag.ButtonCollector:GetButtons()
    for key, info in pairs(buttons) do
        if not self.managedButtons[key] then
            self.managedButtons[key] = info
            table.insert(self.buttonOrder, key)
        end
        self:CollectButton(key)
    end

    -- Sort order
    table.sort(self.buttonOrder, function(a, b)
        local infoA = self.managedButtons[a]
        local infoB = self.managedButtons[b]
        return (infoA.name or "") < (infoB.name or "")
    end)

    self:RefreshLayout()
end

-- Get managed button count
function ButtonManager:GetManagedCount()
    return #self.buttonOrder
end

-- Get list of managed buttons (for settings UI)
function ButtonManager:GetManagedButtonList()
    local list = {}
    for _, key in ipairs(self.buttonOrder) do
        local info = self.managedButtons[key]
        if info then
            table.insert(list, {
                key = key,
                name = info.name,
                source = info.source,
                collected = info.collected,
            })
        end
    end
    return list
end

-- Enable/disable collection
function ButtonManager:SetEnabled(enabled)
    MedaButtonBag.db.settings.enabled = enabled

    if enabled then
        self:CollectAllButtons()
    else
        self:RestoreAllButtons()
    end
end

-- Initialize the manager
function ButtonManager:Initialize()
    MedaButtonBag:Debug("ButtonManager initializing...")

    -- Wait for ButtonBag to be ready before collecting
    C_Timer.After(0.1, function()
        if self:IsEnabled() then
            self:CollectAllButtons()
        end
    end)
end
