if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local SETTINGS_FILE = "AutoProgression.json"

local plr = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = plr:WaitForChild("PlayerGui")

local function WaitForLoadingScreen()
    local loadingScreen = PlayerGui:FindFirstChild("LoadingScreen")
    local content = loadingScreen and loadingScreen:FindFirstChild("content")

    if content then
        task.spawn(function()
            while content.Visible do
                content:GetPropertyChangedSignal("Visible"):Wait()
            end
        end)
    end
end

local rf = ReplicatedStorage:WaitForChild("RemoteFunction")


local TeleportService = game:GetService("TeleportService")
local LOBBY_PLACE_ID = 3260590327

local function AntiStuck()
    task.spawn(function()
        local secondsStuck = 0

        while true do
            task.wait(1)

            local attrLoading = plr:GetAttribute("Loading") == true
            local attrTeleporting = plr:GetAttribute("Teleporting") == true

            local pg = plr:FindFirstChild("PlayerGui")
            local loadScreen = pg and pg:FindFirstChild("LoadingScreen")
            local loadContent = loadScreen and loadScreen:FindFirstChild("content")
            local isLoadVisible = loadContent and loadContent.Visible == true

            local loading = attrLoading or attrTeleporting or isLoadVisible

            if loading then
                secondsStuck += 1

                if secondsStuck >= 60 then
                    print("Loading stuck for 60 seconds. Teleporting...")

                    pcall(function()
                        TeleportService:Teleport(LOBBY_PLACE_ID, plr)
                    end)

                    secondsStuck = 0
                end
            else
                secondsStuck = 0
            end
        end
    end)
end

AntiStuck()

local Settings = {
    AutoProgression = false
}

if isfile and isfile(SETTINGS_FILE) then
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(SETTINGS_FILE))
    end)

    if success and type(data) == "table" then
        Settings = data
    end
end

local function SaveSettings()
    if writefile then
        writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings))
    end
end

local function WaitUntilLoaded()
    print("Waiting for loading screen...")

    while true do
        task.wait(1)

        local attrLoading = plr:GetAttribute("Loading") == true
        local attrTeleporting = plr:GetAttribute("Teleporting") == true

        local pg = plr:FindFirstChild("PlayerGui")
        local loadScreen = pg and pg:FindFirstChild("LoadingScreen")
        local loadContent = loadScreen and loadScreen:FindFirstChild("content")
        local isLoadVisible = loadContent and loadContent.Visible == true

        local loading = attrLoading or attrTeleporting or isLoadVisible

        if loading then
            print("Loading...")
        else
            print("Loaded!")
            break
        end
    end
end

local function GetStat(name)
    local obj = plr:FindFirstChild(name)

    if obj and obj.Value ~= nil then
        return tonumber(obj.Value) or 0
    end

    local attr = plr:GetAttribute(name)
    if attr ~= nil then
        return tonumber(attr) or 0
    end

    local leaderstats = plr:FindFirstChild("leaderstats")
    local stat = leaderstats and leaderstats:FindFirstChild(name)

    if stat and stat.Value ~= nil then
        return tonumber(stat.Value) or 0
    end

    return 0
end

local oldGui = CoreGui:FindFirstChild("Tracker")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "Tracker"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 280, 0, 320)
frame.Position = UDim2.new(0.5, -140, 0.5, -160)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
frame.BorderSizePixel = 0
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 80)
stroke.Thickness = 2
stroke.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, -24, 0, 38)
header.Position = UDim2.new(0, 12, 0, 12)
header.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
header.BorderSizePixel = 0
header.Parent = frame

Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 220))
})
gradient.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "Auto Progression OFF"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = header

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MaxTextSize = 22
titleConstraint.MinTextSize = 15
titleConstraint.Parent = title

