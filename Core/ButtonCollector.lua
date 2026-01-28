--[[
    MedaButtonBag - ButtonCollector.lua
    Discovers minimap buttons from LibDBIcon and native sources
]]

local addonName, MedaButtonBag = ...

local ButtonCollector = {}
MedaButtonBag.ButtonCollector = ButtonCollector

-- Collected buttons storage
-- { [uniqueKey] = { button = frame, source = "libdbicon"|"native", name = "ButtonName", ... } }
ButtonCollector.buttons = {}

-- Blacklist of frame names/patterns that should never be collected
local FRAME_BLACKLIST = {
    -- Minimap UI elements
    ["MinimapZoomIn"] = true,
    ["MinimapZoomOut"] = true,
    ["MinimapBackdrop"] = true,
    ["MinimapBorder"] = true,
    ["MinimapBorderTop"] = true,
    ["MinimapCompassTexture"] = true,
    ["MinimapCluster"] = true,
    ["Minimap"] = true,

    -- Blizzard tracking/mail/etc that we might want to keep in place
    -- (these can be removed from blacklist if user wants to collect them)
    -- ["MiniMapTracking"] = true,
    -- ["MiniMapMailFrame"] = true,
    -- ["GameTimeFrame"] = true,
}

-- Pattern blacklist (for matching partial names)
local PATTERN_BLACKLIST = {
    "^MinimapCluster",
    "^TimeManagerClockButton",  -- Calendar button
}

-- Check if a frame name is blacklisted
local function IsBlacklisted(frameName)
    if not frameName then return false end

    -- Direct blacklist check
    if FRAME_BLACKLIST[frameName] then
        return true
    end

    -- Pattern matching
    for _, pattern in ipairs(PATTERN_BLACKLIST) do
        if frameName:match(pattern) then
            return true
        end
    end

    -- User blacklist
    if MedaButtonBag.db and MedaButtonBag.db.settings.blacklist[frameName] then
        return true
    end

    return false
end

-- Check if a frame looks like a minimap button
local function IsMinimapButton(frame)
    if not frame then return false end
    if not frame:IsShown() then return false end

    local frameName = frame:GetName()
    if IsBlacklisted(frameName) then return false end

    local frameType = frame:GetObjectType()

    -- Must be a Button or Frame
    if frameType ~= "Button" and frameType ~= "Frame" then
        return false
    end

    -- Size check - minimap buttons are typically small
    local width, height = frame:GetSize()
    if width > 50 or height > 50 or width < 10 or height < 10 then
        return false
    end

    -- Must have some kind of icon/visual
    local hasIcon = false
    if frame.icon or frame.Icon then
        hasIcon = true
    elseif frameType == "Button" and frame:GetNormalTexture() then
        hasIcon = true
    else
        -- Check for child textures that look like icons
        for _, child in ipairs({ frame:GetRegions() }) do
            if child:GetObjectType() == "Texture" then
                local tex = child:GetTexture()
                if tex and type(tex) == "number" or (type(tex) == "string" and tex:find("Interface")) then
                    hasIcon = true
                    break
                end
            end
        end
    end

    if not hasIcon then return false end

    -- Must respond to clicks
    local hasClick = frame:IsMouseEnabled()
    if not hasClick then return false end

    return true
end

-- Generate a unique key for a button
local function GetButtonKey(button, source, name)
    if source == "libdbicon" and name then
        return "ldb:" .. name
    end

    local frameName = button:GetName()
    if frameName then
        return "native:" .. frameName
    end

    -- Fallback: use memory address
    return "frame:" .. tostring(button)
end

-- Register a discovered button
function ButtonCollector:RegisterButton(button, source, name)
    local key = GetButtonKey(button, source, name)

    -- Skip if already registered
    if self.buttons[key] then
        return false
    end

    -- Skip if blacklisted
    local frameName = name or button:GetName()
    if IsBlacklisted(frameName) then
        return false
    end

    -- Store button info
    self.buttons[key] = {
        button = button,
        source = source,
        name = frameName or key,
        key = key,
        originalParent = button:GetParent(),
        originalPoint = { button:GetPoint() },
        originalSize = { button:GetSize() },
        collected = false,  -- Will be set true when moved to bag
    }

    MedaButtonBag:Debug("Registered button:", key, "source:", source)

    -- Notify manager of new button
    if MedaButtonBag.ButtonManager then
        MedaButtonBag.ButtonManager:OnButtonDiscovered(key, self.buttons[key])
    end

    return true
