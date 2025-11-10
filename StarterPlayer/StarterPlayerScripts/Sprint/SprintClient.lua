-- SprintClient.lua
-- Client-side controller & input handling
-- Logic & input, separate from GUI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Sprint.Config)
local SharedTypes = require(ReplicatedStorage.Sprint.SharedTypes)
local RemoteEvents = require(ReplicatedStorage.Sprint.RemoteEvents)

local SprintClient = {}

-- Private variables
local player = Players.LocalPlayer
local isSprinting = false
local lastRequestTime = 0
local throttleActive = false
local character = nil
local humanoid = nil

-- GUI reference (will be set by SprintGUI)
local sprintGUI = nil

-- Initialize client
function SprintClient.Init()
    print("[SprintClient] Initializing client for", player.Name)

    -- Set GUI reference
    local SprintGUI = require(script.Parent.SprintGUI)
    SprintGUI.SetClient(SprintClient)
    SprintClient.SetGUI(SprintGUI)

    -- Wait for character
    SprintClient.WaitForCharacter()

    -- Setup input handling
    SprintClient.SetupInputHandling()

    -- Connect to server sync
    RemoteEvents.OnSyncReceived(SprintClient.OnSyncReceived)

    print("[SprintClient] Client initialized")
end

-- Wait for character and setup
function SprintClient.WaitForCharacter()
    local function onCharacterAdded(newCharacter)
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid")

        -- Request current sprint state from server on respawn
        RemoteEvents.FireToggle(isSprinting) -- This will trigger server to send current state

        -- Reset request timing but keep sprint state
        lastRequestTime = 0

        print("[SprintClient] Character loaded - requesting state sync")
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end

    player.CharacterAdded:Connect(onCharacterAdded)
end

-- Setup input handling
function SprintClient.SetupInputHandling()
    -- Keyboard input (only on key press, not release)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Config.DEFAULT_KEYBIND then
            SprintClient.RequestToggle()
        end
    end)

    -- Mobile touch (handled by GUI)
end

-- Request sprint toggle
function SprintClient.RequestToggle()
    if throttleActive then return end

    -- Local throttle check
    local timeSinceLastRequest = tick() - lastRequestTime
    if timeSinceLastRequest < Config.DEBOUNCE_TIME then
        return
    end

    -- Toggle state
    local newState = not isSprinting

    -- Send request to server
    RemoteEvents.FireToggle(newState)

    -- Update local state optimistically
    SprintClient.SetLocalState(newState)

    -- Start throttle
    throttleActive = true
    task.delay(Config.DEBOUNCE_TIME, function()
        throttleActive = false
    end)

    lastRequestTime = tick()
end

-- Handle server sync
function SprintClient.OnSyncReceived(syncData)
    -- Update local state from server
    SprintClient.SetLocalState(syncData.isSprinting)

    -- Update GUI
    if sprintGUI then
        sprintGUI.UpdateVisualState(syncData.isSprinting)
    end
end

-- Set local sprint state
function SprintClient.SetLocalState(newState)
    isSprinting = newState

    -- Update GUI
    if sprintGUI then
        sprintGUI.UpdateVisualState(newState)
    end
end

-- Get current state
function SprintClient.GetCurrentState()
    return isSprinting
end

-- Check if can toggle
function SprintClient.CanToggle()
    return not throttleActive and character and humanoid
end

-- Set GUI reference (deprecated, now auto-required)
function SprintClient.SetGUI(guiModule)
    sprintGUI = guiModule
end

-- Handle request failure (called by GUI)
function SprintClient.OnRequestFailed()
    -- Revert optimistic update
    SprintClient.SetLocalState(not isSprinting)
end

-- Cleanup
function SprintClient.Cleanup()
    -- Disconnect connections if needed
    character = nil
    humanoid = nil
    sprintGUI = nil
end

-- Initialize when script runs
SprintClient.Init()

return SprintClient
