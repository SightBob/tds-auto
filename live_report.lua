if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local LOBBY_PLACE_ID = 3260590327

-- ================= Discord Webhook Report =================
-- ใส่ URL ของ Discord Webhook คุณที่นี่ (Server Settings -> Integrations -> Webhooks -> Copy Webhook URL)
-- ปล่อยว่างไว้ = ระบบรายงานปิดอยู่ จะไม่ส่งข้อมูลอะไรไปที่ไหนเลย
local WEBHOOK_URL = ""

-- ส่งรายงานปกติทุกกี่วินาที / ส่งทันทีเมื่อสถานะเปลี่ยน (มี debounce กัน rate limit)
local WEBHOOK_UPDATE_INTERVAL = 60
local WEBHOOK_EVENT_MIN_GAP = 10

local HttpService = game:GetService("HttpService")
local WebhookStartClock = os.clock()
local WebhookMessageId = nil
local WebhookLastSentAt = -math.huge
local WebhookLastKey = nil
local WebhookLastSentSupabase = false
local WebhookNotified = false
-- ===========================================================

-- ================= Supabase Live Website =================
-- ตั้งค่าให้เว็บ dashboard ทำงานแบบเรียลไทม์ (ดูขั้นตอนในไฟล์ supabase-setup.sql และ dashboard.html)
-- 1) SUPABASE_URL = "https://xxxxxxxx.supabase.co"  (Project Settings -> General)
-- 2) SUPABASE_ANON_KEY = anon "publishable" key     (Project Settings -> API)
-- ปล่อยว่างไว้ = ระบบเว็บรายงานปิดอยู่ (Discord ทำงานแยกจากกัน)
local SUPABASE_URL = "https://ajcqqfrvumyxupufnesd.supabase.co"
local SUPABASE_ANON_KEY = "sb_publishable_k2UQNK0MJsJP0roEPFH0Qw_7wOe-VhG"
-- ===========================================================

local LOADING_TIMEOUT = 100
local LOBBY_LOADING_TIMEOUT = 60
local GAMEOVER_STEP_TIMEOUT = 60
local NO_GAMEOVER_TIMEOUT = 30 * 120

local LoaderActive = true
local ReconnectCheckRunning = false

local RecoveryRunning = false
local SessionStartedAt = nil
local LastRep = nil

local SavedState = {
    Difficulty = nil,
    DisplayName = nil,
    Mode = "survival"
}

local Executor = identifyexecutor and identifyexecutor()
if Executor == "Solara" or Executor == "Xeno" then
    game:GetService("Players").LocalPlayer:Kick("Unsupported executor: " .. Executor)
end

local function GetRep()
    local stateReplicators =
        ReplicatedStorage:FindFirstChild("StateReplicators")

    return stateReplicators
        and stateReplicators:FindFirstChild("GameStateReplicator")
end

local function IsInGame()
    return GetRep() ~= nil
end

local function CacheState(rep)
    if not rep then
        return
    end

    local difficulty =
        rep:GetAttribute("Difficulty")

    local displayName =
        rep:GetAttribute("DifficultyDisplayName")

    if difficulty ~= nil then
        SavedState.Difficulty =
            tostring(difficulty)
    end

    if displayName ~= nil then
        SavedState.DisplayName =
            tostring(displayName)
    end

    if tostring(SavedState.DisplayName or ""):lower() == "hardcore" then
        SavedState.Mode = "hardcore"
    else
        SavedState.Mode = "survival"
    end
end

local function IsGameOver()
    local rep = GetRep()

    return rep
        and rep:GetAttribute("GameOver") == true
end

local function BackToLobby()
    if not IsInGame() then
        return true
    end

    local network =
        ReplicatedStorage:FindFirstChild("Network")

    local teleport =
        network
        and network:FindFirstChild("Teleport")

    local remote =
        teleport
        and teleport:FindFirstChild("RE:backToLobby")

    if not remote then
        return false
    end

    return pcall(function()
        remote:FireServer()
    end)
end

