--[[
    MedaButtonBag - Core.lua
    Initialization, events, and slash commands
]]

-- Create addon namespace
local addonName, MedaButtonBag = ...
_G.MedaButtonBag = MedaButtonBag

-- Addon version
MedaButtonBag.version = "1.0.0"

-- Default database schema
local DEFAULT_DB = {
    version = 1,

    -- Minimap button position (LibDBIcon format)
    minimap = {
        hide = false,
    },

    -- Container position
    position = {
        point = "TOPRIGHT",
        relativeTo = "Minimap",  -- Anchor to Minimap
        relativePoint = "BOTTOMRIGHT",
        x = 0,
        y = -10,  -- Just below the minimap
    },

    -- Settings
    settings = {
        enabled = true,
        locked = false,          -- Start unlocked so users can see and position it

        -- Layout
        columns = 4,             -- Icons per row
        rows = 0,                -- Max rows (0 = unlimited, grows vertically)
        buttonSize = 28,         -- Button size in pixels
        padding = 4,             -- Spacing between buttons

        -- Appearance
        bgOpacity = 0.8,         -- Background opacity (0-1)
        bgColor = { 0.1, 0.1, 0.1 },  -- Background RGB color

        -- Behavior
        autoHideDelay = 0.3,     -- Fade out delay in seconds

        -- Button blacklist (buttons to not collect)
        blacklist = {},          -- { ["ButtonName"] = true }
    },
}

-- Main event frame
local eventFrame = CreateFrame("Frame")
MedaButtonBag.eventFrame = eventFrame

-- Initialize database
local function InitializeDB()
    if not MedaButtonBagDB then
        MedaButtonBagDB = CopyTable(DEFAULT_DB)
    else
        -- Migrate/update schema if needed
        if not MedaButtonBagDB.version then
            MedaButtonBagDB.version = 1
        end

        -- Ensure all default keys exist
        for key, value in pairs(DEFAULT_DB) do
            if MedaButtonBagDB[key] == nil then
                MedaButtonBagDB[key] = CopyTable(value)
            elseif type(value) == "table" and type(MedaButtonBagDB[key]) == "table" then
                -- Deep merge for nested tables
                for subKey, subValue in pairs(value) do
                    if MedaButtonBagDB[key][subKey] == nil then
                        MedaButtonBagDB[key][subKey] = type(subValue) == "table" and CopyTable(subValue) or subValue
                    end
                end
            end
        end
    end

    MedaButtonBag.db = MedaButtonBagDB
end

-- Slash command handler
local function SlashCommandHandler(msg)
    local cmd = msg:lower():trim()

    if cmd == "" or cmd == "options" or cmd == "settings" then
        -- Open settings panel (default action)
        if MedaButtonBag.SettingsPanel then
            MedaButtonBag.SettingsPanel:Toggle()
        else
            print("|cFFE5C46FMedaButtonBag:|r Settings panel not yet loaded.")
        end
    elseif cmd == "lock" then
        -- Lock the container (enable auto-hide)
        MedaButtonBag.db.settings.locked = true
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:UpdateLockState()
        end
        print("|cFFE5C46FMedaButtonBag:|r Container locked (auto-hide enabled).")
    elseif cmd == "unlock" then
        -- Unlock the container (always visible, movable)
        MedaButtonBag.db.settings.locked = false
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:UpdateLockState()
        end
        print("|cFFE5C46FMedaButtonBag:|r Container unlocked (always visible, drag to move).")
    elseif cmd == "reset" then
        -- Reset position to default
        MedaButtonBag.db.position = CopyTable(DEFAULT_DB.position)
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:ResetPosition()
        end
        print("|cFFE5C46FMedaButtonBag:|r Position reset to default.")
    elseif cmd == "rescan" then
        -- Force rescan for buttons
        if MedaButtonBag.ButtonCollector then
            MedaButtonBag.ButtonCollector:Rescan()
        end
        print("|cFFE5C46FMedaButtonBag:|r Rescanning for minimap buttons...")
    elseif cmd == "debug" then
        -- Toggle debug mode
        MedaButtonBag.debug = not MedaButtonBag.debug
        print("|cFFE5C46FMedaButtonBag:|r Debug mode " .. (MedaButtonBag.debug and "enabled" or "disabled"))
    else
        -- Show help
        print("|cFFE5C46FMedaButtonBag Commands:|r")
        print("  /mbb - Open settings panel")
        print("  /mbb lock - Lock container (auto-hide enabled)")
        print("  /mbb unlock - Unlock container (always visible, movable)")
        print("  /mbb reset - Reset position to default")
        print("  /mbb rescan - Force rescan for buttons")
    end