local function makeStatRow(name, y, color)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 26)
    row.Position = UDim2.new(0, 12, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(180, 180, 200)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local value = Instance.new("TextLabel")
    value.Size = UDim2.new(0.55, -12, 1, 0)
    value.Position = UDim2.new(0.45, 12, 0, 0)
    value.BackgroundTransparency = 1
    value.Text = "..."
    value.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    value.TextScaled = true
    value.Font = Enum.Font.GothamBold
    value.TextXAlignment = Enum.TextXAlignment.Right
    value.Parent = row

    local labelConstraint = Instance.new("UITextSizeConstraint")
    labelConstraint.MaxTextSize = 14
    labelConstraint.MinTextSize = 10
    labelConstraint.Parent = label

    local valueConstraint = Instance.new("UITextSizeConstraint")
    valueConstraint.MaxTextSize = 14
    valueConstraint.MinTextSize = 10
    valueConstraint.Parent = value

    return value
end

local levelValue    = makeStatRow("Level", 60, Color3.fromRGB(120, 200, 255))
local expValue      = makeStatRow("EXP", 88, Color3.fromRGB(180, 220, 120))
local coinsValue    = makeStatRow("Coins", 116, Color3.fromRGB(255, 215, 100))
local gemsValue     = makeStatRow("Gems", 144, Color3.fromRGB(200, 140, 255))
local winsValue     = makeStatRow("Wins", 172, Color3.fromRGB(255, 180, 180))

local statusDisplay = Instance.new("TextLabel")
statusDisplay.Size = UDim2.new(1, 0, 0, 25)
statusDisplay.Position = UDim2.new(0, 0, 0, 205)
statusDisplay.BackgroundTransparency = 1
statusDisplay.Text = "Status: Waiting..."
statusDisplay.TextColor3 = Color3.fromRGB(200, 200, 200)
statusDisplay.TextScaled = true
statusDisplay.Font = Enum.Font.GothamBold
statusDisplay.TextXAlignment = Enum.TextXAlignment.Center
statusDisplay.Parent = frame

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0, 90, 0, 30)
toggle.Position = UDim2.new(0.5, -45, 1, -42)
toggle.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
toggle.Text = "OFF"
toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle.TextScaled = true
toggle.Font = Enum.Font.GothamBold
toggle.Parent = frame

Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 10)

local AutoProgression = Settings.AutoProgression
local running = false
local runningEasy = false
local runningPizza = false
local runningHardcore = false

local function BuyTower(towerName)
    print("buying " .. towerName)
    return rf:InvokeServer("Shop", "Purchase", "Tower", towerName)
end

local AETHER_DELAY = 15

local function RemoveAether(delay)
    task.spawn(function()
        task.wait(delay or AETHER_DELAY)
        local aether = CoreGui:FindFirstChild("Aether")
        if aether then
            aether:Destroy()
        end
    end)
end

local function RunEasy()
    if runningEasy then return end
    runningEasy = true

    statusDisplay.Text = "Status: Grinding Easy"

    print("starting easy strat")

    getgenv().AutoPremium = true
    getgenv().AutoSkip = true
    getgenv().AutoRejoin = false
    getgenv().TimeScaleEnabled = false
    getgenv().TimeScaleValue = 2

    local TDS = loadstring(game:HttpGet("https://raw.githubusercontent.com/SightBob/tds-auto/main/Aetherv2.lua"))()

    RemoveAether()


    TDS:Loadout("Scout", "None", "None", "None", "None")
    TDS:Mode("Easy")
    TDS:GameInfo("Simplicity", {})

    loadstring(game:HttpGet("https://raw.githubusercontent.com/SightBob/tds-auto/main/easy.lua"))()
end

local function RunPizza()
    if runningPizza then return end
    runningPizza = true

    statusDisplay.Text = "Status: Grinding Pizza"

    print("starting pizza strat")

    getgenv().AutoPremium = true
    getgenv().AutoSkip = true
    getgenv().AutoRejoin = false

    local TDS = loadstring(game:HttpGet("https://raw.githubusercontent.com/SightBob/tds-auto/main/Aetherv2.lua"))()

    RemoveAether()

    TDS:Loadout("Assassin", "None", "None", "None", "None")
    TDS:Mode("PizzaParty")

    loadstring(game:HttpGet("https://raw.githubusercontent.com/SightBob/tds-auto/main/pizza.lua"))()
