--[[
    MedaButtonBag - ButtonBag.lua
    The container UI with auto-hide functionality
]]

local addonName, MedaButtonBag = ...

local ButtonBag = {}
MedaButtonBag.ButtonBag = ButtonBag

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

    -- Main container (visible part)
    self.container = CreateFrame("Frame", "MedaButtonBagContainer", self.hitbox, "BackdropTemplate")
    self.container:SetAllPoints()
    self.container:SetFrameStrata("MEDIUM")
    self.container:SetFrameLevel(5)

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
    self:UpdateBackgroundColor()

    -- Button container (holds the actual buttons)
    self.buttonContainer = CreateFrame("Frame", "MedaButtonBagButtonContainer", self.container)
    self.buttonContainer:SetAllPoints()
    self.buttonContainer:SetFrameLevel(10)

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
end

-- Mouse enter handler
function ButtonBag:OnMouseEnter()
    self.isHovered = true

    -- Cancel any pending fade out
    if self.fadeOutTimer then
        self.fadeOutTimer:Cancel()
        self.fadeOutTimer = nil
    end

    -- Show if locked (auto-hide mode)
    if MedaButtonBag.db.settings.locked then
        self.fadeOut:Stop()
        self.fadeIn:Play()
    end
end

-- Mouse leave handler
function ButtonBag:OnMouseLeave()
    -- Check if mouse is still over hitbox or container
    if self.hitbox:IsMouseOver() or self.container:IsMouseOver() then
        return
    end

    self.isHovered = false

    -- Start fade out timer if locked
    if MedaButtonBag.db.settings.locked then
        local delay = MedaButtonBag.db.settings.autoHideDelay

        if self.fadeOutTimer then
            self.fadeOutTimer:Cancel()
        end

        self.fadeOutTimer = C_Timer.NewTimer(delay, function()
            -- Double-check mouse is still not over
            if not self.hitbox:IsMouseOver() and not self.container:IsMouseOver() then
                self.fadeIn:Stop()
                self.fadeOut:Play()
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
        if not MedaButtonBag.db.settings.locked then
            frame:StartMoving()
        end
    end)

    self.hitbox:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    -- Also allow dragging from container when unlocked
    self.container:SetScript("OnMouseDown", function(frame, button)
        if button == "LeftButton" and not MedaButtonBag.db.settings.locked then
            self.hitbox:StartMoving()
        end
    end)

    self.container:SetScript("OnMouseUp", function(frame, button)
        if button == "LeftButton" then
            self.hitbox:StopMovingOrSizing()
            self:SavePosition()
        end
    end)
end

-- Save current position to database
function ButtonBag:SavePosition()
    local point, relativeTo, relativePoint, x, y = self.hitbox:GetPoint()
    MedaButtonBag.db.position = {
        point = point,
        relativeTo = relativeTo and relativeTo:GetName() or nil,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

-- Apply saved position from database
function ButtonBag:ApplyPosition()
    local pos = MedaButtonBag.db.position
    self.hitbox:ClearAllPoints()

    local relativeTo = pos.relativeTo and _G[pos.relativeTo] or UIParent
    self.hitbox:SetPoint(
        pos.point or "TOPRIGHT",
        relativeTo,
        pos.relativePoint or "TOPRIGHT",
        pos.x or -20,
        pos.y or -200
    )
end

-- Reset position to default
function ButtonBag:ResetPosition()
    MedaButtonBag.db.position = {
        point = "TOPRIGHT",
        relativeTo = nil,
        relativePoint = "TOPRIGHT",
        x = -20,
        y = -200,
    }
    self:ApplyPosition()
end

-- Update lock state (toggle between auto-hide and always visible)
function ButtonBag:UpdateLockState()
    local locked = MedaButtonBag.db.settings.locked

    if locked then
        -- Auto-hide mode: start hidden
        self.moveIndicator:Hide()
        self.moveText:Hide()

        if not self.isHovered then
            self.container:SetAlpha(0)
            self.container:Hide()
        end
    else
        -- Unlocked mode: always visible with move indicator
        self.fadeIn:Stop()
        self.fadeOut:Stop()

        if self.fadeOutTimer then
            self.fadeOutTimer:Cancel()
            self.fadeOutTimer = nil
        end

        self.container:SetAlpha(1)
        self.container:Show()
        self.moveIndicator:Show()
        self.moveText:Show()
    end
end

-- Update container size (called by ButtonManager)
function ButtonBag:UpdateContainerSize(width, height)
    -- Minimum size
    width = math.max(width, 40)
    height = math.max(height, 40)

    self.hitbox:SetSize(width, height)
end

-- Update background color from settings
function ButtonBag:UpdateBackgroundColor()
    local settings = MedaButtonBag.db.settings
    local r, g, b = unpack(settings.bgColor)
    local a = settings.bgOpacity

    self.container:SetBackdropColor(r, g, b, a)

    -- Border color from theme
    local Theme = GetTheme()
    self.container:SetBackdropBorderColor(unpack(Theme.border))
end

-- Get the button container frame (for reparenting buttons)
function ButtonBag:GetButtonContainer()
    return self.buttonContainer
end

-- Show the bag
function ButtonBag:Show()
    self.hitbox:Show()
    if not MedaButtonBag.db.settings.locked or self.isHovered then
        self.container:Show()
        self.container:SetAlpha(1)
    end
end

-- Hide the bag
function ButtonBag:Hide()
    self.hitbox:Hide()
end

-- Toggle visibility
function ButtonBag:Toggle()
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