end

-- Unregister a button (e.g., if it was destroyed)
function ButtonCollector:UnregisterButton(key)
    local info = self.buttons[key]
    if not info then return end

    -- Notify manager before removal
    if MedaButtonBag.ButtonManager then
        MedaButtonBag.ButtonManager:OnButtonRemoved(key)
    end

    self.buttons[key] = nil
    MedaButtonBag:Debug("Unregistered button:", key)
end

-- Collect buttons from LibDBIcon
function ButtonCollector:CollectLibDBIcon()
    local LibDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LibDBIcon then
        MedaButtonBag:Debug("LibDBIcon not available")
        return
    end

    -- Iterate all registered buttons
    for name, button in pairs(LibDBIcon.objects) do
        -- Skip our own button
        if name ~= "MedaButtonBag" then
            self:RegisterButton(button, "libdbicon", name)
        end
    end

    -- Register callback for buttons created after initialization
    if not self.libDBIconCallbackRegistered then
        LibDBIcon.RegisterCallback(self, "LibDBIcon_IconCreated", function(_, button, name)
            if name ~= "MedaButtonBag" then
                self:RegisterButton(button, "libdbicon", name)
            end
        end)
        self.libDBIconCallbackRegistered = true
    end

    MedaButtonBag:Debug("LibDBIcon scan complete")
end

-- Collect native minimap buttons (not using LibDBIcon)
function ButtonCollector:CollectNativeButtons()
    -- Scan Minimap children
    local minimap = Minimap
    if not minimap then return end

    for _, child in ipairs({ minimap:GetChildren() }) do
        if IsMinimapButton(child) then
            -- Check if this is NOT a LibDBIcon button
            local isLDBButton = false
            local frameName = child:GetName()

            if frameName and frameName:match("^LibDBIcon10_") then
                isLDBButton = true
            end

            if not isLDBButton then
                self:RegisterButton(child, "native", frameName)
            end
        end
    end

    -- Also scan MinimapCluster children (for some native buttons)
    local cluster = MinimapCluster
    if cluster then
        for _, child in ipairs({ cluster:GetChildren() }) do
            if IsMinimapButton(child) then
                local frameName = child:GetName()
                local isLDBButton = frameName and frameName:match("^LibDBIcon10_")

                if not isLDBButton then
                    self:RegisterButton(child, "native", frameName)
                end
            end
        end
    end

    -- Scan MinimapBackdrop children
    local backdrop = MinimapBackdrop
    if backdrop then
        for _, child in ipairs({ backdrop:GetChildren() }) do
            if IsMinimapButton(child) then
                local frameName = child:GetName()
                local isLDBButton = frameName and frameName:match("^LibDBIcon10_")

                if not isLDBButton then
                    self:RegisterButton(child, "native", frameName)
                end
            end
        end
    end

    MedaButtonBag:Debug("Native button scan complete")
end

-- Get all collected buttons
function ButtonCollector:GetButtons()
    return self.buttons
end

-- Get button by key
function ButtonCollector:GetButton(key)
    return self.buttons[key]
end

-- Get button count
function ButtonCollector:GetButtonCount()
    local count = 0
    for _ in pairs(self.buttons) do
        count = count + 1
    end
    return count
end

-- Force rescan all sources
function ButtonCollector:Rescan()
    MedaButtonBag:Debug("Starting button rescan...")

    -- Rescan LibDBIcon
    self:CollectLibDBIcon()

    -- Rescan native buttons
    self:CollectNativeButtons()

    -- Notify manager to refresh layout
    if MedaButtonBag.ButtonManager then
        MedaButtonBag.ButtonManager:RefreshLayout()
    end
end

-- Initialize the collector
function ButtonCollector:Initialize()
    MedaButtonBag:Debug("ButtonCollector initializing...")

    -- Initial collection
    self:CollectLibDBIcon()

    -- Delayed native button scan (let other addons finish loading)
    C_Timer.After(1, function()
        self:CollectNativeButtons()

        -- Another delayed scan to catch really late loaders
        C_Timer.After(3, function()
            self:CollectNativeButtons()
        end)
    end)
end
