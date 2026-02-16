--[[
    MedaButtonBag - ButtonBag.lua
    The container UI with auto-hide functionality
]]

local addonName, MedaButtonBag = ...

local ButtonBag = {}
MedaButtonBag.ButtonBag = ButtonBag

local DEFAULT_STYLE = {
    bgOpacity = 0.8,
    bgColor = { 0.1, 0.1, 0.1 },
    countdownBarColor = { 0.2, 0.58, 1.0, 1.0 },
    countdownTextColor = { 0.45, 0.75, 1.0, 1.0 },
    countdownFadeAlphas = { 0.02, 0.05, 0.08, 0.05, 0.02 },
}

-- UI frames
ButtonBag.hitbox = nil
ButtonBag.container = nil
ButtonBag.buttonContainer = nil
ButtonBag.moveIndicator = nil

-- Animation groups
ButtonBag.fadeIn = nil
ButtonBag.fadeOut = nil

-- State
ButtonBag.isHovered = false
ButtonBag.fadeOutTimer = nil
ButtonBag.hideCountdownBar = nil
ButtonBag.hideCountdownText = nil
ButtonBag.hideCountdownStart = nil
ButtonBag.hideCountdownDuration = nil
ButtonBag.hideCountdownBg = nil
ButtonBag.hideCountdownBgSegments = nil
ButtonBag.containerEdgeFades = nil

-- Get MedaUI theme
local function GetTheme()
    local MedaUI = LibStub("MedaUI-1.0", true)
    if MedaUI then
        return MedaUI:GetTheme()
    end
    -- Fallback theme
    return {
        background = { 0.1, 0.1, 0.1, 1 },
        border = { 0.3, 0.3, 0.3, 1 },
        gold = { 0.9, 0.7, 0.15, 1 },
    }
end

-- Apply a soft alpha gradient on an edge texture (modern API)
local function SetEdgeGradient(texture, orientation, startAlpha, endAlpha)
    -- Force black tint before applying gradient colors.
    if texture.SetVertexColor then
        texture:SetVertexColor(0, 0, 0, 1)
    end

    local strong = math.max(0, math.min(1, startAlpha or 0))
    local soft = math.max(0, math.min(1, endAlpha or 0))

    -- Modern SetGradient expects orientation string: "HORIZONTAL" or "VERTICAL"
    texture:SetGradient(orientation, CreateColor(0, 0, 0, strong), CreateColor(0, 0, 0, soft))
end