local function Rematch()
    if not IsInGame() then
        return false
    end

    local network =
        ReplicatedStorage:FindFirstChild("Network")

    local gameManager =
        network
        and network:FindFirstChild("GameManager")

    local remote =
        gameManager
        and gameManager:FindFirstChild("RE:Rematch")

    if not remote then
        return false
    end

    return pcall(function()
        remote:FireServer()
    end)
end

local function Matchmake()
    if not IsInGame() then
        return false
    end

    local rep = GetRep()

    if rep then
        CacheState(rep)
    end

    if not SavedState.Difficulty then
        return false
    end

    local remote =
        ReplicatedStorage:FindFirstChild("RemoteFunction")

    if not remote then
        return false
    end

    return pcall(function()
        remote:InvokeServer(
            "Multiplayer",
            "v2:start",
            {
                difficulty = SavedState.Difficulty,
                mode = SavedState.Mode,
                count = 1
            }
        )
    end)
end

local function StartGameOverRecovery(rep)
    if RecoveryRunning or not IsInGame() then
        return
    end

    RecoveryRunning = true
    CacheState(rep)

    task.spawn(function()
        task.wait(GAMEOVER_STEP_TIMEOUT)

        if not IsInGame() then
            RecoveryRunning = false
            SessionStartedAt = nil
            return
        end

        if not IsGameOver() then
            RecoveryRunning = false
            SessionStartedAt = os.clock()
            return
        end

        BackToLobby()

        task.wait(GAMEOVER_STEP_TIMEOUT)

        if not IsInGame() then
            RecoveryRunning = false
            SessionStartedAt = nil
            return
        end

        if not IsGameOver() then
            RecoveryRunning = false
            SessionStartedAt = os.clock()
            return
        end

        Rematch()

        task.wait(GAMEOVER_STEP_TIMEOUT)

        if not IsInGame() then
            RecoveryRunning = false
            SessionStartedAt = nil
            return
        end

        if not IsGameOver() then
            RecoveryRunning = false
            SessionStartedAt = os.clock()
            return
        end

        Matchmake()

        RecoveryRunning = false
        SessionStartedAt = os.clock()
    end)
end

local function Reconnect()
    if not LoaderActive or ReconnectCheckRunning then
        return
    end

    ReconnectCheckRunning = true

    task.spawn(function()
        task.wait(2)

        if LoaderActive then
            pcall(function()
                TeleportService:TeleportReconnect()
            end)
        end

        ReconnectCheckRunning = false
    end)
end

local ErrorConnection =
    GuiService.ErrorMessageChanged:Connect(function()
        local code = GuiService:GetErrorCode()

        if code and code ~= Enum.ConnectionError.OK then
            Reconnect()
        end
    end)

local PromptConnection

pcall(function()
    local promptOverlay =
        CoreGui
            :WaitForChild("RobloxPromptGui")
            :WaitForChild("promptOverlay")

    PromptConnection =
        promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                Reconnect()
            end
        end)
end)

local existingCode = GuiService:GetErrorCode()

if existingCode and existingCode ~= Enum.ConnectionError.OK then
    Reconnect()
end

local function IsLoading()
    local playerGui =
        LocalPlayer:FindFirstChild("PlayerGui")

    local loadingScreen =
        playerGui
        and playerGui:FindFirstChild("LoadingScreen")

    local content =
        loadingScreen
        and loadingScreen:FindFirstChild("content")

    return
        LocalPlayer:GetAttribute("Loading") == true
        or LocalPlayer:GetAttribute("Teleporting") == true
        or (content and content.Visible == true)
end

if game.PlaceId == LOBBY_PLACE_ID then
    local startedAt = os.clock()

    while IsLoading() do
        if game.PlaceId ~= LOBBY_PLACE_ID then
            break
        end

        if os.clock() - startedAt >= LOBBY_LOADING_TIMEOUT then
            pcall(function()
                TeleportService:Teleport(
                    LOBBY_PLACE_ID,
                    LocalPlayer
                )
            end)

            return
        end

        task.wait(1)
    end

