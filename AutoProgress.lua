if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local Player =
    Players.LocalPlayer
    or Players.PlayerAdded:Wait()

local Workspace = game:GetService("Workspace")

pcall(function()
    settings().Rendering.QualityLevel =
        Enum.QualityLevel.Level01
end)

local function hideAntiLagObject(v)
    pcall(function()
        if v:IsA("BasePart") then
            v.Transparency = 1
            v.LocalTransparencyModifier = 1
            v.CastShadow = false
        elseif v:IsA("Decal")
            or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter")
            or v:IsA("Trail")
            or v:IsA("Beam")
            or v:IsA("Smoke")
            or v:IsA("Fire")
            or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("Highlight") then
            v.Enabled = false
        elseif v:IsA("BillboardGui")
            or v:IsA("SurfaceGui") then
            v.Enabled = false
        end
    end)
end

local function hookAntiLagFolder(folder)
    if not folder then
        return
    end

    for _, obj in ipairs(folder:GetDescendants()) do
        hideAntiLagObject(obj)
    end

    folder.DescendantAdded:Connect(function(obj)
        task.defer(function()
            hideAntiLagObject(obj)
        end)
    end)
end

task.spawn(function()
    local Towers =
        Workspace:WaitForChild(
            "Towers",
            30
        )

    local NPCs =
        Workspace:WaitForChild(
            "NPCs",
            30
        )

    if Towers then
        hookAntiLagFolder(Towers)
    end

    if NPCs then
        hookAntiLagFolder(NPCs)
    end

    while true do
        local TowersFolder =
            Workspace:FindFirstChild("Towers")

        local ClientUnits =
            Workspace:FindFirstChild("ClientUnits")

        if TowersFolder then
            for _, tower in ipairs(
                TowersFolder:GetChildren()
            ) do
                local anims =
                    tower:FindFirstChild("Animations")

                local weapon =
                    tower:FindFirstChild("Weapon")

                local projectiles =
                    tower:FindFirstChild("Projectiles")

                if anims then
                    anims:Destroy()
                end

                if projectiles then
                    projectiles:Destroy()
                end

                if weapon then
                    weapon:Destroy()
                end
            end
        end

        if ClientUnits then
            for _, unit in ipairs(
                ClientUnits:GetChildren()
            ) do
                unit:Destroy()
            end
        end

        task.wait(0.5)
    end
end)

local PlayerGui =
    Player:WaitForChild("PlayerGui")

local AUTO_FARM_URL =
    "https://api.jnkie.com/api/v1/luascripts/public/b6f94e11cee9f4f5d02f2d41490f2370afdbed8b345834b3b383decb2c386acc/download"

local WEBHOOK_URL =
    "https://raw.githubusercontent.com/Ceepizz/WEBHOOKSOURCE/refs/heads/main/doakes"

local LIBRARY_URL =
    "https://raw.githubusercontent.com/Ceepizz/rya/refs/heads/main/AutoProgressLib.lua"

local STATS_URL =
    "https://raw.githubusercontent.com/Ceepizz/rya/refs/heads/main/AutoProgressStats.lua"

local CONFIG_FILE =
    "AutoProgressGui_"
    .. tostring(Player.UserId)
    .. ".json"

local LOBBY_PLACE_ID = 3260590327
local VIP_MAP_GAMEPASS_ID = 10518590
local Status

local Config = {
    AutoFarmRunning = false,
    Webhook = ""
}

local function LoadConfig()
    if not isfile
        or not readfile
        or not isfile(CONFIG_FILE) then

        return
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(
            readfile(CONFIG_FILE)
        )
    end)

    if not ok or type(data) ~= "table" then
        return
    end

    for key, defaultValue in pairs(Config) do
        if data[key] ~= nil then
            Config[key] = data[key]
        else
            Config[key] = defaultValue
        end
    end
end

local function SaveConfig()
    if not writefile then
        return
    end

    pcall(function()
        writefile(
            CONFIG_FILE,
            HttpService:JSONEncode(Config)
        )
    end)
end

local function LoadModule(url)
    if type(url) ~= "string"
        or url == ""
        or url:find("PASTE_", 1, true) then

        return nil
    end

    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        warn(
            "[AUTO PROGRESS] Download failed:",
            source
        )

        return nil
    end

    local fn, compileError =
        loadstring(source)

    if not fn then
        warn(
            "[AUTO PROGRESS] Compile failed:",
            compileError
        )

        return nil
    end

    local ran, result = pcall(fn)

    if not ran then
        warn(
            "[AUTO PROGRESS] Module error:",
            result
        )

        return nil
    end

    return result