-- Create the main container frames
function ButtonBag:CreateFrames()
    local MedaUI = LibStub("MedaUI-1.0", true)
    local Theme = GetTheme()
    local settings = MedaButtonBag.db.settings

    -- Invisible hitbox for hover detection (always present)
    self.hitbox = CreateFrame("Frame", "MedaButtonBagHitbox", UIParent)
    self.hitbox:SetSize(100, 100)  -- Will be resized
    self.hitbox:SetFrameStrata("MEDIUM")
    self.hitbox:SetFrameLevel(1)
    self.hitbox:EnableMouse(true)
    if self.hitbox.SetPropagateMouseClicks then
        self.hitbox:SetPropagateMouseClicks(true)
    end
    -- Keep hover detection but avoid consuming icon clicks.
    if self.hitbox.SetMouseMotionEnabled then
        self.hitbox:SetMouseMotionEnabled(true)
    end
    if self.hitbox.SetMouseClickEnabled then
        self.hitbox:SetMouseClickEnabled(false)
    end

    -- Main container (visible part)
    self.container = CreateFrame("Frame", "MedaButtonBagContainer", self.hitbox, "BackdropTemplate")
    self.container:SetAllPoints()
    self.container:SetFrameStrata("MEDIUM")
    self.container:SetFrameLevel(5)
    if self.container.SetPropagateMouseClicks then
        self.container:SetPropagateMouseClicks(true)
    end

    -- Apply backdrop
    if MedaUI then
        self.container:SetBackdrop(MedaUI:CreateBackdrop(true))
    else
        self.container:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    -- Button container (holds the actual buttons)
    self.buttonContainer = CreateFrame("Frame", "MedaButtonBagButtonContainer", self.container)
    self.buttonContainer:SetFrameLevel(10)
    if self.buttonContainer.SetPropagateMouseClicks then
        self.buttonContainer:SetPropagateMouseClicks(true)
    end
    self:UpdateButtonContainerInsets()

    -- Subtle edge fade overlays for the main container background
    self.containerEdgeFades = {}

    self.containerEdgeFades.top = self.container:CreateTexture(nil, "BORDER")
    self.containerEdgeFades.top:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.containerEdgeFades.top:SetPoint("TOPLEFT", 1, -1)
    self.containerEdgeFades.top:SetPoint("TOPRIGHT", -1, -1)
    self.containerEdgeFades.top:SetHeight(10)

    self.containerEdgeFades.bottom = self.container:CreateTexture(nil, "BORDER")
    self.containerEdgeFades.bottom:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.containerEdgeFades.bottom:SetPoint("BOTTOMLEFT", 1, 1)
    self.containerEdgeFades.bottom:SetPoint("BOTTOMRIGHT", -1, 1)
    self.containerEdgeFades.bottom:SetHeight(10)

    self.containerEdgeFades.left = self.container:CreateTexture(nil, "BORDER")
    self.containerEdgeFades.left:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.containerEdgeFades.left:SetPoint("TOPLEFT", 1, -1)
    self.containerEdgeFades.left:SetPoint("BOTTOMLEFT", 1, 1)
    self.containerEdgeFades.left:SetWidth(10)

    self.containerEdgeFades.right = self.container:CreateTexture(nil, "BORDER")
    self.containerEdgeFades.right:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.containerEdgeFades.right:SetPoint("TOPRIGHT", -1, -1)
    self.containerEdgeFades.right:SetPoint("BOTTOMRIGHT", -1, 1)
    self.containerEdgeFades.right:SetWidth(10)

    -- Apply container background + edge fade styling now that textures exist.
    self:UpdateBackgroundColor()

    -- Move indicator (shown when unlocked)
    self.moveIndicator = self.container:CreateTexture(nil, "OVERLAY")
    self.moveIndicator:SetAllPoints()
    self.moveIndicator:SetColorTexture(unpack(Theme.gold))
    self.moveIndicator:SetAlpha(0.15)
    self.moveIndicator:Hide()

    -- Move indicator text
    self.moveText = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.moveText:SetPoint("CENTER")
    self.moveText:SetText("Drag to Move")
    self.moveText:SetTextColor(unpack(Theme.gold))
    self.moveText:Hide()

    -- Hide countdown indicator (shown while auto-hide timer is active)
    self.hideCountdownBar = CreateFrame("StatusBar", nil, self.container)
    -- Place indicator outside the bottom edge for stronger visibility
    self.hideCountdownBar:SetPoint("TOPLEFT", self.container, "BOTTOMLEFT", 2, -2)
    self.hideCountdownBar:SetPoint("TOPRIGHT", self.container, "BOTTOMRIGHT", -2, -2)
    self.hideCountdownBar:SetHeight(6)
    -- Flat fill (no default WoW statusbar gradient)
    self.hideCountdownBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    self.hideCountdownBar:SetMinMaxValues(0, 1)
    self.hideCountdownBar:SetValue(1)
    self.hideCountdownBar:SetStatusBarColor(unpack(DEFAULT_STYLE.countdownBarColor))
    self.hideCountdownBar:Hide()

    -- Subtle black backdrop with faded edges behind the countdown bar
    self.hideCountdownBg = CreateFrame("Frame", nil, self.container)
    self.hideCountdownBg:SetPoint("TOPLEFT", self.hideCountdownBar, "TOPLEFT", 0, 1)
    self.hideCountdownBg:SetPoint("TOPRIGHT", self.hideCountdownBar, "TOPRIGHT", 0, 1)
    self.hideCountdownBg:SetHeight(8)
    self.hideCountdownBg:Hide()
    self.hideCountdownBgSegments = {}

    local outerWidth = 6
    local innerWidth = 8

    self.hideCountdownBgSegments[1] = self.hideCountdownBg:CreateTexture(nil, "BACKGROUND")
    self.hideCountdownBgSegments[1]:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.hideCountdownBgSegments[1]:SetPoint("TOPLEFT")
    self.hideCountdownBgSegments[1]:SetPoint("BOTTOMLEFT")
    self.hideCountdownBgSegments[1]:SetWidth(outerWidth)

    self.hideCountdownBgSegments[2] = self.hideCountdownBg:CreateTexture(nil, "BACKGROUND")
    self.hideCountdownBgSegments[2]:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.hideCountdownBgSegments[2]:SetPoint("TOPLEFT", self.hideCountdownBgSegments[1], "TOPRIGHT")
    self.hideCountdownBgSegments[2]:SetPoint("BOTTOMLEFT", self.hideCountdownBgSegments[1], "BOTTOMRIGHT")
    self.hideCountdownBgSegments[2]:SetWidth(innerWidth)

    self.hideCountdownBgSegments[5] = self.hideCountdownBg:CreateTexture(nil, "BACKGROUND")
    self.hideCountdownBgSegments[5]:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.hideCountdownBgSegments[5]:SetPoint("TOPRIGHT")
    self.hideCountdownBgSegments[5]:SetPoint("BOTTOMRIGHT")
    self.hideCountdownBgSegments[5]:SetWidth(outerWidth)

    self.hideCountdownBgSegments[4] = self.hideCountdownBg:CreateTexture(nil, "BACKGROUND")
    self.hideCountdownBgSegments[4]:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.hideCountdownBgSegments[4]:SetPoint("TOPRIGHT", self.hideCountdownBgSegments[5], "TOPLEFT")
    self.hideCountdownBgSegments[4]:SetPoint("BOTTOMRIGHT", self.hideCountdownBgSegments[5], "BOTTOMLEFT")
    self.hideCountdownBgSegments[4]:SetWidth(innerWidth)

    self.hideCountdownBgSegments[3] = self.hideCountdownBg:CreateTexture(nil, "BACKGROUND")
    self.hideCountdownBgSegments[3]:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.hideCountdownBgSegments[3]:SetPoint("TOPLEFT", self.hideCountdownBgSegments[2], "TOPRIGHT")
    self.hideCountdownBgSegments[3]:SetPoint("BOTTOMRIGHT", self.hideCountdownBgSegments[4], "BOTTOMLEFT")

    self.hideCountdownText = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.hideCountdownText:SetPoint("TOP", self.hideCountdownBar, "BOTTOM", 0, -1)
    self.hideCountdownText:SetTextColor(unpack(DEFAULT_STYLE.countdownTextColor))
    self.hideCountdownText:Hide()
    self:ApplyCountdownStyle()

    -- Setup animations
    self:SetupAnimations()

    -- Setup hover scripts
    self:SetupHoverScripts()

    -- Setup dragging
    self:SetupDragging()

    -- Apply saved position
    self:ApplyPosition()

    -- Initial state
    self:UpdateLockState()