elseif IsInGame() then
    local startedAt = os.clock()

    while IsLoading() do
        if not IsInGame() then
            break
        end

        if os.clock() - startedAt >= LOADING_TIMEOUT then
            Matchmake()
            return
        end

        task.wait(1)
    end
end

task.spawn(function()
    while true do
        task.wait(0.1)

        local rep = GetRep()

        if not rep then
            SessionStartedAt = nil
            LastRep = nil
            RecoveryRunning = false

            SavedState.Difficulty = nil
            SavedState.DisplayName = nil
            SavedState.Mode = "survival"

            continue
        end

        if rep ~= LastRep then
            LastRep = rep
            SessionStartedAt = os.clock()
        end

        CacheState(rep)

        local gameOver =
            rep:GetAttribute("GameOver") == true

        if gameOver then
            StartGameOverRecovery(rep)

        elseif not RecoveryRunning
            and SessionStartedAt
            and os.clock() - SessionStartedAt >= NO_GAMEOVER_TIMEOUT then

            RecoveryRunning = true

            Matchmake()

            SessionStartedAt = os.clock()
            RecoveryRunning = false
        end
    end
end)

-- ================= Discord Webhook Report =================
-- =================================================================
-- ระบบรายงานสถานะแบบ "เรียลไทม์" (เช็กทุก 3 วินาที, เปลี่ยนสถานะส่งทันที)
-- * ระบบนี้อ่านค่าจากตัวเกมแบบ read-only เท่านั้น ไม่มีการยิง remote ใด ๆ
-- =================================================================

local STATUS_COLORS = {
    Playing   = 0x2ECC71, -- เขียว
    GameOver  = 0xE74C3C, -- แดง
    Recovering= 0xF39C12, -- ส้ม
    Loading   = 0x3498DB, -- ฟ้า
    Lobby     = 0x95A5A6, -- เทา
}

local function GetStatus()
    local rep = GetRep()

    if not rep then
        if game.PlaceId == LOBBY_PLACE_ID then
            return "Lobby", "🏠 อยู่หน้า Lobby"
        end

        return "Lobby", "🏠 ตอนนี้รอที่ Lobby"
    end

    if rep:GetAttribute("GameOver") == true then
        return "GameOver", "💀 เกมจบ (รอระบบกู้คืนทำงาน)"
    end

    if RecoveryRunning then
        return "Recovering", "🔄 กำลังกู้คืน"
    end

    if IsLoading() then
        return "Loading", "⏳ กำลังโหลดเกม"
    end

    local difficulty = SavedState.DisplayName or SavedState.Difficulty

    return "Playing",
        "🎮 กำลังเล่น" .. (difficulty and (" (" .. tostring(difficulty) .. ")") or "")
end

-- ================= Supabase Live Website =================
-- รูปแบบที่เกม TDS ใช้: Coins / Gems เป็น IntValue ลูกโดยตรงของ LocalPlayer (ไม่มี leaderstats)
-- จึงสแกนลูกโดยตรงก่อน แล้วค่อยใช้ leaderstats และ attribute ของ GameStateReplicator สำรอง

