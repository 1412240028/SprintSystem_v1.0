-- PlayerDataManager.lua
-- Handle semua player data operations
-- Single Responsibility: data management, persistence, cleanup

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Sprint.Config)
local SharedTypes = require(ReplicatedStorage.Sprint.SharedTypes)

local PlayerDataManager = {}

-- Private variables
local dataStore = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local playerDataCache = {} -- player -> data

-- Create new player data structure
function PlayerDataManager.CreatePlayerData(player)
    local data = table.clone(SharedTypes.PlayerData)
    data.userId = player.UserId
    data.isSprinting = false
    data.lastToggleTime = 0
    data.toggleCount = 0
    data.character = nil
    data.humanoid = nil
    data.lastSpeedCheck = 0
    data.speedViolations = 0
    -- Checkpoint System integration
    data.lastCheckpointId = nil
    data.checkpointTimestamp = 0

    playerDataCache[player] = data
    return data
end

-- Get player data safely
function PlayerDataManager.GetPlayerData(player)
    return playerDataCache[player]
end

-- Update sprint state
function PlayerDataManager.UpdateSprintState(player, isSprinting)
    local data = playerDataCache[player]
    if not data then return end

    data.isSprinting = isSprinting
    data.lastToggleTime = tick()
    data.toggleCount = data.toggleCount + 1
end

-- Update checkpoint data (Checkpoint System integration)
function PlayerDataManager.UpdateCheckpointData(player, checkpointId)
    local data = playerDataCache[player]
    if not data then return end

    data.lastCheckpointId = checkpointId
    data.checkpointTimestamp = tick()
end

-- Save player data to DataStore
function PlayerDataManager.SavePlayerData(player)
    local data = playerDataCache[player]
    if not data then return end

    local key = Config.DATASTORE_KEY_PREFIX .. tostring(data.userId)
    local saveData = {
        isSprinting = data.isSprinting,
        toggleCount = data.toggleCount,
        speedViolations = data.speedViolations,
        lastPlayedVersion = "1.0",
        -- Checkpoint System integration
        lastCheckpointId = data.lastCheckpointId,
        checkpointTimestamp = data.checkpointTimestamp
    }

    -- Retry logic with exponential backoff
    for attempt = 1, Config.SAVE_RETRY_ATTEMPTS do
        local success, errorMessage = pcall(function()
            dataStore:SetAsync(key, saveData)
        end)

        if success then
            print(string.format("[PlayerDataManager] Saved data for %s", player.Name))
            return true
        else
            warn(string.format("[PlayerDataManager] Save attempt %d failed for %s: %s",
                attempt, player.Name, errorMessage))

            if attempt < Config.SAVE_RETRY_ATTEMPTS then
                task.wait(attempt * Config.SAVE_RETRY_DELAY_BASE)
            end
        end
    end

    warn(string.format("[PlayerDataManager] Failed to save data for %s after %d attempts",
        player.Name, Config.SAVE_RETRY_ATTEMPTS))
    return false
end

-- Load player data from DataStore
function PlayerDataManager.LoadPlayerData(player)
    local data = playerDataCache[player]
    if not data then return end

    local key = Config.DATASTORE_KEY_PREFIX .. tostring(data.userId)

    local success, loadedData = pcall(function()
        return dataStore:GetAsync(key)
    end)

    if success and loadedData then
        -- Apply loaded data
        data.isSprinting = loadedData.isSprinting or false
        data.toggleCount = loadedData.toggleCount or 0
        data.speedViolations = loadedData.speedViolations or 0
        -- Checkpoint System integration
        data.lastCheckpointId = loadedData.lastCheckpointId or nil
        data.checkpointTimestamp = loadedData.checkpointTimestamp or 0

        print(string.format("[PlayerDataManager] Loaded data for %s (sprinting: %s, toggles: %d, checkpoint: %s)",
            player.Name, tostring(data.isSprinting), data.toggleCount, tostring(data.lastCheckpointId)))
    else
        -- Use defaults
        warn(string.format("[PlayerDataManager] Load failed for %s, using defaults", player.Name))
        data.isSprinting = false
        data.toggleCount = 0
        data.speedViolations = 0
        -- Checkpoint System integration
        data.lastCheckpointId = nil
        data.checkpointTimestamp = 0
    end
end

-- Cleanup player data
function PlayerDataManager.CleanupPlayerData(player)
    playerDataCache[player] = nil
end

-- Get all active player data (for debugging)
function PlayerDataManager.GetAllPlayerData()
    return playerDataCache
end

-- Force save all data (emergency)
function PlayerDataManager.SaveAllData()
    for player in pairs(playerDataCache) do
        PlayerDataManager.SavePlayerData(player)
    end
end

return PlayerDataManager