end

local function RequireSharedOrUrl(
    sharedName,
    url
)
    if type(shared[sharedName]) == "table" then
        return shared[sharedName]
    end

    local result = LoadModule(url)

    if type(result) == "table" then
        return result
    end

    if type(shared[sharedName]) == "table" then
        return shared[sharedName]
    end

    return nil
end

LoadConfig()

local SAVED_KEY = "34817160-15af-4d0f-87e2-434a30dd8136"

if getgenv then
    getgenv().SCRIPT_KEY = SAVED_KEY
    getgenv().Key = SAVED_KEY
    getgenv().key = SAVED_KEY
    getgenv().JNKIE_KEY = SAVED_KEY
    getgenv().script_key = SAVED_KEY
end

script_key = SAVED_KEY
shared.Key = SAVED_KEY
shared.key = SAVED_KEY
shared.script_key = SAVED_KEY

local Library =
    RequireSharedOrUrl(
        "AutoProgressLibrary",
        LIBRARY_URL
    )

if not Library then
    error(
        "AutoProgressLibrary is missing. "
        .. "Execute AutoProgressLibrary.lua first "
        .. "or paste its raw URL into LIBRARY_URL."
    )
end

local Stats =
    RequireSharedOrUrl(
        "AutoProgressStats",
        STATS_URL
    )

if not Stats then
    error(
        "AutoProgressStats is missing. "
        .. "Execute AutoProgressStats.lua first "
        .. "or paste its raw URL into STATS_URL."
    )
end

if Stats.SetRewardTimeout then
    Stats.SetRewardTimeout(3)
end

local AutoFarm
local ProgressWebhook
local Running =
    Config.AutoFarmRunning == true

local GameReady = false

local C = Library.Theme

local function Reconnect()
    local initialCode = GuiService:GetErrorCode()

    if initialCode
        and initialCode ~= Enum.ConnectionError.OK then

        task.wait(5)

        if GuiService:GetErrorCode() == initialCode then
            pcall(function()
                TeleportService:TeleportReconnect()
            end)
        end
    end
end

task.spawn(Reconnect)
GuiService.ErrorMessageChanged:Connect(Reconnect)

local function WaitForLoadingScreen()
    local loadingScreen =
        PlayerGui:FindFirstChild(
            "LoadingScreen"
        )

    local content =
        loadingScreen
        and loadingScreen:FindFirstChild(
            "content"
        )

    if content then
        while content.Visible do
            content
                :GetPropertyChangedSignal(
                    "Visible"
                )
                :Wait()
        end
    end
end

local function IsLoading()
    local attrLoading =
        Player:GetAttribute(
            "Loading"
        ) == true

    local attrTeleporting =
        Player:GetAttribute(
            "Teleporting"
        ) == true

    local pg =
        Player:FindFirstChild(
            "PlayerGui"
        )

    local loadingScreen =
        pg
        and pg:FindFirstChild(
            "LoadingScreen"
        )

    local content =
        loadingScreen
        and loadingScreen:FindFirstChild(
            "content"
        )

    local contentVisible =
        content
        and content.Visible == true

    return
        attrLoading
        or attrTeleporting
        or contentVisible
end

local function WaitUntilLoaded()
    print(
        "[AUTO PROGRESS GUI] Waiting for loading screen..."
    )

    while IsLoading() do
        task.wait(1)
    end

    print(
        "[AUTO PROGRESS GUI] Loaded!"
    )
end

local function WaitForGame()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    Player:WaitForChild("PlayerGui")

    local startedAt = os.clock()

    print(
        "[AUTO PROGRESS GUI] Waiting for loading screen..."
    )

    while IsLoading() do
        if os.clock() - startedAt >= 60 then
            warn(
                "[AUTO PROGRESS GUI] Loading stuck for 60 seconds. Teleporting to lobby..."
            )

            pcall(function()
                TeleportService:Teleport(
                    LOBBY_PLACE_ID,
                    Player
                )
            end)

            return
        end

        task.wait(1)
    end

    print(
        "[AUTO PROGRESS GUI] Loaded!"
    )

    GameReady = true
end

local function GetProgressMode(level)
    level = tonumber(level) or 0

    if level >= 175 then
        return "Molten"
    elseif level >= 50 then
        return "Hardcore"
    elseif level >= 15 then
        return "Molten"
    end

    return "Easy"
end