local function DetectCurrency()
    local coins, gems, coinName, gemName = nil, nil, nil, nil

    local function Scan(name, value)
        local key = name:lower()

        if not gems
            and (key:find("gem", 1, true)
                or key:find("diamond", 1, true)
                or key:find("crystal", 1, true)) then

            gems = value
            gemName = name

        elseif not coins
            and (key:find("coin", 1, true)
                or key:find("gold", 1, true)
                or key:find("money", 1, true)
                or key:find("cash", 1, true)) then

            coins = value
            coinName = name
        end
    end

    -- (1) ลูกโดยตรงของ LocalPlayer (TDS: Coins/Gems/Cash IntValues อยู่ตรงนี้)
    --     ในด่านจะมีทั้ง Coins (เงินบัญชี) และ Cash (เงินในด่าน) — ชื่อตรง ๆ ต้องชนะ Cash
    local exactValues = {}
    for _, stat in ipairs(LocalPlayer:GetChildren()) do
        if stat:IsA("ValueBase")
            and typeof(stat.Value) == "number" then

            Scan(stat.Name, stat.Value)
            exactValues[stat.Name:lower()] = stat.Value
        end
    end

    -- (1b) exact name (Coins/Gems) มีความหมายชัดกว่า generic match (Cash) เสมอ
    coins = exactValues["coins"] or coins
    gems = exactValues["gems"] or gems

    -- (2) leaderstats (เกมทั่วไปมักใช้ folder นี้)
    if not coins or not gems then
        local leaderstats =
            LocalPlayer:FindFirstChild("leaderstats")

        if leaderstats then
            for _, stat in ipairs(leaderstats:GetChildren()) do
                if stat:IsA("ValueBase")
                    and typeof(stat.Value) == "number" then

                    Scan(stat.Name, stat.Value)
                end
            end
        end
    end

    -- (3) attributes ของ GameStateReplicator (สำรองสุดท้าย)
    if not coins or not gems then
        local rep = GetRep()

        if rep then
            for attrName, attrValue in pairs(rep:GetAttributes()) do
                if typeof(attrValue) == "number" then
                    Scan(attrName, attrValue)
                end
            end
        end
    end

    local labels = {
        coinLabel = coinName and ("🪙 " .. coinName) or "🪙 Coins",
        gemLabel = gemName and ("💎 " .. gemName) or "💎 Gems",
    }

    return coins, gems, labels
end

local function FormatNumber(value)
    local formatted = tostring(math.floor(value + 0.5))

    while true do
        local count
        formatted, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")

        if count == 0 then
            break
        end
    end

    return formatted
end

local function HttpJson(method, url, body, extraHeaders)
    local headers = { ["Content-Type"] = "application/json" }

    for key, value in pairs(extraHeaders or {}) do
        headers[key] = value
    end

    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = method,
            Headers = headers,
            Body = body,
        })
    end)

    if ok and res then
        return {
            StatusCode = res.StatusCode,
            Body = res.Body or "",
        }
    end

    local requestFn = http_request or request or (syn and syn.request)

    if requestFn then
        local ok2, res2 = pcall(requestFn, {
            Url = url,
            Method = method,
            Headers = headers,
            Body = body,
        })

        if ok2 and res2 then
            return {
                StatusCode = res2.StatusCode or res2.code or 200,
                Body = res2.Body or res2.body or "",
            }
        end
    end

    return nil
end

local function IsHttpSuccess(statusCode)
    return statusCode
        and statusCode >= 200
        and statusCode < 300
end

local function SendWebhookPayload(payload)
    local body = HttpService:JSONEncode(payload)

    -- ถ้าเคยส่งไปแล้ว: แก้ข้อความเดิม (embed เดิมจะถูกอัปเดตแบบ live dashboard)
    if WebhookMessageId then
        local res = HttpJson(
            "PATCH",
            WEBHOOK_URL .. "/messages/" .. WebhookMessageId,
            body
        )

        if IsHttpSuccess(res and res.StatusCode) then
            return true
        end

        WebhookMessageId = nil
    end

    -- ?wait=true เพื่อให้ตอบกลับ id ของข้อความกลับมา
    local res = HttpJson(WEBHOOK_URL .. "?wait=true", body)

    if res and IsHttpSuccess(res.StatusCode) then
        local ok, msg = pcall(function()
            return HttpService:JSONDecode(res.Body)
        end)

        if ok and msg and msg.id then
            WebhookMessageId = msg.id
        end

        return true
    end

    return false
end

local function TimeStamp()
    return os.date("%d/%m/%Y %H:%M:%S")
end

local function GetPlayerIntValue(name)
    local stat = LocalPlayer:FindFirstChild(name)

    if stat and stat:IsA("ValueBase") then
        local ok, value = pcall(function() return stat.Value end)

        if ok and typeof(value) == "number" then
            return math.floor(value)
        end
    end

    return nil
end

local function GetPlayerReplicator()
    local stateReplicators =
        ReplicatedStorage:FindFirstChild("StateReplicators")

    return stateReplicators
        and stateReplicators:FindFirstChild("PlayerReplicator")