end

-- Debug print helper
function MedaButtonBag:Debug(...)
    if self.debug then
        print("|cFFE5C46FMedaButtonBag Debug:|r", ...)
    end
end

-- Event handlers
local function OnAddonLoaded(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end

    -- Initialize database
    InitializeDB()

    -- Register slash commands
    SLASH_MEDABUTTONBAG1 = "/mbb"
    SLASH_MEDABUTTONBAG2 = "/mbutton"
    SlashCmdList["MEDABUTTONBAG"] = SlashCommandHandler

    print("|cFFE5C46FMedaButtonBag|r v" .. MedaButtonBag.version .. " loaded. Type /mbb for commands.")

    -- Unregister this event
    eventFrame:UnregisterEvent("ADDON_LOADED")
end

local function OnPlayerLogin(self, event)
    -- Initialize modules after a short delay to let other addons load their buttons
    C_Timer.After(1, function()
        -- Initialize button collector
        if MedaButtonBag.ButtonCollector then
            MedaButtonBag.ButtonCollector:Initialize()
        end

        -- Initialize button manager
        if MedaButtonBag.ButtonManager then
            MedaButtonBag.ButtonManager:Initialize()
        end

        -- Initialize button bag UI
        if MedaButtonBag.ButtonBag then
            MedaButtonBag.ButtonBag:Initialize()
        end

        -- Initialize minimap button
        MedaButtonBag:InitializeMinimapButton()
    end)
end

local function OnPlayerEnteringWorld(self, event, isInitialLogin, isReloadingUI)
    -- Delayed rescan after zoning/reload to catch any late-loading buttons
    if not isInitialLogin then
        C_Timer.After(2, function()
            if MedaButtonBag.ButtonCollector then
                MedaButtonBag.ButtonCollector:Rescan()
            end
        end)
    end
end

-- Event dispatcher
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(self, event, ...)
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin(self, event)
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld(self, event, ...)
    end
end)

-- Register events
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- ============================================================================
-- Minimap Button (our own button, using MedaUI)
-- ============================================================================

function MedaButtonBag:InitializeMinimapButton()
    local MedaUI = LibStub("MedaUI-1.0", true)
    if not MedaUI then return end

    self.minimapButton = MedaUI:CreateMinimapButton(
        "MedaButtonBag",
        "Interface\\Icons\\INV_Misc_Bag_10_Blue",
        function() -- Left click
            if self.SettingsPanel then
                self.SettingsPanel:Toggle()
            end
        end,
        function() -- Right click
            -- Toggle lock state
            self.db.settings.locked = not self.db.settings.locked
            if self.ButtonBag then
                self.ButtonBag:UpdateLockState()
            end
            local state = self.db.settings.locked and "locked" or "unlocked"
            print("|cFFE5C46FMedaButtonBag:|r Container " .. state .. ".")
        end,
        self.db.minimap
    )
end

-- Show/hide our own minimap button
function MedaButtonBag:SetMinimapButtonShown(show)
    if not self.minimapButton then return end

    if show then
        self.minimapButton:ShowButton()
        self.db.minimap.hide = false
    else
        self.minimapButton:HideButton()
        self.db.minimap.hide = true
    end
end