end

-- Edge padding around the inner button grid area.
function ButtonBag:GetContainerEdgePadding()
    local settings = MedaButtonBag.db and MedaButtonBag.db.settings
    -- Keep a stable frame around the grid while still scaling with user spacing.
    return math.max(4, (settings and settings.padding or 4) + 2)
end

-- Keep button container insets synced with current layout settings.
function ButtonBag:UpdateButtonContainerInsets()
    if not self.buttonContainer then return end
    local edgePad = self:GetContainerEdgePadding()
    self.buttonContainer:ClearAllPoints()
    self.buttonContainer:SetPoint("TOPLEFT", edgePad, -edgePad)
    self.buttonContainer:SetPoint("BOTTOMRIGHT", -edgePad, edgePad)
end

-- Setup fade animations
function ButtonBag:SetupAnimations()
    -- Fade in animation
    self.fadeIn = self.container:CreateAnimationGroup()
    local fadeInAlpha = self.fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.15)
    fadeInAlpha:SetSmoothing("OUT")

    self.fadeIn:SetScript("OnPlay", function()
        self.container:Show()
    end)

    self.fadeIn:SetScript("OnFinished", function()
        self.container:SetAlpha(1)
    end)

    -- Fade out animation
    self.fadeOut = self.container:CreateAnimationGroup()
    local fadeOutAlpha = self.fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(0.2)
    fadeOutAlpha:SetSmoothing("IN")

    self.fadeOut:SetScript("OnFinished", function()
        self.container:SetAlpha(0)
        self.container:Hide()
    end)