local function CanOverrideMap()
    local ownsPass = false

    pcall(function()
        ownsPass =
            MarketplaceService:UserOwnsGamePassAsync(
                Player.UserId,
                VIP_MAP_GAMEPASS_ID
            ) == true
    end)

    if ownsPass then
        return true
    end

    local stateReplicators =
        ReplicatedStorage:FindFirstChild(
            "StateReplicators"
        )

    local gameStateReplicator =
        stateReplicators
        and stateReplicators:FindFirstChild(
            "GameStateReplicator"
        )

    return gameStateReplicator
        and gameStateReplicator:GetAttribute(
            "IsPrivateServer"
        ) == true
        or false
end

local function ReadBoardMaps(folderName)
    local lobby =
        workspace:FindFirstChild(folderName)

    local boards =
        lobby
        and lobby:FindFirstChild("Boards")

    if not boards then
        return nil
    end

    local maps = {}

    for i = 1, 4 do
        local board =
            boards:FindFirstChild("Board" .. i)

        local hitboxes =
            board
            and board:FindFirstChild("Hitboxes")

        local bottom =
            hitboxes
            and hitboxes:FindFirstChild("Bottom")

        local mapDisplay =
            bottom
            and bottom:FindFirstChild("MapDisplay")

        local title =
            mapDisplay
            and mapDisplay:FindFirstChild("Title")

        if title then
            maps[i] = title.Text
        end
    end

    return maps
end

local function GetTargetMaps(mode)
    if mode == "Easy" then
        return {
            ["Meltdown"] = true,
            ["Simplicity"] = true,
            ["Stained Temple"] = true,
            ["Midnight Issue"] = true,
            ["Spring Fever"] = true
        }
    elseif mode == "Hardcore" then
        return {
            ["Wretched Front"] = true
        }
    end

    return {
        ["Wrecked Battlefield II"] = true,
        ["Lighthaos"] = true,
        ["Midnight Issue"] = true,
        ["Nether"] = true
    }
end

local function FindTargetMap(mode)
    local folderName =
        mode == "Hardcore"
        and "HardcoreIntermissionLobby"
        or "IntermissionLobby"

    local maps =
        ReadBoardMaps(folderName)

    local targetMaps =
        GetTargetMaps(mode)

    if maps then
        for _, mapName in pairs(maps) do
            if targetMaps[mapName] then
                return mapName
            end
        end
    end

    if CanOverrideMap() then
        for mapName in pairs(targetMaps) do
            return mapName
        end
    end

    return nil
end

local function StartModeMatchmaking(mode)
    local remote =
        ReplicatedStorage:WaitForChild(
            "RemoteFunction"
        )

    local difficulty =
        mode == "Hardcore"
        and "Easy"
        or mode

    local matchmakingMode =
        mode == "Hardcore"
        and "hardcore"
        or "survival"

    local ok, result = pcall(function()
        return remote:InvokeServer(
            "Multiplayer",
            "v2:start",
            {
                difficulty = difficulty,
                mode = matchmakingMode,
                count = 1
            }
        )
    end)

    if not ok then
        warn(
            "[AUTO PROGRESS GUI] Matchmaking failed:",
            result
        )

        return false
    end

    return true
end

local function WaitForTargetMapBeforeBackend(level)
    if game.PlaceId == LOBBY_PLACE_ID then
        return true
    end

    local mode =
        GetProgressMode(level)

    local selectedMap =
        FindTargetMap(mode)

    if selectedMap then
        return true
    end

    local remoteEvent =
        ReplicatedStorage:WaitForChild(
            "RemoteEvent"
        )

    pcall(function()
        remoteEvent:FireServer(
            "LobbyVoting",
            "Veto"
        )
    end)

    task.wait(2)

    selectedMap =
        FindTargetMap(mode)

    if selectedMap then
        return true
    end

    StartModeMatchmaking(mode)

    return false
end

local function LoadAutoFarm()
    if AutoFarm then
        return AutoFarm
    end

    if type(shared.AutoProgress) == "table" then
        AutoFarm = shared.AutoProgress
        return AutoFarm
    end

    AutoFarm =
        LoadModule(AUTO_FARM_URL)

    if type(AutoFarm) ~= "table" then
        AutoFarm = shared.AutoProgress
    end

    return
        type(AutoFarm) == "table"
        and AutoFarm
        or nil
end

local function LoadProgressWebhook()
    if ProgressWebhook then
        return ProgressWebhook
    end

    if type(shared.ProgressWebhook) == "table" then
        ProgressWebhook =
            shared.ProgressWebhook

        return ProgressWebhook
    end

    ProgressWebhook =
        LoadModule(WEBHOOK_URL)

    if type(ProgressWebhook) ~= "table" then
        ProgressWebhook =
            shared.ProgressWebhook
    end

    return
        type(ProgressWebhook) == "table"
        and ProgressWebhook
        or nil