end

local function GetEquippedTowers()
    -- (1) หลัก: ชุดจริงจาก UserTowerStore (store เดียวกับหน้าจัดชุดใน lobby)
    --     (PlayerReplicator.EquippedTowers เป็นค่าแมตช์เก่า/ค่าฝั่งอื่น — ไม่ตรงกับชุดผู้เล่น)
    local ok, slots = pcall(function()
        local stores = ReplicatedStorage.Client.Interfaces.Stores
        local userTowerStore = require(stores.Game.UserTowerStore)
        local state = userTowerStore.getState()

        local ordered = {}
        for slot, towerName in pairs(state.equipped) do
            if typeof(towerName) == "string" then
                table.insert(ordered, { slot = slot, name = towerName })
            end
        end
        table.sort(ordered, function(a, b) return a.slot < b.slot end)

        local names = {}
        for _, entry in ipairs(ordered) do
            table.insert(names, entry.name)
        end
        return names
    end)

    if ok and typeof(slots) == "table" then
        return HttpService:JSONEncode(slots)
    end

    -- (2) สำรอง: attribute ของ PlayerReplicator
    local playerReplicator = GetPlayerReplicator()

    if not playerReplicator then
        return nil
    end

    local raw = playerReplicator:GetAttribute("EquippedTowers")

    if raw ~= nil then
        -- TDS แปะ control char (\1 serialize marker) นำหน้าค่า — ตัดทิ้งให้เหลือ JSON ล้วน
        return (tostring(raw):gsub("%c", ""))
    end

    return nil
end

local function GetOwnedTowers()
    local ok, result = pcall(function()
        local stores = ReplicatedStorage.Client.Interfaces.Stores
        local userTowerStore = require(stores.Game.UserTowerStore)
        local state = userTowerStore.getState()
        local names = {}

        for name, data in pairs(state.inventory) do
            if typeof(name) == "string" and typeof(data) == "table" then
                table.insert(names, name .. (data.GoldenPerks and " ⭐" or ""))
            end
        end

        table.sort(names)
        return names
    end)

    if ok and typeof(result) == "table" then
        -- owner เกมใช้ client store เก็บ tower ที่ซื้อแล้ว — encode เป็น JSON array
        return HttpService:JSONEncode(result)
    end

    return nil
end

local function GetMissingTowers()
    -- (catalog ทั้งเกม = folder ลูกของ ReplicatedStorage.Content.Tower) เทียบกับ owned
    local ok, result = pcall(function()
        local towerRoot =
            ReplicatedStorage.Content
            and ReplicatedStorage.Content:FindFirstChild("Tower")

        if not towerRoot then
            return nil
        end

        local catalog = {}

        for _, child in ipairs(towerRoot:GetChildren()) do
            if child:IsA("Folder") then
                table.insert(catalog, child.Name)
            end
        end

        local stores = ReplicatedStorage.Client.Interfaces.Stores
        local userTowerStore = require(stores.Game.UserTowerStore)
        local ownedBase = {}

        for name in pairs(userTowerStore.getState().inventory) do
            if typeof(name) == "string" then
                ownedBase[name:lower()] = true
            end
        end

        local missing = {}

        for _, name in ipairs(catalog) do
            if not ownedBase[name:lower()] then
                table.insert(missing, name)
            end
        end

        table.sort(missing)
        return missing
    end)

    if ok and typeof(result) == "table" then
        return HttpService:JSONEncode(result)
    end

    return nil
end