end

-- Setup hover detection scripts
function ButtonBag:SetupHoverScripts()
    local settings = MedaButtonBag.db.settings

    -- Hitbox hover
    self.hitbox:SetScript("OnEnter", function()
        self:OnMouseEnter()
    end)

    self.hitbox:SetScript("OnLeave", function()
        self:OnMouseLeave()
    end)

    -- Container hover (for when mouse moves from hitbox to container)
    self.container:SetScript("OnEnter", function()
        self:OnMouseEnter()
    end)

    self.container:SetScript("OnLeave", function()
        self:OnMouseLeave()
    end)

    -- Button container hover (for movement over child button area)
    self.buttonContainer:SetScript("OnEnter", function()
        self:OnMouseEnter()
    end)

    self.buttonContainer:SetScript("OnLeave", function()
        self:OnMouseLeave()
    end)
end

-- Check if mouse is over any interactive bag surface
function ButtonBag:IsBagMouseOver()
    if not self.hitbox or not self.container then
        return false
    end

    if self.hitbox:IsMouseOver() or self.container:IsMouseOver() then
        return true
    end

    if self.buttonContainer and self.buttonContainer:IsMouseOver() then
        return true
    end

    return false
end

-- Apply countdown indicator style visuals
function ButtonBag:ApplyCountdownStyle()
    if self.hideCountdownBar then
        self.hideCountdownBar:SetStatusBarColor(unpack(DEFAULT_STYLE.countdownBarColor))
    end

    if self.hideCountdownText then
        self.hideCountdownText:SetTextColor(unpack(DEFAULT_STYLE.countdownTextColor))
    end

    if self.hideCountdownBgSegments then
        for i, tex in ipairs(self.hideCountdownBgSegments) do
            tex:SetColorTexture(0, 0, 0, DEFAULT_STYLE.countdownFadeAlphas[i] or 0)
        end
    end
end

-- Stop countdown indicator updates and hide visuals
function ButtonBag:StopHideCountdown()
    self.hideCountdownStart = nil
    self.hideCountdownDuration = nil

    if self.hideCountdownBar then
        self.hideCountdownBar:SetScript("OnUpdate", nil)
        self.hideCountdownBar:Hide()
    end

    if self.hideCountdownText then
        self.hideCountdownText:Hide()
    end

    if self.hideCountdownBg then
        self.hideCountdownBg:Hide()
    end
end

-- Start countdown indicator for pending auto-hide
function ButtonBag:StartHideCountdown(duration)
    if not self.hideCountdownBar or not self.hideCountdownText then
        return
    end

    if not duration or duration <= 0 then
        self:StopHideCountdown()
        return
    end

    self.hideCountdownStart = GetTime()
    self.hideCountdownDuration = duration
    self.hideCountdownBar:SetValue(1)
    if self.hideCountdownBg then
        self.hideCountdownBg:Show()
    end
    self.hideCountdownBar:Show()
    self.hideCountdownText:SetFormattedText("%.1fs", duration)
    self.hideCountdownText:Show()

    self.hideCountdownBar:SetScript("OnUpdate", function(_, _)
        if not self.hideCountdownStart or not self.hideCountdownDuration then
            self:StopHideCountdown()
            return
        end

        local elapsed = GetTime() - self.hideCountdownStart
        local remaining = self.hideCountdownDuration - elapsed
        if remaining <= 0 then
            self.hideCountdownBar:SetValue(0)
            self.hideCountdownText:SetText("0.0s")
            self.hideCountdownBar:SetScript("OnUpdate", nil)
            return
        end

        local progress = remaining / self.hideCountdownDuration
        self.hideCountdownBar:SetValue(progress)
        self.hideCountdownText:SetFormattedText("%.1fs", remaining)
    end)
end

-- Mouse enter handler
function ButtonBag:OnMouseEnter()
    self.isHovered = true

    -- Cancel any pending fade out
    if self.fadeOutTimer then
        self.fadeOutTimer:Cancel()
        self.fadeOutTimer = nil
        MedaButtonBag:Debug("Auto-hide timer canceled on mouse enter")
    end
    self:StopHideCountdown()

    -- Show if locked (auto-hide mode)
    if MedaButtonBag.db.settings.locked then
        self.fadeOut:Stop()
        self.fadeIn:Play()
    end
