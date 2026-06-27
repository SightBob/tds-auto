local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local RemoteFunction = ReplicatedStorage:WaitForChild("RemoteFunction")

local GameStateReplicator = ReplicatedStorage
    :WaitForChild("StateReplicators")
    :WaitForChild("GameStateReplicator")

local BackToLobbyRemote = ReplicatedStorage
    :WaitForChild("Network")
    :WaitForChild("Teleport")
    :WaitForChild("RE:backToLobby")

local MAX_GAMES = 20

local activeStratThread = nil
local stratRunning = false
local returningToLobby = false
local gameOverHandled = false
local gameCount = 0

local function BackToLobby()
    if returningToLobby then
        return
    end

    returningToLobby = true
    print(MAX_GAMES .. " games reached. Returning to lobby...")

    local success, err = pcall(function()
        BackToLobbyRemote:FireServer()
    end)

    if not success then
        warn("Back to lobby failed:", err)
        returningToLobby = false
    end
end

local function StartStrategy()
    if stratRunning or returningToLobby then
        return
    end

    stratRunning = true
    print("Starting strategy...")

    local success, err = pcall(function()
        TDS:ResetIndex()
        TDS:Ready()
        TDS:VoteSkip(1, 20)

        for i = 1, 15 do
            TDS:Place(
                "Assassin",
                4.272305488586426,
                1.0368714332580566,
                -31.2442684173584,
                true
            )
        end

        for towerIndex = 1, 15 do
            for i = 1, 2 do
                TDS:Upgrade(towerIndex)
            end
        end

        for i = 1, 25 do
            TDS:Place(
                "Assassin",
                4.272305488586426,
                1.0368714332580566,
                -31.2442684173584,
                true
            )
        end

        for towerIndex = 16, 40 do
            for i = 1, 2 do
                TDS:Upgrade(towerIndex)
            end
        end
    end)

    stratRunning = false

    if success then
        print("Strategy finished.")
    else
        warn("Strategy error:", err)
    end
end

local function StopStrategy()
    if activeStratThread and coroutine.status(activeStratThread) ~= "dead" then
        task.cancel(activeStratThread)
    end

    activeStratThread = nil
    stratRunning = false
end

local function RestartMatch()
    print("Firing Voting Skip to restart match...")

    local success, result = pcall(function()
        return RemoteFunction:InvokeServer("Voting", "Skip")
    end)

    if not success then
        warn("Voting Skip failed:", result)
        return false
    end

    print("Voting Skip fired.")
    return true
end

local function WaitForNewMatch()
    print("Waiting for GameOver to become false...")

    while not returningToLobby do
        if GameStateReplicator:GetAttribute("GameOver") == false then
            return true
        end

        task.wait(0.25)
    end

    return false
end

local function HandleGameOver()
    local gameOver = GameStateReplicator:GetAttribute("GameOver")

    if gameOver == false then
        gameOverHandled = false
        return
    end

    if gameOver ~= true or gameOverHandled or returningToLobby then
        return
    end

    gameOverHandled = true
    gameCount += 1

    print("Game Over detected!")
    print("Game Count:", gameCount .. "/" .. MAX_GAMES)

    StopStrategy()

    if gameCount >= MAX_GAMES then
        task.wait(1)
        BackToLobby()
        return
    end

    task.spawn(function()
        task.wait(1)

        if returningToLobby then
            return
        end

        if not RestartMatch() then
            gameOverHandled = false
            return
        end

        if not WaitForNewMatch() then
            return
        end

        task.wait(1.5)

        if returningToLobby then
            return
        end

        gameOverHandled = false

        print("Starting new strategy match!")
        activeStratThread = task.spawn(StartStrategy)
    end)
end

GameStateReplicator
    :GetAttributeChangedSignal("GameOver")
    :Connect(HandleGameOver)

activeStratThread = task.spawn(StartStrategy)
HandleGameOver()