end

WaitForGame()

local Window =
    Library.CreateWindow({
        Title = "Auto Progress",
        GuiName = "AutoProgressGui",
        Width = 430,
        CompactHeight = 150,
        ExpandedHeight = 470
    })

local Gui = Window.Gui
local Content = Window.Content

local Home =
    Library.CreatePage(
        Content,
        false
    )

Library.AddListLayout(
    Home,
    12
)

local Selector =
    Library.CreateButton(
        Home,
        "Auto Farm Until Gatling",
        48
    )

local FarmPage =
    Library.CreatePage(
        Content,
        true
    )

FarmPage.Visible = false

Library.AddListLayout(
    FarmPage,
    10
)

local Back =
    Library.CreateButton(
        FarmPage,
        "< BACK",
        36
    )

Back.LayoutOrder = 1

local SectionTitle =
    Library.CreateLabel(
        FarmPage,
        "Auto Farm Until Gatling",
        28
    )

SectionTitle.LayoutOrder = 2
SectionTitle.TextColor3 = C.Text
SectionTitle.TextSize = 16
SectionTitle.Font = Enum.Font.GothamBold

Status =
    Library.CreateLabel(
        FarmPage,
        "Status: Disabled"
    )

Status.LayoutOrder = 3

local Level =
    Library.CreateLabel(
        FarmPage,
        "Level: Loading..."
    )

Level.LayoutOrder = 4

local Coins =
    Library.CreateLabel(
        FarmPage,
        "Coins: Loading..."
    )

Coins.LayoutOrder = 5

local Gatling =
    Library.CreateLabel(
        FarmPage,
        "Gatling Gun: Checking..."
    )

Gatling.LayoutOrder = 6

local WebhookTitle =
    Library.CreateLabel(
        FarmPage,
        "Progress Webhook"
    )

WebhookTitle.LayoutOrder = 7

local WebhookBox =
    Library.CreateTextBox(
        FarmPage,
        {
            Placeholder =
                "Paste Discord webhook...",
            Text =
                tostring(
                    Config.Webhook or ""
                ),
            Height = 40
        }
    )

WebhookBox.LayoutOrder = 8

local Toggle =
    Library.CreateButton(
        FarmPage,
        "START",
        42
    )

Toggle.LayoutOrder = 9

local SendWebhook =
    Library.CreateButton(
        FarmPage,
        "SEND WEBHOOK",
        42
    )

SendWebhook.LayoutOrder = 10

local function ShowHome()
    Home.Visible = true
    FarmPage.Visible = false
    Window:SetCompact()
end

local function ShowFarm()
    Home.Visible = false
    FarmPage.Visible = true
    Window:SetExpanded()
end

Selector.MouseButton1Click:Connect(
    ShowFarm
)

Back.MouseButton1Click:Connect(
    ShowHome
)

local LastSnapshot =
    Stats.GetSnapshot()


local function UpdateStatusText()
    if not Running then
        Status.Text = "Status: Disabled"
        return
    end

    if game.PlaceId == LOBBY_PLACE_ID then
        Status.Text = "Status: Running | Waiting for Match"
    else
        Status.Text = "Status: Running | Anti-Stuck: 15m"
    end
end

local function Refresh(snapshot)
    if not Gui.Parent then
        return
    end

    snapshot =
        snapshot
        or Stats.GetSnapshot()

    LastSnapshot = snapshot

    local level =
        tonumber(snapshot.Level) or 0

    local coins =
        tonumber(snapshot.Coins) or 0

    local owned =
        snapshot.GatlingOwned == true

    Level.Text =
        "Level: " .. tostring(level)

    if owned then
        Coins.Visible = false

        Gatling.Text =
            "Gatling Gun: Owned"

        Gatling.TextColor3 =
            C.Green


        Toggle.Text =
            "COMPLETED"

        Toggle.BackgroundColor3 =
            C.Border

        Running = false
        Config.AutoFarmRunning = false
        SaveConfig()

    UpdateStatusText()
        return
    end

    Coins.Visible = true

    Coins.Text =
        "Coins: "
        .. Library.FormatNumber(coins)
        .. " / 35,000"

    Gatling.Text =
        "Gatling Gun: Not Owned"

    Gatling.TextColor3 =
        C.Muted


    if not GameReady then

        Toggle.Text =
            Running
            and "STOP"
            or "START"

        return
    end
    if Running then
        Toggle.Text = "STOP"
        UpdateStatusText()
    else
        Toggle.Text = "START"
        UpdateStatusText()
    end
