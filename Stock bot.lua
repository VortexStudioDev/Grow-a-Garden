--[[ 
    @author depso (depthso)
    @description Grow a Garden stock bot script
    https://www.roblox.com/games/126884695634066
    @brand VortexTeam™
]]

type table = {
    [any]: any
}

-- VortexTeam™ Konfigürasyonu
_G.Configuration = {
    --// Reporting
    ["Enabled"] = true,
    ["Webhook"] = "https://discord.com/api/webhooks.....", -- Webhook URL'nizi buraya yerleştirin
    ["Weather Reporting"] = true,
    
    --// User
    ["Anti-AFK"] = true,
    ["Auto-Reconnect"] = true,
    ["Rendering Enabled"] = false,

    --// Embeds (Renkler ve Düzenler)
    ["AlertLayouts"] = {
        ["Weather"] = {
            EmbedColor = Color3.fromRGB(42, 109, 255), -- VortexBlue
        },
        ["SeedsAndGears"] = {
            EmbedColor = Color3.fromRGB(56, 238, 23), -- VortexGreen
            Layout = {
                ["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
                ["ROOT/GearStock/Stocks"] = "GEAR STOCK"
            }
        },
        ["EventShop"] = {
            EmbedColor = Color3.fromRGB(212, 42, 255), -- VortexPurple
            Layout = {
                ["ROOT/EventShopStock/Stocks"] = "EVENT STOCK"
            }
        },
        ["Eggs"] = {
            EmbedColor = Color3.fromRGB(251, 255, 14), -- VortexYellow
            Layout = {
                ["ROOT/PetEggStock/Stocks"] = "EGG STOCK"
            }
        },
        ["CosmeticStock"] = {
            EmbedColor = Color3.fromRGB(255, 106, 42), -- VortexOrange
            Layout = {
                ["ROOT/CosmeticStock/ItemStocks"] = "COSMETIC ITEMS STOCK"
            }
        }
    }
}

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

--// Remotes
local DataStream = ReplicatedStorage.GameEvents.DataStream -- RemoteEvent 
local WeatherEventStarted = ReplicatedStorage.GameEvents.WeatherEventStarted -- RemoteEvent 

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

--// Konfigürasyon Değeri Alma
local function GetConfigValue(Key: string)
    return _G.Configuration[Key]
end

--// Rendering etkinleştirildi
local Rendering = GetConfigValue("Rendering Enabled")
RunService:Set3dRenderingEnabled(Rendering)

--// Script zaten çalışıyorsa tekrar başlatma
if _G.StockBot then return end 
_G.StockBot = true

--// Renkleri Hex'e dönüştürme
local function ConvertColor3(Color: Color3): number
    local Hex = Color:ToHex()
    return tonumber(Hex, 16)
end

--// Verileri al
local function GetDataPacket(Data, Target: string)
    for _, Packet in Data do
        local Name = Packet[1]
        local Content = Packet[2]

        if Name == Target then
            return Content
        end
    end

    return 
end

--// Layout alma
local function GetLayout(Type: string)
    local Layouts = GetConfigValue("AlertLayouts")
    return Layouts[Type]
end

--// Webhook gönderme
local function WebhookSend(Type: string, Fields: table)
    local Enabled = GetConfigValue("Enabled")
    local Webhook = GetConfigValue("Webhook")

    --// Raportlar aktif mi kontrol et
    if not Enabled then return end

    local Layout = GetLayout(Type)
    local Color = ConvertColor3(Layout.EmbedColor)

    --// Webhook veri
    local TimeStamp = DateTime.now():ToIsoDate()
    local Body = {
        embeds = {
            {
                color = Color,
                fields = Fields,
                footer = {
                    text = "Powered by VortexTeam™" -- Markayı belirtmek
                },
                timestamp = TimeStamp
            }
        }
    }

    local RequestData = {
        Url = Webhook,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(Body)
    }

    --// Webhook'a POST isteği gönder
    task.spawn(request, RequestData)
end

--// Stok bilgilerini string olarak oluşturma
local function MakeStockString(Stock: table): string
    local String = ""
    for Name, Data in Stock do 
        local Amount = Data.Stock
        local EggName = Data.EggName 

        Name = EggName or Name
        String ..= `{Name} **x{Amount}**\n`
    end

    return String
end

--// Paket işleme
local function ProcessPacket(Data, Type: string, Layout)
    local Fields = {}
    
    local FieldsLayout = Layout.Layout
    if not FieldsLayout then return end

    for Packet, Title in FieldsLayout do 
        local Stock = GetDataPacket(Data, Packet)
        if not Stock then return end

        local StockString = MakeStockString(Stock)
        local Field = {
            name = Title,
            value = StockString,
            inline = true
        }

        table.insert(Fields, Field)
    end

    WebhookSend(Type, Fields)
end

--// Verileri dinle
DataStream.OnClientEvent:Connect(function(Type: string, Profile: string, Data: table)
    if Type ~= "UpdateData" then return end
    if not Profile:find(LocalPlayer.Name) then return end

    local Layouts = GetConfigValue("AlertLayouts")
    for Name, Layout in Layouts do
        ProcessPacket(Data, Name, Layout)
    end
end)

--// Hava durumu raporları
WeatherEventStarted.OnClientEvent:Connect(function(Event: string, Length: number)
    --// Hava durumu raporları aktif mi kontrol et
    local WeatherReporting = GetConfigValue("Weather Reporting")
    if not WeatherReporting then return end

    --// Bitiş zamanını hesapla
    local ServerTime = math.round(workspace:GetServerTimeNow())
    local EndUnix = ServerTime + Length

    WebhookSend("Weather", {
        {
            name = "WEATHER",
            value = `{Event}\nEnds:<t:{EndUnix}:R>`,
            inline = true
        }
    })
end)

--// Anti-AFK
LocalPlayer.Idled:Connect(function()
    --// Anti-AFK aktif mi kontrol et
    local AntiAFK = GetConfigValue("Anti-AFK")
    if not AntiAFK then return end

    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

--// Auto-Reconnect
GuiService.ErrorMessageChanged:Connect(function()
    local IsSingle = #Players:GetPlayers() <= 1

    --// Auto-Reconnect aktif mi kontrol et
    local AutoReconnect = GetConfigValue("Auto-Reconnect")
    if not AutoReconnect then return end

    --// Teleport sonrası scripti tekrar çalıştır
    queue_on_teleport("https://raw.githubusercontent.com/VortexStudioDev/Grow-a-Garden/refs/heads/main/Stock%20bot.lua")

    --// Tek başına isen farklı bir sunucuya geç
    if IsSingle then
        TeleportService:Teleport(PlaceId, LocalPlayer)
        return
    end

    TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
end)