local function SendSupabaseReport(statusKey, statusText, coins, gems, elapsed, level, wins, equippedTowers, ownedTowers, missingTowers)
    if SUPABASE_URL == "" or SUPABASE_ANON_KEY == "" then
        return
    end

    local body = HttpService:JSONEncode({
        id = tostring(LocalPlayer.UserId),
        display_name = LocalPlayer.DisplayName,
        username = LocalPlayer.Name,
        status = statusKey,
        status_text = statusText,
        difficulty = SavedState.DisplayName or SavedState.Difficulty,
        coins = coins,
        gems = gems,
        level = level,
        wins = wins,
        equipped_towers = equippedTowers,
        owned_towers = ownedTowers,
        missing_towers = missingTowers,
        place_id = game.PlaceId,
        job_id = game.JobId ~= "" and game.JobId or nil,
        session_seconds = math.floor(elapsed),
        updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })

    -- upsert: ถียังไม่มีแถว id นี้จะสร้างใหม่ / ถ้ามีแล้วจะแก้ของเดิม
    local res = HttpJson(
        "POST",
        SUPABASE_URL .. "/rest/v1/reports?on_conflict=id",
        body,
        {
            ["apikey"] = SUPABASE_ANON_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_ANON_KEY,
            ["Prefer"] = "resolution=merge-duplicates",
        }
    )

    if not IsHttpSuccess(res and res.StatusCode) then
        return
    end

    WebhookLastSentSupabase = true

    return true
end

local function SendStatusReport()
    if WEBHOOK_URL == "" and SUPABASE_URL == "" then
        return
    end

    local now = os.clock()
    local statusKey, statusText = GetStatus()
    local coins, gems, labels = DetectCurrency()

    local coinText = coins and FormatNumber(coins) or "- (ไม่พบในเกม)"
    local gemText = gems and FormatNumber(gems) or "- (ไม่พบในเกม)"

    local level = GetPlayerIntValue("Level")
    local wins = GetPlayerIntValue("Wins")
    local equippedTowers = GetEquippedTowers()
    local ownedTowers = GetOwnedTowers()
    local missingTowers = GetMissingTowers()

    local changeKey = table.concat({
        statusKey,
        tostring(coins),
        tostring(gems),
        tostring(level),
        tostring(wins),
        tostring(equippedTowers)
    }, "|")

    local changed = changeKey ~= WebhookLastKey

    if changed then
        if now - WebhookLastSentAt < WEBHOOK_EVENT_MIN_GAP then
            return
        end
    elseif now - WebhookLastSentAt < WEBHOOK_UPDATE_INTERVAL then
        return
    end

    if not WebhookNotified then
        print("[script.lua] Status report: enabled (Discord/Supabase)")
        WebhookNotified = true
    end

    local elapsed = now - WebhookStartClock
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = math.floor(elapsed % 60)
    local timeText = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    local jobIdText = game.JobId ~= ""

    -- (1) Discord webhook (ถ้าตั้งค่าไว้)
    if WEBHOOK_URL ~= "" then
        SendWebhookPayload({
            username = "Game Report",
            embeds = { {
                title = "📊 รายงานสถานะการเล่นเกม",
                color = STATUS_COLORS[statusKey] or STATUS_COLORS.Lobby,
                fields = {
                    { name = "👤 ชื่อ", value = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")", inline = true },
                    { name = "🆔 User ID", value = tostring(LocalPlayer.UserId), inline = true },
                    { name = "📊 สถานะ", value = statusText, inline = false },
                    { name = labels.coinLabel, value = coinText, inline = true },
                    { name = labels.gemLabel, value = gemText, inline = true },
                    { name = "⏱ เวลาเล่นรวม", value = timeText, inline = true },
                    { name = "🌐 เซิร์ฟเวอร์", value = tostring(game.PlaceId) .. (jobIdText and (" / " .. game.JobId) or ""), inline = false },
                },
                footer = { text = "อัปเดต: " .. TimeStamp() },
            } },
        })
    end

    -- (2) เว็บ Supabase (ถ้าตั้งค่าไว้)
    if SUPABASE_URL ~= "" and SUPABASE_ANON_KEY ~= "" then
        SendSupabaseReport(statusKey, statusText, coins, gems, elapsed, level, wins, equippedTowers, ownedTowers, missingTowers)
    end

    WebhookLastKey = changeKey
    WebhookLastSentAt = now
end

