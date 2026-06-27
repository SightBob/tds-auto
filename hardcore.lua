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

local MAX_GAMES = 30

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

        TDS:Place(
            "Pyromancer",
            -5.936307430267334,
            0.9551397562026978,
            -31.831748962402344
        )

        TDS:SetTarget(1, "Farthest")

        for i = 1, 4 do
            TDS:Upgrade(1)
        end

        for i = 1, 9 do
            TDS:Place(
                "Hunter",
                2.679039716720581,
                1.341203212738037,
                21.30302619934082,
                true
            )
        end

        TDS:Place(
            "Minigunner",
            2.679039716720581,
            1.341203212738037,
            21.30302619934082,
            true
        )

        for i = 1, 10 do
            TDS:Sell(i)
        end

        TDS:Place(
            "EvolvedJuggernaut",
            2.679039716720581,
            1.341203212738037,
            21.30302619934082,
            true
        )
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