end

-- Mouse leave handler
function ButtonBag:OnMouseLeave()
    -- Ignore leave transitions while cursor is still inside bag surfaces
    if self:IsBagMouseOver() then
        return
    end

    self.isHovered = false

    -- Start fade out timer if locked
    if MedaButtonBag.db.settings.locked then
        local delay = MedaButtonBag.db.settings.autoHideDelay

        if self.fadeOutTimer then
            self.fadeOutTimer:Cancel()
            MedaButtonBag:Debug("Replaced existing auto-hide timer")
        end

        MedaButtonBag:Debug("Mouse left bag; scheduling auto-hide in", delay, "seconds")
        self:StartHideCountdown(delay)
        self.fadeOutTimer = C_Timer.NewTimer(delay, function()
            -- Double-check mouse is still not over
            if not self:IsBagMouseOver() then
                MedaButtonBag:Debug("Auto-hide timer fired; fading out bag")
                self:StopHideCountdown()
                self.fadeIn:Stop()
                self.fadeOut:Play()
            else
                MedaButtonBag:Debug("Auto-hide timer fired but mouse returned; keeping bag visible")
                self:StopHideCountdown()
            end
            self.fadeOutTimer = nil
        end)
    end
end

-- Setup dragging functionality
function ButtonBag:SetupDragging()
    self.hitbox:SetMovable(true)
    self.hitbox:RegisterForDrag("LeftButton")

    self.hitbox:SetScript("OnDragStart", function(frame)
        if not MedaButtonBag.db.settings.locked and IsAltKeyDown() then
            frame:StartMoving()
        end
    end)

    self.hitbox:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    -- Also allow dragging from container when unlocked (Alt+Left drag only)
    self.container:SetScript("OnMouseDown", function(frame, button)
        if button == "LeftButton" and not MedaButtonBag.db.settings.locked and IsAltKeyDown() then
            self.hitbox:StartMoving()
            self.isAltDragging = true
        end
    end)

    self.container:SetScript("OnMouseUp", function(frame, button)
        if button == "LeftButton" and self.isAltDragging then
            self.hitbox:StopMovingOrSizing()
            self:SavePosition()
            self.isAltDragging = false
        end
    end)
end