end

local function RunHardcore()
    if runningHardcore then return end
    runningHardcore = true

    statusDisplay.Text = "Status: Grinding Hardcore"

    print("starting hardcore mode")

    getgenv().AutoPremium = true
    getgenv().AutoSkip = true
    getgenv().AutoRejoin = false
    getgenv().TimeScaleEnabled = true
    getgenv().TimeScaleValue = 2

    local TDS = loadstring(game:HttpGet("https://raw.githubusercontent.com/SightBob/tds-auto/main/Aetherv2.lua"))()
    RemoveAether()

    if game.PlaceId == 3260590327 then
        rf:InvokeServer("Multiplayer", "v2:start", {
            difficulty = "Easy",
            mode = "hardcore",
            count = 1
        })
    end

    TDS:GameInfo("Wretched Front", {})
    TDS:Loadout("Pyromancer", "Hunter", "Minigunner", "EvolvedJuggernaut", "None")

    loadstring(game:HttpGet("https://raw.githubusercontent.com/SightBob/tds-auto/main/hardcore.lua"))()
end

local function RunAutoProgression()
    if running then return end
    running = true

    print("Auto progression loop started")

    while AutoProgression do
        WaitUntilLoaded()
        task.wait(1)

        if not AutoProgression then break end

        runningEasy = false
        runningPizza = false
        runningHardcore = false

        local level = GetStat("Level")
        local coins = GetStat("Coins")

        print("Level:", level, "Coins:", coins)

        if level >= 50 then
            if coins >= 2250 then
                BuyTower("Pyromancer")
                task.wait(1)
                BuyTower("Hunter")
                task.wait(1)
            end
            RunHardcore()
        elseif level <= 24 then
            RunEasy()
        else
            if coins >= 800 then
                BuyTower("Assassin")
                task.wait(1)
            end
            RunPizza()
        end

        local leaveTimeout = 0
        while AutoProgression and game.PlaceId == LOBBY_PLACE_ID and leaveTimeout < 120 do
            task.wait(1)
            leaveTimeout += 1
        end

        while AutoProgression and game.PlaceId ~= LOBBY_PLACE_ID do
            task.wait(2)
        end

        task.wait(3)
    end

    running = false
    print("Auto progression loop stopped")
end

toggle.MouseButton1Click:Connect(function()
    AutoProgression = not AutoProgression
    Settings.AutoProgression = AutoProgression
    SaveSettings()

    if AutoProgression then
        toggle.Text = "ON"
        toggle.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
        title.Text = "Auto Progression Running"
        task.spawn(RunAutoProgression)
    else
        toggle.Text = "OFF"
        toggle.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        title.Text = "Auto Progression OFF"
    end
end)

if AutoProgression then
    toggle.Text = "ON"
    toggle.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    title.Text = "Auto Progression Running"
    task.spawn(RunAutoProgression)
end

local dragging = false
local dragInput
local dragStart
local startPos

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

local function formatNum(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.2fK", n / 1e3) end
    return tostring(n)
end

task.spawn(function()
    while task.wait(1) do
        local level = GetStat("Level")
        local exp = GetStat("EXP") or GetStat("Xp") or GetStat("Experience")
        local coins = GetStat("Coins")
        local gems = GetStat("Gems")
        local wins = GetStat("Wins")

        levelValue.Text = level > 0 and tostring(level) or "..."
        expValue.Text = (exp and exp > 0) and formatNum(exp) or "..."
        coinsValue.Text = (coins and coins > 0) and formatNum(coins) or "..."
        gemsValue.Text = (gems and gems > 0) and formatNum(gems) or "..."
        winsValue.Text = (wins and wins > 0) and tostring(wins) or "..."
    end
end)