-- RemoteEvents.lua
-- Centralized remote management
-- Avoid hardcoded remote names & type-safe communication

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SprintFolder = ReplicatedStorage:WaitForChild("Sprint")
local EventsFolder = SprintFolder:WaitForChild("Events")

local RemoteEvents = {
    -- Remote Events
    SprintToggleEvent = EventsFolder:WaitForChild("SprintToggleEvent"), -- RemoteEvent: Client -> Server
    SprintSyncEvent = EventsFolder:WaitForChild("SprintSyncEvent"), -- RemoteEvent: Server -> Client
}

-- Helper Functions

-- Client: Fire toggle request to server
function RemoteEvents.FireToggle(requestedState)
    assert(typeof(requestedState) == "boolean", "requestedState must be boolean")
    RemoteEvents.SprintToggleEvent:FireServer(requestedState)
end

-- Server: Send sync data to specific client
function RemoteEvents.SendSync(player, syncData)
    assert(typeof(player) == "Instance" and player:IsA("Player"), "player must be Player instance")
    assert(typeof(syncData) == "table", "syncData must be table")
    RemoteEvents.SprintSyncEvent:FireClient(player, syncData)
end

-- Server: Send sync to all clients (broadcast)
function RemoteEvents.BroadcastSync(syncData)
    assert(typeof(syncData) == "table", "syncData must be table")
    RemoteEvents.SprintSyncEvent:FireAllClients(syncData)
end

-- Client: Connect to sync event
function RemoteEvents.OnSyncReceived(callback)
    assert(typeof(callback) == "function", "callback must be function")
    return RemoteEvents.SprintSyncEvent.OnClientEvent:Connect(callback)
end

-- Server: Connect to toggle event
function RemoteEvents.OnToggleRequested(callback)
    assert(typeof(callback) == "function", "callback must be function")
    return RemoteEvents.SprintToggleEvent.OnServerEvent:Connect(callback)
end

return RemoteEvents