end
local function SetWebhook()
    Config.Webhook =
        WebhookBox.Text

    SaveConfig()

    local module =
        LoadProgressWebhook()

    if not module
        or not module.SetWebhook then

        return false
    end

    module.SetWebhook(
        WebhookBox.Text
    )

    return true
end

local StartTaskRunning = false

local function StartFarm(
    resumeExisting
)
    if StartTaskRunning then
        return
    end

    if Running
        and not resumeExisting then

        return
    end

    Running = true
    Config.AutoFarmRunning = true
    SaveConfig()

    UpdateStatusText()

    Toggle.Text = "STOP"

    UpdateStatusText()

    StartTaskRunning = true

    task.spawn(function()
        WaitForGame()

        if not Running then
            StartTaskRunning = false
            return
        end

        if Stats.IsGatlingOwned() then
            Running = false
            Config.AutoFarmRunning = false
            SaveConfig()

            StartTaskRunning = false
            Refresh()

            return
        end

        if game.PlaceId ~= LOBBY_PLACE_ID then
            local snapshot =
                Stats.GetSnapshot()

            local level =
                tonumber(snapshot.Level) or 0

            local mapReady =
                WaitForTargetMapBeforeBackend(level)

            if not Running then
                StartTaskRunning = false
                return
            end

            if not mapReady then
                StartTaskRunning = false
                Refresh()
                return
            end
        end

        local farm =
            LoadAutoFarm()

        if not Running then
            StartTaskRunning = false
            return
        end

        if not farm
            or not farm.Start then

            Running = false
            Config.AutoFarmRunning = false
            SaveConfig()

            Toggle.Text = "START"
            StartTaskRunning = false

            return
        end

        local webhook =
            LoadProgressWebhook()

        if webhook
            and WebhookBox.Text ~= ""
            and webhook.SetWebhook then

            Config.Webhook =
                WebhookBox.Text

            SaveConfig()

            webhook.SetWebhook(
                WebhookBox.Text
            )
        end

        if webhook
            and webhook.Start then

            webhook.Start()
        end

        local alreadyRunning = false

        if shared.AutoProgress
            and shared.AutoProgress.GetStatus then

            local ok, state =
                pcall(
                    shared.AutoProgress.GetStatus
                )

            if ok and state then
                local stateText =
                    tostring(state)

                alreadyRunning =
                    stateText ~= ""
                    and stateText ~= "Disabled"
                    and stateText
                        ~= "Status: Disabled"
            end
        end

        if not alreadyRunning
            and Running then

            farm.Start()
        end

        StartTaskRunning = false
        Refresh()
    end)
end

local function StopFarm()
    Running = false
    Config.AutoFarmRunning = false
    SaveConfig()

    if AutoFarm
        and AutoFarm.Stop then

        AutoFarm.Stop()
    elseif shared.AutoProgress
        and shared.AutoProgress.Stop then

        shared.AutoProgress.Stop()
    end

    Refresh()
end

local function ToggleFarm()
    if Stats.IsGatlingOwned() then
        Refresh()
        return
    end

    if Running then
        StopFarm()
    else
        StartFarm()
    end
end

local function SendProgressWebhook()
    if not GameReady then

        return
    end

    local module =
        LoadProgressWebhook()

    if not module then

        return
    end

    if WebhookBox.Text ~= ""
        and module.SetWebhook then

        Config.Webhook =
            WebhookBox.Text

        SaveConfig()

        module.SetWebhook(
            WebhookBox.Text
        )
    end

    if module.Send then
        local ok, result =
            module.Send(true)
    else
    end
end

Toggle.MouseButton1Click:Connect(
    ToggleFarm
)

SendWebhook.MouseButton1Click:Connect(
    SendProgressWebhook
)

WebhookBox.FocusLost:Connect(function()
    Config.Webhook =
        WebhookBox.Text

    SaveConfig()

    if WebhookBox.Text ~= "" then
        SetWebhook()
    end
end)

Stats.Start(function(snapshot)
    Refresh(snapshot)
end)

Gui.Destroying:Connect(function()
    Stats.Stop()
end)

if Running then
    ShowFarm()

    task.defer(function()
        StartFarm(true)
    end)
else
    ShowHome()

    task.spawn(function()
        WaitForGame()
        Refresh()
    end)
end

Refresh(LastSnapshot)