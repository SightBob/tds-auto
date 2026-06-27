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

local MAX_GAMES = 10

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
    print("Returning to TDS lobby...")

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
    print("Starting easy strategy...")

    local success, err = pcall(function()
        TDS:ResetIndex()
        TDS:Ready()
        TDS:VoteSkip(1, 20)

        TDS:Place(
            "Scout",
            -11.131479263305664,
            0.9999938011169434,
            -9.647957801818848,
            true
        )

        TDS:Upgrade(1)
        TDS:Upgrade(1)

        for i = 1, 9 do
            TDS:Place(
                "Scout",
                -11.131479263305664,
                0.9999938011169434,
                -9.647957801818848,
                true
            )
        end

        TDS:Upgrade(2)
        TDS:Upgrade(2)
        TDS:Upgrade(3)
        TDS:Upgrade(3)
        TDS:Upgrade(4)
        TDS:Upgrade(4)
        TDS:Upgrade(5)
        TDS:Upgrade(6)
        TDS:Upgrade(6)
        TDS:Upgrade(7)
        TDS:Upgrade(7)
        TDS:Upgrade(8)
        TDS:Upgrade(9)
        TDS:Upgrade(9)
        TDS:Upgrade(10)
        TDS:Upgrade(10)

        TDS:Upgrade(1)
        TDS:Upgrade(1)
        TDS:Upgrade(2)
        TDS:Upgrade(2)
        TDS:Upgrade(3)
        TDS:Upgrade(3)
        TDS:Upgrade(4)
        TDS:Upgrade(4)
        TDS:Upgrade(5)
        TDS:Upgrade(6)
        TDS:Upgrade(6)
        TDS:Upgrade(7)
        TDS:Upgrade(7)
        TDS:Upgrade(8)
        TDS:Upgrade(9)
        TDS:Upgrade(9)
        TDS:Upgrade(10)
        TDS:Upgrade(10)

        for i = 1, 20 do
            TDS:Place(
                "Scout",
                -11.131479263305664,
                0.9999938011169434,
                -9.647957801818848,
                true
            )
        end

        for i = 1, 4 do
            TDS:Upgrade(11)
        end

        for i = 1, 4 do
            TDS:Upgrade(12)
        end

        for i = 1, 4 do
            TDS:Upgrade(13)
        end

        TDS:WaitForWave(19)
        task.wait(4)

        for i = 1, 30 do
            TDS:Sell(i)
        end
    end)

    stratRunning = false

    if success then
        print("Easy strategy finished.")
    else
        warn("Easy strategy error:", err)
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

local function CheckGameOver()
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
        print(MAX_GAMES .. " game completed. Returning to lobby...")
        task.wait(1)
        BackToLobby()
        return
    end

    task.spawn(function()
        task.wait(1)

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
        print("Starting new easy strategy match!")
        activeStratThread = task.spawn(StartStrategy)
    end)
end

GameStateReplicator
    :GetAttributeChangedSignal("GameOver")
    :Connect(CheckGameOver)

activeStratThread = task.spawn(StartStrategy)
CheckGameOver()