-- Save current position to database
function ButtonBag:SavePosition()
    local point, relativeTo, relativePoint, x, y = self.hitbox:GetPoint()
    MedaButtonBag.db.position = {
        point = point,
        relativeTo = relativeTo == Minimap and "Minimap" or (relativeTo and relativeTo:GetName() or nil),
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

-- Apply saved position from database
function ButtonBag:ApplyPosition()
    local pos = MedaButtonBag.db.position
    self.hitbox:ClearAllPoints()

    -- Handle relativeTo - default to Minimap if nil or "Minimap"
    local relativeTo = UIParent
    if pos.relativeTo == "Minimap" or pos.relativeTo == nil then
        relativeTo = Minimap
    elseif pos.relativeTo and _G[pos.relativeTo] then
        relativeTo = _G[pos.relativeTo]
    end

    self.hitbox:SetPoint(
        pos.point or "TOPRIGHT",
        relativeTo,
        pos.relativePoint or "BOTTOMRIGHT",
        pos.x or 0,
        pos.y or -10
    )
end

-- Reset position to default
function ButtonBag:ResetPosition()
    MedaButtonBag.db.position = {
        point = "TOPRIGHT",
        relativeTo = "Minimap",
        relativePoint = "BOTTOMRIGHT",
        x = 0,
        y = -10,
    }
    self:ApplyPosition()
end

-- Reset style settings and reapply visuals
function ButtonBag:ResetStyle()
    local settings = MedaButtonBag.db.settings
    settings.bgOpacity = DEFAULT_STYLE.bgOpacity
    settings.bgColor = { unpack(DEFAULT_STYLE.bgColor) }
    self:UpdateBackgroundColor()
    self:ApplyCountdownStyle()
end

-- Update lock state (toggle between auto-hide and always visible)
function ButtonBag:UpdateLockState()
    local locked = MedaButtonBag.db.settings.locked

    -- Guard: ensure ButtonBag is fully initialized
    if not self.container or not self.hitbox then return end

    -- Always ensure hitbox is shown (it's invisible but needed for hover detection)
    self.hitbox:Show()

    if locked then
        -- Auto-hide mode: start hidden
        if self.moveIndicator then self.moveIndicator:Hide() end
        if self.moveText then self.moveText:Hide() end

        if not self.isHovered then
            self.container:SetAlpha(0)
            self.container:Hide()
        end
    else
        -- Unlocked mode: always visible with move indicator
        if self.fadeIn then self.fadeIn:Stop() end
        if self.fadeOut then self.fadeOut:Stop() end

        if self.fadeOutTimer then
            self.fadeOutTimer:Cancel()
            self.fadeOutTimer = nil
        end
        self:StopHideCountdown()

        self.container:SetAlpha(1)
        self.container:Show()
        if self.moveIndicator then self.moveIndicator:Show() end
        if self.moveText then self.moveText:Show() end
    end
end

-- Update container size (called by ButtonManager)
function ButtonBag:UpdateContainerSize(width, height)
    -- Guard: ensure ButtonBag is initialized
    if not self.hitbox then return end

    -- Ensure insets follow settings changes (size/spacing updates).
    self:UpdateButtonContainerInsets()
    local edgePad = self:GetContainerEdgePadding()

    -- Include consistent inner edge padding around the button grid.
    width = width + (edgePad * 2)
    height = height + (edgePad * 2)

    -- Minimum size
    width = math.max(width, 40)
    height = math.max(height, 40)

    self.hitbox:SetSize(width, height)
end

-- Update background color from settings
function ButtonBag:UpdateBackgroundColor()
    if not self.container then return end

    local settings = MedaButtonBag.db.settings
    local r, g, b = unpack(settings.bgColor)
    local a = settings.bgOpacity

    self.container:SetBackdropColor(r, g, b, a)

    -- Border color from theme
    local Theme = GetTheme()
    self.container:SetBackdropBorderColor(unpack(Theme.border))

    -- Keep edge fades subtle; opacity scales lightly with background opacity.
    local edgeAlphaStrong = math.min(0.1, 0.03 + (a * 0.07))
    local edgeAlphaSoft = edgeAlphaStrong * 0.15
    if self.containerEdgeFades then
        SetEdgeGradient(self.containerEdgeFades.top, "VERTICAL", edgeAlphaStrong, edgeAlphaSoft)
        SetEdgeGradient(self.containerEdgeFades.bottom, "VERTICAL", edgeAlphaSoft, edgeAlphaStrong)
        SetEdgeGradient(self.containerEdgeFades.left, "HORIZONTAL", edgeAlphaStrong, edgeAlphaSoft)
        SetEdgeGradient(self.containerEdgeFades.right, "HORIZONTAL", edgeAlphaSoft, edgeAlphaStrong)
    end
end

-- Get the button container frame (for reparenting buttons)
function ButtonBag:GetButtonContainer()
    return self.buttonContainer  -- May be nil if not initialized
end

-- Check if ButtonBag is initialized
function ButtonBag:IsInitialized()
    return self.hitbox ~= nil and self.container ~= nil
end

-- Show the bag
function ButtonBag:Show()
    if not self.hitbox then return end
    self.hitbox:Show()
    if not MedaButtonBag.db.settings.locked or self.isHovered then
        self.container:Show()
        self.container:SetAlpha(1)
    end
end

-- Hide the bag
function ButtonBag:Hide()
    if not self.hitbox then return end
    self.hitbox:Hide()
end

-- Toggle visibility
function ButtonBag:Toggle()
    if not self.hitbox then return end
    if self.hitbox:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Initialize the ButtonBag UI
function ButtonBag:Initialize()
    MedaButtonBag:Debug("ButtonBag initializing...")

    self:CreateFrames()

    -- Initial size (will be updated by ButtonManager)
    local settings = MedaButtonBag.db.settings
    local size = settings.buttonSize + (settings.padding * 2)
    self:UpdateContainerSize(size, size)

    self:Show()
end
