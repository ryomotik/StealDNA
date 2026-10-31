-- Steal DNA / Украсть ДНК — Ultimate Script Hub
-- Author: ryomotik
-- Built with WindUI

if _G.StealDNAScriptLoaded and _G.StealDNAScriptUnload then
    pcall(_G.StealDNAScriptUnload)
end
_G.StealDNAScriptLoaded = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
end)

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

-- Универсальная функция HTTP-запросов (поддержка всех экзекуторов)
local function getRequestFunc()
    return (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (syn and type(syn.request) == "function" and syn.request)
        or (http and type(http.request) == "function" and http.request)
end

-- Загрузка интерфейса WindUI
local WindUI
local reqFunc = getRequestFunc()

if reqFunc then
    local s, res = pcall(function()
        return reqFunc({
            Url = "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
            Method = "GET"
        })
    end)
    if s and res and res.Body then
        local fn = loadstring(res.Body)
        if fn then WindUI = fn() end
    end
end

if not WindUI then
    local s, body = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
    end)
    if s and body then
        local fn = loadstring(body)
        if fn then WindUI = fn() end
    end
end

if not WindUI then
    error("Failed to load WindUI library")
end

-- Создание окна хаба
local Window = WindUI:CreateWindow({
    Title = "Steal DNA Hub",
    Author = "by ryomotik",
    Folder = "StealDNA_Hub",
    Icon = "dna",
    Size = UDim2.fromOffset(600, 480),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    ToggleKey = Enum.KeyCode.RightControl,
    OpenButton = {
        Title = "Steal DNA",
        Icon = "dna",
        CornerRadius = UDim.new(0, 16),
        StrokeThickness = 2,
        Color = ColorSequence.new(Color3.fromRGB(0, 255, 170), Color3.fromRGB(0, 140, 255)),
        OnlyMobile = false,
        Enabled = true,
        Draggable = true,
    }
})

-- Вкладки
local Tabs = {
    Farm = Window:Tab({ Title = "Фарм и Кража", Icon = "flame" }),
    Base = Window:Tab({ Title = "База и Мутации", Icon = "home" }),
    Discord = Window:Tab({ Title = "Discord Webhook", Icon = "message-square" }),
    Teleports = Window:Tab({ Title = "Телепорты", Icon = "map-pin" }),
    ESP = Window:Tab({ Title = "ESP Животных", Icon = "eye" }),
    Player = Window:Tab({ Title = "Игрок и Демка", Icon = "user" }),
}

-- Таблица настроек и состояний
local Flags = {
    AutoTrain = false,
    FastClick = false,
    AutoUpgradeTreadmill = false,
    AutoSteal = false,
    SelectedAnimal = "Bear",
    AutoSafeEscape = true,
    StealDelay = 2,
    AutoFinishMutation = false,
    AutoUpgradePlot = false,
    AutoUpgradeMutator = false,
    ESPEnabled = false,
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    Noclip = false,
    StreamerMode = false,
    WebhookURL = "",
    WebhookSteal = true,
    WebhookMutant = true,
    WebhookPeriodic = false,
    PeriodicInterval = 10,
}

-- Статистика текущей игровой сессии
local SessionStats = {
    StartTime = os.time(),
    DnaStolen = 0,
    MutantsClaimed = 0,
    LastDnaAnimal = "Не было",
    LastMutant = "Не было",
}

