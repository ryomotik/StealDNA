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
}

-- Функция отправки сообщений в Discord Webhook
local function sendDiscordWebhook(title, description, color, fields)
    if not Flags.WebhookURL or Flags.WebhookURL == "" then return end
    local req = getRequestFunc()
    if not req then return end

    local embed = {
        title = title,
        description = description,
        color = color or 5814783,
        fields = fields or {},
        footer = { text = "Steal DNA Hub • by ryomotik" },
        timestamp = DateTime.now():ToIsoDate()
    }

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

    if Flags.WebhookSteal then
        local speedVal = tostring(LocalPlayer:GetAttribute("Speed") or "0")
        local playerName = Flags.StreamerMode and "[Скрыто на демке]" or LocalPlayer.Name
        sendDiscordWebhook(
            "🧬 Успешная кража ДНК!",
            "Игрок успешно украл ДНК и ушел в безопасную зону.",
            65280,
            {
                { name = "Зверь", value = tostring(targetAnimalId), inline = true },
                { name = "Скорость", value = speedVal, inline = true },
                { name = "Игрок", value = playerName, inline = true }
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
                                if Flags.WebhookMutant then
                                    local mName = inc:GetAttribute("MutantName") or "Мутант"
                                    local pName = Flags.StreamerMode and "[Скрыто]" or LocalPlayer.Name
                                    sendDiscordWebhook(
                                        "🔬 Мутант созрел и собран!",
                                        "Забрали мутанта из инкубатора #" .. i,
                                        16753920,
                                        {
                                            { name = "Мутант", value = tostring(mName), inline = true },
                                            { name = "Слот", value = "#" .. i, inline = true },
                                            { name = "Игрок", value = pName, inline = true }
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
    Title = "🔔 Отправить тестовое сообщение",
    Desc = "Проверяет корректность вебхука и шлет тестовый эмбед в Discord",
    Callback = function()
        if not Flags.WebhookURL or Flags.WebhookURL == "" then
            WindUI:Notify({ Title = "Ошибка", Content = "Сначала вставьте URL вебхука!", Duration = 3 })
            return
        end
        local pName = Flags.StreamerMode and "[Скрыто на демке]" or LocalPlayer.Name
        sendDiscordWebhook(
            "🔔 Проверка связи с Discord!",
            "Вебхук успешно подключен и настроен в Steal DNA Hub!",
            3447003,
            {
                { name = "Статус", value = "Активен ✅", inline = true },
                { name = "Игрок", value = pName, inline = true },
                { name = "Автор хаба", value = "ryomotik", inline = true }
            }
        )
        WindUI:Notify({ Title = "Discord", Content = "Тестовое сообщение отправлено!", Duration = 3 })
    end
})

Tabs.Discord:Section({ Title = "Настройки оповещений" })

Tabs.Discord:Toggle({
    Title = "Оповещать при краже ДНК",
    Desc = "Шлет сообщение в Discord каждый раз при успешном сборе ДНК",
    Value = true,
    Callback = function(val)
        Flags.WebhookSteal = val
    end
})

Tabs.Discord:Toggle({
    Title = "Оповещать при выведении Мутанта",
    Desc = "Шлет сообщение в Discord при сборе готового мутанта",
    Value = true,
    Callback = function(val)
        Flags.WebhookMutant = val
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