-- ตรวจสถานะทุก 3 วินาที:
--   * สถานะ/ตัวเลขเปลี่ยน → ส่งทันที (ไม่เร็วกว่า 10 วิ ต่อครั้ง กัน spam / rate limit)
--   * อย่างอื่นปกติ → ส่งตามรอบ WEBHOOK_UPDATE_INTERVAL
task.spawn(function()
    if WEBHOOK_URL == "" and SUPABASE_URL == "" then
        return
    end

    while true do
        pcall(SendStatusReport)

        task.wait(3)
    end
end)
-- ===========================================================

-- ================= one-time structure probe (สำหรับดีบัก, ลบได้เมื่อเสร็จ) =================
-- ขึ้นรอบแรก: รอให้เข้าเกม -> เก็บชื่อสถิติทุกที่ที่มี -> ส่งขึ้นแถว "debug" ใน Supabase
local PROBE_ENABLED = false -- ✅ ดีบักเสร็จแล้ว (จะไม่สร้าง/อัปเดตแถว DEBUG อีก)

task.spawn(function()
    if not PROBE_ENABLED or SUPABASE_URL == "" then
        return
    end

    -- รอสูงสุด ~30 วิ ให้ leaderstats/โครงสร้างเกมปรากฏ
    for _ = 1, 15 do
        if LocalPlayer:FindFirstChild("leaderstats") then
            break
        end

        task.wait(2)
    end

    local out = {}

    local function add(...)
        table.insert(out, table.concat({...}, " "))
    end

    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")

    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            local ok, value = pcall(function() return stat.Value end)
            add("LS:", stat.Name, stat.ClassName, "=", ok and tostring(value) or "?")
        end
    else
        add("LS:none")
    end

    for _, containerName in ipairs({"stats","Stats","stuffs","Currency","ServerStats","PlayerStats"}) do
        local container = LocalPlayer:FindFirstChild(containerName)

        if container then
            add("ALT:", containerName)

            for _, valueNode in ipairs(container:GetDescendants()) do
                if valueNode:IsA("ValueBase") then
                    local ok, value = pcall(function() return valueNode.Value end)
                    add("ALT-val:", valueNode.Name, "=", ok and tostring(value) or "?")
                end
            end
        end
    end

    local stateReplicators =
        ReplicatedStorage:FindFirstChild("StateReplicators")

    if stateReplicators then
        for _, child in ipairs(stateReplicators:GetChildren()) do
            for attrKey, attrValue in pairs(child:GetAttributes()) do
                add("SR-attr:", child.Name, attrKey, "=", tostring(attrValue), "(" .. typeof(attrValue) .. ")")
            end
        end
    end

    for attrName, attrValue in pairs(LocalPlayer:GetAttributes()) do
        add("PATTR:", attrName, "=", tostring(attrValue), "(" .. typeof(attrValue) .. ")")
    end

    local ok, err = pcall(function()
        HttpJson(
            "POST",
            SUPABASE_URL .. "/rest/v1/reports?on_conflict=id",
            HttpService:JSONEncode({
                id = "debug",
                display_name = "DEBUG",
                username = "probe",
                status = "Debug",
                status_text = "probe place " .. game.PlaceId
                    .. " player " .. LocalPlayer.Name
                    .. " || " .. table.concat(out, " || "),
                place_id = game.PlaceId,
                job_id = game.JobId ~= "" and game.JobId or nil,
                session_seconds = 0,
                updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }),
            {
                ["apikey"] = SUPABASE_ANON_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_ANON_KEY,
                ["Prefer"] = "resolution=merge-duplicates",
            }
        )
    end)

    if not ok then
        warn("[probe] upload failed: " .. tostring(err))
    else
        print("[probe] uploaded structure snapshot")
    end
end)
-- ===========================================================

local ok, err = pcall(function()
loadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/96aa3bb286648b1860f83b0d1dffc8b67b5091050f89341b6384c4450894193d/download"))()
end)

LoaderActive = false

if ErrorConnection then
    ErrorConnection:Disconnect()
end

if PromptConnection then
    PromptConnection:Disconnect()
end

ReconnectCheckRunning = false

if not ok then
    warn(err)
end