-- Вспомогательные функции для форматирования и сбора данных
local function formatDuration(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    if h > 0 then
        return string.format("%dч %dм %dс", h, m, s)
    elseif m > 0 then
        return string.format("%dм %dс", m, s)
    else
        return string.format("%dс", s)
    end
end

local function getPlayerCash()
    local attr = LocalPlayer:GetAttribute("Cash") or LocalPlayer:GetAttribute("Money") or LocalPlayer:GetAttribute("Coins")
    if attr ~= nil then return tostring(attr) end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local c = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money") or ls:FindFirstChild("Coins")
        if c and c.Value ~= nil then return tostring(c.Value) end
    end
    return "N/A"
end

local function getPlayerSpeed()
    local sp = LocalPlayer:GetAttribute("Speed")
    if sp ~= nil then return tostring(sp) end
    if Character and Character:FindFirstChildOfClass("Humanoid") then
        return tostring(math.floor(Character.Humanoid.WalkSpeed))
    end
    return "0"
end

local function getPing()
    local ok, ping = pcall(function()
        local s = game:GetService("Stats")
        local item = s and s:FindFirstChild("Network") and s.Network:FindFirstChild("ServerStatsItem")
        local dp = item and item:FindFirstChild("Data Ping")
        return dp and dp:GetValueString()
    end)
    if ok and ping then
        return ping
    end
    return "N/A"
end

-- Функция отправки сообщений в Discord Webhook
local function sendDiscordWebhook(title, description, color, fields, thumbnail)
    if not Flags.WebhookURL or Flags.WebhookURL == "" then return end
    local req = getRequestFunc()
    if not req then return end

    local embed = {
        title = title,
        description = description,
        color = color or 5814783,
        fields = fields or {},
        footer = { 
            text = "Steal DNA Hub v2.1 • by ryomotik",
            icon_url = "https://i.imgur.com/83pA8y7.png"
        },
        timestamp = DateTime.now():ToIsoDate()
    }

    if thumbnail then
        embed.thumbnail = { url = thumbnail }
    end

    local payload = HttpService:JSONEncode({
        username = "Steal DNA Hub",
        avatar_url = "https://i.imgur.com/83pA8y7.png",
        embeds = { embed }
    })

    task.spawn(function()
        pcall(function()
            req({
                Url = Flags.WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        end)
    end)
end

-- Отправка расширенной сводки сессии в Discord
local function sendSessionReportWebhook()
    local pName = Flags.StreamerMode and "[Скрыто на демке]" or (LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")")
    local curSpeed = getPlayerSpeed()
    local curCash = getPlayerCash()
    local uptime = formatDuration(os.time() - SessionStats.StartTime)
    local ping = getPing()

    local botsSummary = string.format(
        "• Тренировка: %s\n• Супер-клик (5x): %s\n• Авто-кража: %s\n• Авто-мутатор: %s",
        Flags.AutoTrain and "ВКЛ ✅" or "ВЫКЛ ❌",
        Flags.FastClick and "ВКЛ ✅" or "ВЫКЛ ❌",
        Flags.AutoSteal and ("ВКЛ ✅ (" .. tostring(Flags.SelectedAnimal) .. ")") or "ВЫКЛ ❌",
        Flags.AutoFinishMutation and "ВКЛ ✅" or "ВЫКЛ ❌"
    )

    sendDiscordWebhook(
        "📈 Сводка сессии • Steal DNA Hub",
        "Подробный аналитический отчет об игровой сессии и текущем прогрессе фарминга.",
        43263,
        {
            { name = "👤 Игрок", value = pName, inline = true },
            { name = "⏱️ Время сессии", value = uptime, inline = true },
            { name = "🏡 Участок (Plot)", value = "Plot #" .. tostring(LocalPlayer:GetAttribute("Plot") or "?"), inline = true },

            { name = "🏃 Текущая скорость", value = curSpeed .. " ⚡", inline = true },
            { name = "💰 Баланс", value = "$" .. curCash .. " 💵", inline = true },
            { name = "📡 Пинг сервера", value = ping, inline = true },

            { name = "🧬 Украдено ДНК", value = tostring(SessionStats.DnaStolen) .. " шт.\n(Посл: " .. SessionStats.LastDnaAnimal .. ")", inline = true },
            { name = "🔬 Мутантов получено", value = tostring(SessionStats.MutantsClaimed) .. " шт.\n(Посл: " .. SessionStats.LastMutant .. ")", inline = true },
            { name = "🛡️ Режим демки", value = Flags.StreamerMode and "АКТИВЕН 🔒" or "ВЫКЛЮЧЕН 🔓", inline = true },

            { name = "⚙️ Состояние автоматизации", value = botsSummary, inline = false },
        },
        "https://i.imgur.com/83pA8y7.png"
    )
end

-- Хелперы игры
local function getMyPlot()
    local pIdx = LocalPlayer:GetAttribute("Plot")
    if not pIdx then return nil end
    local plots = workspace:FindFirstChild("Plots")
    return plots and plots:FindFirstChild(tostring(pIdx))
end

local function getMyPlotCFrame()
    local plot = getMyPlot()
    if not plot then return nil end
    local anchor = plot:FindFirstChild("OwnerAnchor")
    if anchor then
        return anchor.CFrame + Vector3.new(0, 4, 0)
    end
    local treadmill = plot:FindFirstChild("Treadmill")
    if treadmill and treadmill:FindFirstChild("Belt") then
        return treadmill.Belt.CFrame + Vector3.new(0, 4, 5)
    end
    return nil
end

-- ====================================================================
-- 1. ВКЛАДКА "ФАРМ И КРАЖА"
-- ====================================================================

Tabs.Farm:Section({ Title = "Беговая дорожка (Тренировка скорости)" })

Tabs.Farm:Toggle({
    Title = "Авто-тренировка на дорожке",
    Desc = "Автоматически встает на беговую дорожку и запускает бег",
    Value = false,
    Callback = function(val)
        Flags.AutoTrain = val
        if val then
            task.spawn(function()
                while Flags.AutoTrain do
                    if not LocalPlayer:GetAttribute("Training") then
                        local plot = getMyPlot()
                        local tm = plot and plot:FindFirstChild("Treadmill")
                        local belt = tm and tm:FindFirstChild("Belt")
                        if belt and HRP then
                            HRP.CFrame = belt.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.2)
                        end
                        Net.Fire("TrainStart")
                    end
                    task.wait(1)
                end
            end)
        else
            if LocalPlayer:GetAttribute("Training") then
                Net.Fire("TrainStop")
            end
        end
    end
})

Tabs.Farm:Toggle({
    Title = "Супер-клик буст (5x Combo)",
    Desc = "Максимально ускоряет прирост скорости на дорожке (спам TrainClick)",
    Value = false,
    Callback = function(val)
        Flags.FastClick = val
        if val then
            task.spawn(function()
                while Flags.FastClick do
                    if LocalPlayer:GetAttribute("Training") then
                        Net.Fire("TrainClick")
                        task.wait(0.07)
                    else
                        task.wait(0.3)
                    end
                end
            end)
        end
    end
})

Tabs.Farm:Toggle({
    Title = "Авто-прокачка дорожки ($)",
    Desc = "Автоматически покупает улучшение дорожки за заработанный кэш",
    Value = false,
    Callback = function(val)
        Flags.AutoUpgradeTreadmill = val
        if val then
            task.spawn(function()
                while Flags.AutoUpgradeTreadmill do
                    local plot = getMyPlot()
                    local sign = plot and plot:FindFirstChild("Signs") and plot.Signs:FindFirstChild("TreadmillUpgradeSign")
                    local btn = sign and sign:FindFirstChild("MoneyButton")
                    if btn then
                        Net.Fire("SignClick", btn)
                        local cd = btn:FindFirstChildOfClass("ClickDetector")
                        if cd and fireclickdetector then
                            fireclickdetector(cd)
                        end
                    end
                    Net.Fire("UpgradeTreadmill", "Cash")
                    task.wait(1.5)
                end
            end)
        end
    end
})

Tabs.Farm:Section({ Title = "Кража ДНК животных" })

local animalOptions = {}
for id, data in pairs(Config.Animals or {}) do
    table.insert(animalOptions, id)
end
table.sort(animalOptions, function(a, b)
    local sa = Config.Animals[a] and Config.Animals[a].Speed or 0
    local sb = Config.Animals[b] and Config.Animals[b].Speed or 0
    return sa < sb
end)

Tabs.Farm:Dropdown({
    Title = "Выберите животное для кражи",
    Desc = "Животные отсортированы по требуемой скорости",
    Values = animalOptions,
    Value = "Bear",
    Callback = function(selected)
        Flags.SelectedAnimal = selected
    end
})

local function stealDnaOnce(targetAnimalId)
    local animalsFolder = workspace:FindFirstChild("Animals")
    if not animalsFolder then
        WindUI:Notify({ Title = "Ошибка", Content = "Папка Animals не найдена!", Duration = 3 })
        return false
    end

    local targetModel = nil
    for _, animal in ipairs(animalsFolder:GetChildren()) do
        if animal:GetAttribute("AnimalId") == targetAnimalId and animal:GetAttribute("State") == "Sleep" then
            targetModel = animal
            break
        end
    end

    if not targetModel then
        WindUI:Notify({
            Title = "Животное не найдено",
            Content = targetAnimalId .. " сейчас бодрствует или не заспавнен!",
            Duration = 3
        })
        return false
    end

    local promptAt = targetModel:FindFirstChild("HumanoidRootPart") and targetModel.HumanoidRootPart:FindFirstChild("PromptAt")
    local stealPrompt = promptAt and promptAt:FindFirstChild("StealPrompt")

    if not stealPrompt then
        WindUI:Notify({ Title = "Ошибка", Content = "У животного нет StealPrompt!", Duration = 3 })
        return false
    end

    if LocalPlayer:GetAttribute("Training") then
        Net.Fire("TrainStop")
        task.wait(0.2)
    end

    if HRP and targetModel:FindFirstChild("HumanoidRootPart") then
        HRP.CFrame = targetModel.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        task.wait(0.2)
    end

    if fireproximityprompt then
        fireproximityprompt(stealPrompt)
    end

    task.wait(0.35)

    if Flags.AutoSafeEscape then
        local plotCF = getMyPlotCFrame()
        if plotCF and HRP then
            HRP.CFrame = plotCF
        elseif HRP then
            HRP.CFrame = CFrame.new(0, 5, 0)
        end
    end

    WindUI:Notify({
        Title = "ДНК украдено!",
        Content = "+1 ДНК " .. targetAnimalId .. " успешно получено!",
        Duration = 3
    })

    SessionStats.DnaStolen = SessionStats.DnaStolen + 1
    SessionStats.LastDnaAnimal = tostring(targetAnimalId)

    if Flags.WebhookSteal then
        local pName = Flags.StreamerMode and "[Скрыто на демке]" or (LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")")
        local curSpeed = tonumber(LocalPlayer:GetAttribute("Speed")) or tonumber(getPlayerSpeed()) or 0
        local reqSpeed = (Config.Animals and Config.Animals[targetAnimalId] and Config.Animals[targetAnimalId].Speed) or 0
        local diff = curSpeed - reqSpeed
        local diffStr = diff >= 0 and ("+" .. diff .. " запас ✅") or (diff .. " нехватка ⚠️")
        local curCash = getPlayerCash()
        local uptime = formatDuration(os.time() - SessionStats.StartTime)

        sendDiscordWebhook(
            "🧬 Успешная кража ДНК: " .. tostring(targetAnimalId),
            "Игрок успешно украл ДНК и ушел в безопасную зону за SafeLine!",
            65416,
            {
                { name = "🐾 Добыча", value = tostring(targetAnimalId), inline = true },
                { name = "⚡ Требуемая скорость", value = tostring(reqSpeed), inline = true },
                { name = "🏃 Скорость игрока", value = tostring(curSpeed) .. " (" .. diffStr .. ")", inline = true },

                { name = "💰 Баланс", value = "$" .. curCash, inline = true },
                { name = "🏡 База", value = "Plot #" .. tostring(LocalPlayer:GetAttribute("Plot") or "?"), inline = true },
                { name = "🛡️ Уход за SafeLine", value = Flags.AutoSafeEscape and "Мгновенный ✅" or "Ручной ⚠️", inline = true },

                { name = "📊 Всего за сессию", value = tostring(SessionStats.DnaStolen) .. " ДНК", inline = true },
                { name = "⏱️ Время в игре", value = uptime, inline = true },
                { name = "👤 Игрок", value = pName, inline = true },
            }
        )
    end

    return true
end

Tabs.Farm:Button({
    Title = "Украсть ДНК выбранного животного",
    Desc = "Мгновенно телепортирует к животному, ворует ДНК и возвращает за безопасную черту",
    Callback = function()
        stealDnaOnce(Flags.SelectedAnimal)
    end
})

Tabs.Farm:Toggle({
    Title = "Авто-кража ДНК (Цикл)",
    Desc = "Постоянно ворует ДНК выбранного животного по кулдауну",
    Value = false,
    Callback = function(val)
        Flags.AutoSteal = val
        if val then
            task.spawn(function()
                while Flags.AutoSteal do
                    stealDnaOnce(Flags.SelectedAnimal)
                    task.wait(Flags.StealDelay)
                end
            end)
        end
    end
})

Tabs.Farm:Slider({
    Title = "Задержка авто-кражи (сек)",
    Value = { Min = 1, Max = 10, Default = 2 },
    Step = 0.5,
    Callback = function(val)
        Flags.StealDelay = val
    end
})

Tabs.Farm:Toggle({
    Title = "Авто-уход за SafeLine при краже",
    Desc = "Мгновенно телепортирует на безопасную базу после кражи, исключая поимку",
    Value = true,
    Callback = function(val)
        Flags.AutoSafeEscape = val
    end
})

-- ====================================================================
-- 2. ВКЛАДКА "БАЗА И МУТАЦИИ"
-- ====================================================================

Tabs.Base:Section({ Title = "Инкубатор и Мутации" })

Tabs.Base:Toggle({
    Title = "Авто-сбор готовых мутантов",
    Desc = "Автоматически забирает созданных мутантов из инкубаторов базы",
    Value = false,
    Callback = function(val)
        Flags.AutoFinishMutation = val
        if val then
            task.spawn(function()
                while Flags.AutoFinishMutation do
                    local plot = getMyPlot()
                    local incs = plot and plot:FindFirstChild("Incubators")
                    if incs then
                        for i = 1, 5 do
                            local inc = incs:FindFirstChild("Incubator" .. i)
                            if inc and (inc:GetAttribute("Ready") == true or inc:GetAttribute("HasJob") == true) then
                                Net.Fire("FinishMutation", i)
                                local mName = inc:GetAttribute("MutantName") or "Мутант"
                                SessionStats.MutantsClaimed = SessionStats.MutantsClaimed + 1
                                SessionStats.LastMutant = tostring(mName)

                                if Flags.WebhookMutant then
                                    local pName = Flags.StreamerMode and "[Скрыто на демке]" or (LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")")
                                    local curCash = getPlayerCash()
                                    local curSpeed = getPlayerSpeed()
                                    local uptime = formatDuration(os.time() - SessionStats.StartTime)

                                    sendDiscordWebhook(
                                        "🔬 Мутант выведен и собран!",
                                        "Инкубатор завершил скрещивание, новый мутант добавлен на базу!",
                                        10181046,
                                        {
                                            { name = "🧬 Мутант", value = tostring(mName), inline = true },
                                            { name = "📦 Слот инкубатора", value = "Слот #" .. tostring(i), inline = true },
                                            { name = "🏆 Собрано мутантов", value = tostring(SessionStats.MutantsClaimed) .. " шт.", inline = true },

                                            { name = "💰 Баланс ($)", value = "$" .. curCash, inline = true },
                                            { name = "🏃 Текущая скорость", value = curSpeed .. " ⚡", inline = true },
                                            { name = "⏱️ Время сессии", value = uptime, inline = true },

                                            { name = "👤 Игрок", value = pName, inline = true },
                                            { name = "🏡 Участок", value = "Plot #" .. tostring(LocalPlayer:GetAttribute("Plot") or "?"), inline = true },
                                        }
                                    )
                                end
                            end
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end
})

Tabs.Base:Button({
    Title = "Забрать готовых мутантов (Claim All)",
    Desc = "Проверяет все 5 слотов инкубатора и завершает созревание",
    Callback = function()
        for i = 1, 5 do
            Net.Fire("FinishMutation", i)
        end
        WindUI:Notify({ Title = "Мутатор", Content = "Запрос на завершение мутаций отправлен!", Duration = 3 })
    end
})

Tabs.Base:Section({ Title = "Авто-улучшения Базы ($)" })

Tabs.Base:Toggle({
    Title = "Авто-прокачка участка (Plot Upgrade)",
    Desc = "Увеличивает вместимость базы и количество мест для мутантов",
    Value = false,
    Callback = function(val)
        Flags.AutoUpgradePlot = val
        if val then
            task.spawn(function()
                while Flags.AutoUpgradePlot do
                    local plot = getMyPlot()
                    local sign = plot and plot:FindFirstChild("Signs") and plot.Signs:FindFirstChild("PlotUpgradeSign")
                    local btn = sign and sign:FindFirstChild("MoneyButton")
                    if btn then
                        Net.Fire("SignClick", btn)
                        local cd = btn:FindFirstChildOfClass("ClickDetector")
                        if cd and fireclickdetector then
                            fireclickdetector(cd)
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end
})

Tabs.Base:Toggle({
    Title = "Авто-прокачка мутатора (Mutator Upgrade)",
    Desc = "Улучшает мутатор, сокращая время выведения мутантов",
    Value = false,
    Callback = function(val)
        Flags.AutoUpgradeMutator = val
        if val then
            task.spawn(function()
                while Flags.AutoUpgradeMutator do
                    local plot = getMyPlot()
                    local sign = plot and plot:FindFirstChild("Signs") and plot.Signs:FindFirstChild("MutatorSign1")
                    local btn = sign and sign:FindFirstChild("MoneyButton")
                    if btn then
                        Net.Fire("SignClick", btn)
                        local cd = btn:FindFirstChildOfClass("ClickDetector")
                        if cd and fireclickdetector then
                            fireclickdetector(cd)
                        end
                    end
                    task.wait(2)
                end
            end)
        end
    end
})

-- ====================================================================
-- 3. ВКЛАДКА "DISCORD WEBHOOK"
-- ====================================================================

Tabs.Discord:Section({ Title = "Подключение Discord Вебхука" })

Tabs.Discord:Input({
    Title = "Discord Webhook URL",
    Desc = "Вставьте ссылку на ваш вебхук в канале Discord",
    Default = Flags.WebhookURL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(val)
        Flags.WebhookURL = val
    end
})

Tabs.Discord:Button({
    Title = "🔔 Отправить тестовое сообщение (Инфо-тест)",
    Desc = "Проверяет корректность вебхука и высылает подробную карточку профиля",
    Callback = function()
        if not Flags.WebhookURL or Flags.WebhookURL == "" then
            WindUI:Notify({ Title = "Ошибка", Content = "Сначала вставьте URL вебхука!", Duration = 3 })
            return
        end
        local pName = Flags.StreamerMode and "[Скрыто на демке]" or (LocalPlayer.Name .. " (" .. LocalPlayer.DisplayName .. ")")
        local accAge = Flags.StreamerMode and "[Скрыто]" or (tostring(LocalPlayer.AccountAge) .. " дн.")
        local userId = Flags.StreamerMode and "[Скрыто]" or tostring(LocalPlayer.UserId)
        local curSpeed = getPlayerSpeed()
        local curCash = getPlayerCash()
        local uptime = formatDuration(os.time() - SessionStats.StartTime)
        local ping = getPing()

        sendDiscordWebhook(
            "🔔 Проверка связи • Steal DNA Hub",
            "Вебхук успешно подключен и настроен на передачу расширенной статистики!",
            5793266,
            {
                { name = "👤 Профиль игрока", value = pName, inline = true },
                { name = "🆔 User ID", value = userId, inline = true },
                { name = "📅 Возраст аккаунта", value = accAge, inline = true },

                { name = "🏃 Текущая скорость", value = curSpeed .. " ⚡", inline = true },
                { name = "💰 Баланс ($)", value = "$" .. curCash .. " 💵", inline = true },
                { name = "🏡 Участок (Plot)", value = "Plot #" .. tostring(LocalPlayer:GetAttribute("Plot") or "?"), inline = true },

                { name = "⏱️ Время сессии", value = uptime, inline = true },
                { name = "📡 Пинг сервера", value = ping, inline = true },
                { name = "🛡️ Режим демки", value = Flags.StreamerMode and "АКТИВЕН 🔒" or "ВЫКЛ 🔓", inline = true },

                { name = "👑 Автор хаба", value = "ryomotik", inline = true },
                { name = "📊 Украдено ДНК", value = tostring(SessionStats.DnaStolen) .. " шт.", inline = true },
                { name = "🔬 Мутантов получено", value = tostring(SessionStats.MutantsClaimed) .. " шт.", inline = true },
            }
        )
        WindUI:Notify({ Title = "Discord", Content = "Расширенный тестовый отчет отправлен!", Duration = 3 })
    end
})

Tabs.Discord:Section({ Title = "Настройки оповещений" })

Tabs.Discord:Toggle({
    Title = "Оповещать при краже ДНК",
    Desc = "Шлет подробный отчет (животное, скорость, баланс, статистика)",
    Value = true,
    Callback = function(val)
        Flags.WebhookSteal = val
    end
})

Tabs.Discord:Toggle({
    Title = "Оповещать при выведении Мутанта",
    Desc = "Шлет подробный отчет при завершении мутации в инкубаторе",
    Value = true,
    Callback = function(val)
        Flags.WebhookMutant = val
    end
})

Tabs.Discord:Section({ Title = "Периодические отчеты и Аналитика" })

Tabs.Discord:Button({
    Title = "📊 Отправить текущую сводку сессии",
    Desc = "Мгновенно отправляет полный отчет со всеми счетчиками и статусами в Discord",
    Callback = function()
        if not Flags.WebhookURL or Flags.WebhookURL == "" then
            WindUI:Notify({ Title = "Ошибка", Content = "Сначала вставьте URL вебхука!", Duration = 3 })
            return
        end
        sendSessionReportWebhook()
        WindUI:Notify({ Title = "Discord", Content = "Сводка сессии успешно отправлена!", Duration = 3 })
    end
})

Tabs.Discord:Toggle({
    Title = "Периодический авто-отчет",
    Desc = "Автоматически отправляет полную сводку сессии в Discord по таймеру",
    Value = false,
    Callback = function(val)
        Flags.WebhookPeriodic = val
        if val then
            task.spawn(function()
                while Flags.WebhookPeriodic do
                    task.wait(Flags.PeriodicInterval * 60)
                    if Flags.WebhookPeriodic and Flags.WebhookURL and Flags.WebhookURL ~= "" then
                        sendSessionReportWebhook()
                    end
                end
            end)
        end
    end
})

Tabs.Discord:Slider({
    Title = "Интервал авто-отчета (мин)",
    Value = { Min = 2, Max = 30, Default = 10 },
    Step = 1,
    Callback = function(val)
        Flags.PeriodicInterval = val
    end
})

-- ====================================================================
-- 4. ВКЛАДКА "ТЕЛЕПОРТЫ"
-- ====================================================================

Tabs.Teleports:Section({ Title = "База" })

Tabs.Teleports:Button({
    Title = "Телепорт на мою базу (My Plot)",
    Desc = "Мгновенно перемещает персонажа на ваш участок",
    Callback = function()
        local cf = getMyPlotCFrame()
        if cf and HRP then
            HRP.CFrame = cf
        else
            WindUI:Notify({ Title = "Телепорт", Content = "Участок не найден!", Duration = 3 })
        end
    end
})

Tabs.Teleports:Section({ Title = "Зоны и Биомы" })

local biomes = {
    { Name = "Лес (Forest)", Z = 100 },
    { Name = "Озеро (Lake)", Z = 350 },
    { Name = "Пустыня (Desert)", Z = 650 },
    { Name = "Джунгли (Jungle)", Z = 950 },
    { Name = "Снег (Snow)", Z = 1250 },
    { Name = "Вулкан (Volcano)", Z = 1700 },
    { Name = "Бездна (Abyss)", Z = 2100 },
    { Name = "Доисторический (Prehistoric)", Z = 2600 },
    { Name = "Смерть (Death)", Z = 3000 },
    { Name = "Радуга (Rainbow)", Z = 3500 },
}

local biomeNames = {}
for _, b in ipairs(biomes) do
    table.insert(biomeNames, b.Name)
end

local selectedBiome = biomes[1]

Tabs.Teleports:Dropdown({
    Title = "Выберите биом",
    Values = biomeNames,
    Value = biomeNames[1],
    Callback = function(sel)
        for _, b in ipairs(biomes) do
            if b.Name == sel then
                selectedBiome = b
                break
            end
        end
    end
})

Tabs.Teleports:Button({
    Title = "Телепортироваться в выбранный биом",
    Callback = function()
        if HRP and selectedBiome then
            HRP.CFrame = CFrame.new(0, 8, selectedBiome.Z)
            WindUI:Notify({ Title = "Телепорт", Content = "Вы в биоме: " .. selectedBiome.Name, Duration = 2 })
        end
    end
})

-- ====================================================================
-- 5. ВКЛАДКА "ESP ЖИВОТНЫХ"
-- ====================================================================

Tabs.ESP:Section({ Title = "Подсветка спящих животных" })

local espFolder = Instance.new("Folder")
espFolder.Name = "StealDNA_ESP"
espFolder.Parent = game:GetService("CoreGui")

local function clearESP()
    espFolder:ClearAllChildren()
end

Tabs.ESP:Toggle({
    Title = "Включить ESP животных",
    Desc = "Показывает имена, необходимую скорость и дистанцию до спящих животных",
    Value = false,
    Callback = function(val)
        Flags.ESPEnabled = val
        if not val then
            clearESP()
        end
    end
})

RunService.RenderStepped:Connect(function()
    if not Flags.ESPEnabled then return end
    clearESP()

    local animals = workspace:FindFirstChild("Animals")
    if not animals or not HRP then return end

    local mySpeed = LocalPlayer:GetAttribute("Speed") or 16

    for _, a in ipairs(animals:GetChildren()) do
        local aHrp = a:FindFirstChild("HumanoidRootPart")
        local state = a:GetAttribute("State")
        local reqSpeed = a:GetAttribute("Speed") or 0
        local aId = a:GetAttribute("AnimalId") or a.Name

        if aHrp and state == "Sleep" then
            local dist = (aHrp.Position - HRP.Position).Magnitude
            if dist < 800 then
                local canSteal = mySpeed >= reqSpeed

                local bg = Instance.new("BillboardGui")
                bg.Name = a.Name
                bg.Adornee = aHrp
                bg.Size = UDim2.new(0, 150, 0, 45)
                bg.StudsOffset = Vector3.new(0, 3.5, 0)
                bg.AlwaysOnTop = true
                bg.Parent = espFolder

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.GothamBold
                label.TextSize = 13
                label.TextStrokeTransparency = 0.2
                label.Text = string.format("%s\nReq: %d | [%dm]", aId, reqSpeed, math.floor(dist))
                label.TextColor3 = canSteal and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 80, 80)
                label.Parent = bg

                local hl = Instance.new("Highlight")
                hl.Adornee = a
                hl.FillColor = canSteal and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 60, 60)
                hl.FillTransparency = 0.7
                hl.OutlineColor = canSteal and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 30, 30)
                hl.OutlineTransparency = 0.2
                hl.Parent = espFolder
            end
        end
    end
end)

-- ====================================================================
-- 6. ВКЛАДКА "ИГРОК И ДЕМКА"
-- ====================================================================

Tabs.Player:Section({ Title = "🖥️ Режим для Демки (Discord Screen Share)" })

Tabs.Player:Toggle({
    Title = "Режим Стримера / Демка (Скрыть ник)",
    Desc = "Заменяет ваш ник над головой на 'Player', чтобы не спалить аккаунт на показе экрана",
    Value = false,
    Callback = function(val)
        Flags.StreamerMode = val
        if Character and Character:FindFirstChildOfClass("Humanoid") then
            Character.Humanoid.DisplayName = val and "Player" or LocalPlayer.DisplayName
        end
        WindUI:Notify({
            Title = "Режим Демки",
            Content = val and "Ник замаскирован под 'Player'!" or "Реальный ник возвращен.",
            Duration = 3
        })
    end
})

Tabs.Player:Button({
    Title = "Скрыть / Показать меню хаба",
    Desc = "Также можно нажимать горячую клавишу RightControl или Insert",
    Callback = function()
        Window:Toggle()
    end
})

Tabs.Player:Section({ Title = "Модификаторы персонажа" })

Tabs.Player:Slider({
    Title = "Скорость бега (WalkSpeed)",
    Value = { Min = 16, Max = 400, Default = 16 },
    Step = 2,
    Callback = function(val)
        Flags.WalkSpeed = val
        if Humanoid then
            Humanoid.WalkSpeed = val
        end
    end
})

Tabs.Player:Slider({
    Title = "Сила прыжка (JumpPower)",
    Value = { Min = 50, Max = 350, Default = 50 },
    Step = 5,
    Callback = function(val)
        Flags.JumpPower = val
        if Humanoid then
            Humanoid.JumpPower = val
        end
    end
})

Tabs.Player:Toggle({
    Title = "Бесконечный прыжок (Infinite Jump)",
    Value = false,
    Callback = function(val)
        Flags.InfJump = val
    end
})

UserInputService.JumpRequest:Connect(function()
    if Flags.InfJump and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

Tabs.Player:Toggle({
    Title = "Noclip (Проход сквозь препятствия)",
    Desc = "Позволяет ходить сквозь стены и игнорировать капканы",
    Value = false,
    Callback = function(val)
        Flags.Noclip = val
    end
})

RunService.Stepped:Connect(function()
    if Flags.Noclip and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- Горячая клавиша Insert для открытия/закрытия
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Insert then
        Window:Toggle()
    end
end)

Tabs.Player:Section({ Title = "Управление скриптом" })

_G.StealDNAScriptUnload = function()
    Flags.AutoTrain = false
    Flags.FastClick = false
    Flags.AutoUpgradeTreadmill = false
    Flags.AutoSteal = false
    Flags.AutoFinishMutation = false
    Flags.AutoUpgradePlot = false
    Flags.AutoUpgradeMutator = false
    Flags.ESPEnabled = false
    Flags.Noclip = false
    Flags.WebhookPeriodic = false
    if Character and Character:FindFirstChildOfClass("Humanoid") then
        Character.Humanoid.DisplayName = LocalPlayer.DisplayName
    end
    clearESP()
    espFolder:Destroy()
    Window:Destroy()
    _G.StealDNAScriptLoaded = nil
    _G.StealDNAScriptUnload = nil
end

Tabs.Player:Button({
    Title = "Выгрузить скрипт (Unload)",
    Callback = function()
        _G.StealDNAScriptUnload()
        WindUI:Notify({ Title = "Скрипт", Content = "Скрипт успешно выгружен!", Duration = 2 })
    end
})

WindUI:Notify({
    Title = "Steal DNA Hub",
    Content = "Скрипт успешно запущен! Автор: ryomotik",
    Duration = 4
})
