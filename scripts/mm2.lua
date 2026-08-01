-- Vision Hub/main.lua
-- sexy script by github.com/orialdev
-- please give credit if you use anything from my code

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Modules = {}

local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-modded/releases/download/1.5.1/FluentPro"))()

local UserInputService_Init = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local IsMobile = UserInputService_Init.TouchEnabled and not UserInputService_Init.KeyboardEnabled

local queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or function(...) end

if getgenv().VisionHub_Connections then
    for i, conn in pairs(getgenv().VisionHub_Connections) do
        if conn then
            pcall(function() conn:Disconnect() end)
        end
        getgenv().VisionHub_Connections[i] = nil
    end
end
getgenv().VisionHub_Connections = {}

for _, gui in ipairs(CoreGui:GetChildren()) do
    if gui.Name == "Vision Hub" or gui.Name == "VisionESP" or string.match(gui.Name, "^VisionBtn_") or gui.Name == "VisionTimerGUI" then
        gui:Destroy()
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        local artifacts = {
            player.Character:FindFirstChild("VisionHighlight"),
            player.Character:FindFirstChild("Head") and player.Character.Head:FindFirstChild("NameESP")
        }
        for _, artifact in ipairs(artifacts) do
            if artifact then artifact:Destroy() end
        end
    end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj.Name == "VisionGunHighlight" or obj.Name == "VisionGunLabel" then
        obj:Destroy()
    end
end

if Modules and Modules.RootPart then 
    local v = Modules.RootPart:FindFirstChild("EpixVel") 
    if v then v:Destroy() end 
end

if getgenv().FPDH then
    Workspace.FallenPartsDestroyHeight = getgenv().FPDH
end

local function AddConnection(conn)
    local connections = getgenv().VisionHub_Connections
    for i = #connections, 1, -1 do
        local c = connections[i]
        if not c or not c.Connected then
            table.remove(connections, i)
        end
    end
    table.insert(connections, conn)
    return conn
end

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local Player = Players.LocalPlayer
local GetMouse = Player:GetMouse()
local PlayerGui = Player:FindFirstChildWhichIsA("PlayerGui")
local PlaceId, JobId = game.PlaceId, game.JobId

local writefile = writefile or nil
local readfile = readfile or nil
local firetouchinterest = firetouchinterest or nil

Modules.Player = Player
Modules.GetMouse = GetMouse
Modules.PlayerGui = PlayerGui
Modules.PlaceId = PlaceId
Modules.JobId = JobId
Modules.RunService = RunService
Modules.UserInputService = UserInputService
Modules.Lighting = Lighting
Modules.SoundService = SoundService
Modules.Workspace = Workspace
Modules.ReplicatedStorage = ReplicatedStorage
Modules.HttpService = HttpService
Modules.StarterGui = StarterGui
Modules.TextChatService = TextChatService

Modules.Config = {
    GodMode = false,
    AntiFling = false,
    AntiAfk = false,
    EnableWalkSpeed = false,
    WalkSpeed = 16,
    EnableJumpPower = false,
    JumpPower = 50,
    Noclip = false,
    InfiniteJump = false,
    AutoGrabGun = false,
    AutoKill = false,
    KnifeAura = false,
    AuraRadius = 10,
    EspPlayers = false,
    ShowNames = false,
    EspDroppedGun = false,
    EspTrap = false,
    RemoveTraps = false,
    SilentThrow = false,
    AutoShootMurderer = false,
    AutoQueue = true,
    QueueUrl = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/orialdev/Vision-Hub/refs/heads/main/main.lua"))()',
    NotifyMurderer = false,
    NotifySheriff = false,
    NotifyGunDropped = false,

    ButtonsLocked = false
}

Modules.PlayerData = {}
Modules.MobileButtons = {}

local function updateCharacterRefs(character)
    Modules.Character = character

    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
        if not hum then
            hum = character:WaitForChild("Humanoid", 5)
        end

        Modules.Humanoid = hum
        Modules.Backpack = Modules.Player:FindFirstChild("Backpack")
        Modules.RootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
        Modules.Camera = Workspace.CurrentCamera
    else
        Modules.Humanoid = nil
        Modules.RootPart = nil
    end
end

if Modules.Player then
    if Modules.Player.Character then
        updateCharacterRefs(Modules.Player.Character)
    end

    AddConnection(Modules.Player.CharacterAdded:Connect(function(character)
        updateCharacterRefs(character)
    end))

    AddConnection(Modules.Player.CharacterRemoving:Connect(function()
        updateCharacterRefs(nil)
    end))

    AddConnection(Players.PlayerRemoving:Connect(function(p)
        if p and p.Name and Modules.PlayerData[p.Name] then
            Modules.PlayerData[p.Name] = nil
        end
    end))
end

function Modules.GetService(name)
    local ok, s = pcall(function()
        return game:GetService(name)
    end)
    return ok and s or nil
end

do
    local antiFlingConn = nil
    
    function Modules.ToggleAntiFling(enable)
        Modules.Config.AntiFling = enable
        
        if antiFlingConn then
            antiFlingConn:Disconnect()
            antiFlingConn = nil
        end
        
        if enable then
            antiFlingConn = AddConnection(RunService.Stepped:Connect(function()
                if not Modules.Character then return end
                
                for _, otherPlayer in ipairs(Players:GetPlayers()) do
                    if otherPlayer ~= Modules.Player and otherPlayer.Character then
                        for _, part in ipairs(otherPlayer.Character:GetChildren()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                                if part.Name == "HumanoidRootPart" then
                                    part.Velocity = Vector3.new(0, 0, 0)
                                    part.RotVelocity = Vector3.new(0, 0, 0)
                                end
                            end
                        end
                    end
                end
            end))
        end
    end
end

function Modules.HandleQueueTeleport()
    if Modules.Config.AutoQueue and Modules.Config.QueueUrl and Modules.Config.QueueUrl ~= "" then
        if queue_on_teleport then
            queue_on_teleport(Modules.Config.QueueUrl)
        end
    end
end

function Modules.Rejoin()
    if not TeleportService then return end
    if not Modules.Player then return end

    Modules.HandleQueueTeleport()

    pcall(function()
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            game.JobId,
            Modules.Player
        )
    end)
end

function Modules.ServerHop()
    if not TeleportService or not Modules.Player then return end

    Modules.HandleQueueTeleport()

    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"

    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    server.id,
                    Modules.Player
                )
                return
            end
        end
    end

    TeleportService:Teleport(game.PlaceId, Modules.Player)
end

function getMap()
    for _, o in ipairs(workspace:GetChildren()) do
        if o:FindFirstChild("CoinContainer") and o:FindFirstChild("Spawns") then
            return o
        end
    end
    return nil
end

function Modules.TeleportToMap()
    local character = Modules.Character or (Modules.RootPart and Modules.RootPart.Parent)
    if not character then return end

    local map = getMap()
    if not map then return end

    local spawns = map:FindFirstChild("Spawns")
    if not spawns then return end

    local spawnList = {}
    for _, v in ipairs(spawns:GetChildren()) do
        if v:IsA("BasePart") then
            table.insert(spawnList, v)
        end
    end

    local spawn
    if #spawnList > 0 then
        spawn = spawnList[math.random(1, #spawnList)]
    end

    if not spawn then
        spawn = spawns:FindFirstChild("Spawn") or spawns:FindFirstChild("PlayerSpawn")
    end

    if spawn and spawn:IsA("BasePart") then
        character:PivotTo(spawn.CFrame * CFrame.new(0, 5, 0))
    else
        
    end
end

function getLobby()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("Lobby") then
            return obj.Lobby
        end
        if obj.Name:lower() == "lobby" then
            return obj
        end
    end
    return nil
end

function Modules.TeleportToLobby()
    local character = Modules.Character or (Modules.RootPart and Modules.RootPart.Parent)
    if not character then return end

    local lobby = getLobby()
    if not lobby then return end

    local spawns = lobby:FindFirstChild("Spawns")
    if not spawns then return end

    local spawnList = {}
    for _, v in ipairs(spawns:GetChildren()) do
        if v:IsA("BasePart") then
            table.insert(spawnList, v)
        end
    end

    local spawn
    if #spawnList > 0 then
        spawn = spawnList[math.random(1, #spawnList)]
    end

    if not spawn then
        spawn = spawns:FindFirstChild("SpawnLocation")
    end

    if spawn and spawn:IsA("BasePart") then
        character:PivotTo(spawn.CFrame * CFrame.new(0, 5, 0))
    end
end

function getCoinContainer()
    local map = getMap()
    if map then return map:FindFirstChild("CoinContainer") end
    return nil
end

function Modules.GetPlayerByName(name)
    if not name then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == name:lower() then
            return p
        end
    end
    return nil
end

function Modules.FindMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Knife") then
            return plr
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("Knife") then
            return plr
        end
    end

    if Modules.PlayerData then
        for playerName, data in pairs(Modules.PlayerData) do
            if data and (data.Role == "Murderer" or data.role == "Murderer") then
                local found = Players:FindFirstChild(playerName)
                if found then return found end
            end
        end
    end

    return nil
end

function Modules.FindSheriff()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Gun") then
            return plr
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild("Gun") then
            return plr
        end
    end

    if Modules.PlayerData then
        for playerName, data in pairs(Modules.PlayerData) do
            if data and (data.Role == "Sheriff" or data.role == "Sheriff") then
                local found = Players:FindFirstChild(playerName)
                if found then return found end
            end
        end
    end

    return nil
end

function Modules.FindSheriffThatsNotMe()
    local localplayer = Players.LocalPlayer

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localplayer and plr:FindFirstChild("Backpack") and plr.Backpack:FindFirstChild("Gun") then
            return plr
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localplayer and plr.Character and plr.Character:FindFirstChild("Gun") then
            return plr
        end
    end

    if Modules.PlayerData then
        for playerName, data in pairs(Modules.PlayerData) do
            if data and (data.Role == "Sheriff" or data.role == "Sheriff") then
                local found = Players:FindFirstChild(playerName)
                if found and found ~= localplayer then
                    return found
                end
            end
        end
    end

    return nil
end

do
    local success, remotes = pcall(function()
        return Modules.ReplicatedStorage and Modules.ReplicatedStorage:WaitForChild("Remotes", 5)
    end)

    if success and remotes then
        local gameplay = remotes:FindFirstChild("Gameplay") or remotes:FindFirstChild("Gameplay", true)
        if gameplay then
            local pdEvent = gameplay:FindFirstChild("PlayerDataChanged")
            if pdEvent and pdEvent:IsA("RemoteEvent") then
                AddConnection(pdEvent.OnClientEvent:Connect(function(data)
                    if type(data) == "table" then
                        Modules.PlayerData = data
                    end
                end))
            end
        end
    end

    local getPD = nil
    if Modules.ReplicatedStorage then
        getPD = Modules.ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    end

    if getPD and typeof(getPD.InvokeServer) == "function" then
        pcall(function()
            local ok, res = pcall(function() return getPD:InvokeServer() end)
            if ok and type(res) == "table" then
                Modules.PlayerData = res
            end
        end)
    end
end

local SkidFling = function(TargetPlayer)
    if not TargetPlayer or not TargetPlayer.Character then return end

    local Character = Player and Player.Character
    local Humanoid = Character and (Character:FindFirstChildOfClass("Humanoid") or Character:FindFirstChild("Humanoid"))
    local RootPart = Character and (Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart)

    local TCharacter = TargetPlayer and TargetPlayer.Character
    local THumanoid
    local TRootPart
    local THead
    local Accessory
    local Handle

    if TCharacter and TCharacter:FindFirstChildOfClass("Humanoid") then
        THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    end
    if THumanoid then
        TRootPart = TCharacter:FindFirstChild("HumanoidRootPart") or TCharacter.PrimaryPart or THumanoid.RootPart
    end
    if TCharacter and TCharacter:FindFirstChild("Head") then
        THead = TCharacter.Head
    end
    if TCharacter and TCharacter:FindFirstChildOfClass("Accessory") then
        Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    end
    if Accessory and Accessory:FindFirstChild("Handle") then
        Handle = Accessory.Handle
    end

    if Character and Humanoid and RootPart then
        if RootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = RootPart.CFrame
        end
        
        local CurrentCam = workspace.CurrentCamera
        if THead then
            CurrentCam.CameraSubject = THead
        elseif not THead and Handle then
            CurrentCam.CameraSubject = Handle
        elseif THumanoid and TRootPart then
            CurrentCam.CameraSubject = THumanoid
        end
        if not (TCharacter and TCharacter:FindFirstChildWhichIsA("BasePart")) then
            return
        end
        
        local FPos = function(BasePart, Pos, Ang)
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            pcall(function()
                if Character and Character.PrimaryPart then
                    Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
                end
            end)
            RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end
        
        local SFBasePart = function(BasePart)
            local TimeToWait = 2
            local Time = tick()
            local Angle = 0

            repeat
                if RootPart and THumanoid then
                    if BasePart.Velocity.Magnitude < 50 then
                        Angle = Angle + 100

                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                    else
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        
                        FPos(BasePart, CFrame.new(0, 1.5, TRootPart and TRootPart.Velocity.Magnitude / 1.25 or 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, -(TRootPart and TRootPart.Velocity.Magnitude / 1.25 or 0)), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, 1.5, TRootPart and TRootPart.Velocity.Magnitude / 1.25 or 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5 ,0), CFrame.Angles(math.rad(-90), 0, 0))
                        task.wait()

                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()
                    end
                else
                    break
                end
            until BasePart.Velocity.Magnitude > 500 or BasePart.Parent ~= TargetPlayer.Character or TargetPlayer.Parent ~= Players or TargetPlayer.Character ~= TCharacter or (THumanoid and THumanoid.Sit) or (Humanoid and Humanoid.Health <= 0) or tick() > Time + TimeToWait
        end
        
        if not getgenv().FPDH then
             getgenv().FPDH = workspace.FallenPartsDestroyHeight
        end

        workspace.FallenPartsDestroyHeight = 0/0
        
        local BV = Instance.new("BodyVelocity")
        BV.Name = "EpixVel"
        BV.Parent = RootPart
        BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
        BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)
        
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        
        if TRootPart and THead then
            if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
                SFBasePart(THead)
            else
                SFBasePart(TRootPart)
            end
        elseif TRootPart and not THead then
            SFBasePart(TRootPart)
        elseif not TRootPart and THead then
            SFBasePart(THead)
        elseif not TRootPart and not THead and Accessory and Handle then
            SFBasePart(Handle)
        end
        
        if BV and BV.Parent then BV:Destroy() end
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        workspace.CurrentCamera.CameraSubject = Humanoid
        
        repeat
            if getgenv().OldPos then
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                pcall(function()
                    if Character and Character.PrimaryPart then
                        Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
                    end
                end)
            end
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            for _, x in ipairs(Character:GetChildren()) do
                if x:IsA("BasePart") then
                    x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                end
            end
            task.wait()
        until not getgenv().OldPos or (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
        
        if getgenv().FPDH then
            workspace.FallenPartsDestroyHeight = getgenv().FPDH
        end
    end
end

function Modules.getPredictedPosition(player)
    if not player or not player.Character then return Vector3.new(0,0,0) end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart") or player.Character.PrimaryPart
    if not hrp then return Vector3.new(0,0,0) end

    local vel = hrp.AssemblyLinearVelocity or hrp.Velocity or Vector3.new(0,0,0)

    local ping = 0
    pcall(function()
        if Modules.Player and typeof(Modules.Player.GetNetworkPing) == "function" then
            ping = Modules.Player:GetNetworkPing() or 0
        end
    end)
    if type(ping) ~= "number" then ping = tonumber(ping) or 0 end
    if ping > 1 then ping = ping / 1000 end

    local offset = 2.8

    local leadTime = math.max(0, offset * 0.01) + ping

    return hrp.Position + vel * leadTime
end

function Modules.ShootMurdererOnce()
    local localplayer = Modules.Player
    if not localplayer or not localplayer.Character then return end
    if not (Modules.FindMurderer or Modules.FindSheriffThatsNotMe) then return end

    local target = Modules.FindMurderer() or Modules.FindSheriffThatsNotMe()
    if not target or not target.Character then return end
    local mHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local lHRP = localplayer.Character:FindFirstChild("HumanoidRootPart")
    if not mHRP or not lHRP then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { localplayer.Character }
    local direction = (mHRP.Position - lHRP.Position)
    local ok, res = pcall(function()
        return workspace:Raycast(lHRP.Position, direction, rayParams)
    end)

    local clearShot = false
    if not ok or not res then
        clearShot = true
    else
        if res.Instance and target.Character and res.Instance:IsDescendantOf(target.Character) then
            clearShot = true
        end
    end

    if not clearShot then return end

    if not localplayer.Character:FindFirstChild("Gun") then
        local tool = localplayer.Backpack and localplayer.Backpack:FindFirstChild("Gun")
        if tool and localplayer.Character:FindFirstChildOfClass("Humanoid") then
            pcall(function() localplayer.Character.Humanoid:EquipTool(tool) end)
        end
    end

    local gun = localplayer.Character and localplayer.Character:FindFirstChild("Gun")
    if not gun then return end

    local knifeLocal = gun:FindFirstChild("KnifeLocal")
    local createBeam = knifeLocal and knifeLocal:FindFirstChild("CreateBeam")
    local rf = createBeam and createBeam:FindFirstChild("RemoteFunction")
    if gun and knifeLocal and createBeam and rf and typeof(rf.InvokeServer) == "function" then
        local predPos = Modules.getPredictedPosition(target)
        pcall(function()
            rf:InvokeServer(1, predPos, "AH2")
        end)
    end
end

do
    local autoShootConn = nil
    function Modules.ToggleAutoShootMurderer(enable)
        Modules.Config.AutoShootMurderer = enable
        if autoShootConn then
            autoShootConn:Disconnect()
            autoShootConn = nil
        end

        if not enable then return end

        autoShootConn = AddConnection(Modules.RunService.Heartbeat:Connect(function()
            pcall(function()
                if Modules.Config.AutoShootMurderer and Modules.FindSheriff() == Modules.Player then
                    Modules.ShootMurdererOnce()
                end
            end)
        end))
    end
end

do
function Modules.TeleportToPlayer(targetPlayer)
    if not Modules.RootPart then
        return false
    end
    if not (targetPlayer and targetPlayer.Character and targetPlayer.Character.PrimaryPart) then
        return false
    end

    local ok = pcall(function()
        local targetCFrame = targetPlayer.Character.PrimaryPart.CFrame
        Modules.Character:SetPrimaryPartCFrame(targetCFrame * CFrame.new(0, 3, 0))
    end)

    return ok
end
end

do
    local _godConn = nil
    function Modules.EnableGodMode(enable)
        Modules.Config.GodMode = enable
        if _godConn then
            _godConn:Disconnect()
            _godConn = nil
        end
        if not enable then return end
        local function protectHumanoid(h)
            if not h then return end
            local healthConn 
            healthConn = h.HealthChanged:Connect(function(newHealth)
                if Modules.Config.GodMode and newHealth < h.MaxHealth then
                    h.Health = h.MaxHealth
                end
            end)
            task.spawn(function()
                while Modules.Config.GodMode and h and h.Parent do
                    if h.Health < h.MaxHealth then
                        h.Health = h.MaxHealth
                    end
                    if h:GetState() == Enum.HumanoidStateType.Dead then
                        h:ChangeState(Enum.HumanoidStateType.GettingUp)
                        h.Health = h.MaxHealth
                    end
                    task.wait(0.2)
                end
                if healthConn then healthConn:Disconnect() end
            end)
        end
        if Modules.Humanoid then
            protectHumanoid(Modules.Humanoid)
        end
        _godConn = AddConnection(Modules.Player.CharacterAdded:Connect(function(character)
            local hum = character:WaitForChild("Humanoid", 5)
            if hum then
                task.wait(0.5)
                protectHumanoid(hum)
            end
        end))
    end
end

do
local _speedConnection = nil
local _originalSpeed = 16
function Modules.EnableWalkSpeed(enable)
    Modules.Config.EnableWalkSpeed = enable
    if enable then
        if _speedConnection then _speedConnection:Disconnect() end
        _speedConnection = AddConnection(RunService.Heartbeat:Connect(function()
            if Modules.Humanoid and Modules.Humanoid.WalkSpeed ~= Modules.Config.WalkSpeed then
                Modules.Humanoid.WalkSpeed = Modules.Config.WalkSpeed
            end
        end))
    else
        if _speedConnection then
            _speedConnection:Disconnect()
            _speedConnection = nil
        end
        if Modules.Humanoid then
            Modules.Humanoid.WalkSpeed = _originalSpeed
        end
    end
end

function Modules.SetWalkSpeed(value)
    Modules.Config.WalkSpeed = math.clamp(value, 16, 200)
    if Modules.Config.EnableWalkSpeed and Modules.Humanoid then
        Modules.Humanoid.WalkSpeed = Modules.Config.WalkSpeed
    end
end
end

do
local _jumpConnection = nil
local _originalJumpPower = 50
function Modules.EnableJumpPower(enable)
    Modules.Config.EnableJumpPower = enable
    if enable then
        if _jumpConnection then _jumpConnection:Disconnect() end
        _jumpConnection = AddConnection(RunService.Heartbeat:Connect(function()
            if Modules.Humanoid and Modules.Humanoid.JumpPower ~= Modules.Config.JumpPower then
                Modules.Humanoid.JumpPower = Modules.Config.JumpPower
            end
        end))
    else
        if _jumpConnection then
            _jumpConnection:Disconnect()
            _jumpConnection = nil
        end
        if Modules.Humanoid then
            Modules.Humanoid.JumpPower = _originalJumpPower
        end
    end
end

function Modules.SetJumpPower(value)
    Modules.Config.JumpPower = math.clamp(value, 50, 300)
    if Modules.Config.EnableJumpPower and Modules.Humanoid then
        Modules.Humanoid.JumpPower = Modules.Config.JumpPower
    end
end
end

do
local _noclipConn = nil
local _savedCanCollide = {}
function Modules.EnableNoclip(enable)
    Modules.Config.Noclip = enable
    if enable then
        if Modules.Character then
            for _, part in ipairs(Modules.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    _savedCanCollide[part] = part.CanCollide
                    part.CanCollide = false
                end
            end
        end
        if _noclipConn then _noclipConn:Disconnect() end
        _noclipConn = AddConnection(RunService.Stepped:Connect(function()
            if not Modules.Character then return end
            for _, part in ipairs(Modules.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end))
    else
        if _noclipConn then
            _noclipConn:Disconnect()
            _noclipConn = nil
        end
        for part, state in pairs(_savedCanCollide) do
            if part and part.Parent then
                part.CanCollide = state
            end
        end
        _savedCanCollide = {}
    end
end
end

do
local _infJumpConn = nil
function Modules.InfiniteJump(enabled)
    Modules.Config.InfiniteJump = enabled
    if enabled then
        if _infJumpConn then _infJumpConn:Disconnect() end
        _infJumpConn = AddConnection(UserInputService.JumpRequest:Connect(function()
            if Modules.Humanoid then
                Modules.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end))
    else
        if _infJumpConn then
            _infJumpConn:Disconnect()
            _infJumpConn = nil
        end
    end
end
end

do
local grabGunConn = nil
function Modules.GrabGun()
    local root = Modules.RootPart
    if not root or not root.Parent then return end

    local map = getMap()
    if not map then return end

    local gunDrop = map:FindFirstChild("GunDrop")
    if gunDrop and gunDrop:IsA("BasePart") then
        pcall(function()
            firetouchinterest(gunDrop, root, 1)
            firetouchinterest(gunDrop, root, 0)
        end)
    end
end

function Modules.ToggleAutoGrabGun(enable)
    Modules.Config.AutoGrabGun = enable

    if grabGunConn then
        grabGunConn:Disconnect()
        grabGunConn = nil
    end

    if enable then
        grabGunConn = AddConnection(RunService.Heartbeat:Connect(Modules.GrabGun))
    end
end
end

do
function Modules.KillAll()
    if not Modules.Backpack or not Modules.Character or not Modules.Humanoid then return end
    
    local Knife = Modules.Backpack:FindFirstChild("Knife") or Modules.Character:FindFirstChild("Knife")
    local Humanoid = Modules.Humanoid

    if not Knife then return end

    if Knife.Parent == Modules.Backpack then
        Humanoid:EquipTool(Knife)
        task.wait(0.1)
        Knife = Modules.Character:FindFirstChild("Knife")
    end
    
    if not Knife then return end

    local Handle = Knife:FindFirstChild("Handle")
    local Stab = Knife:FindFirstChild("Stab")

    if Knife:IsA("Tool") then
        Knife.Parent = Modules.Character

        for _, v in ipairs(Players:GetPlayers()) do
            local EnemyRoot = v.Character and (v.Character:FindFirstChild("HumanoidRootPart") or v.Character.PrimaryPart)
            if v ~= Modules.Player and EnemyRoot and Handle then
                firetouchinterest(Handle, EnemyRoot, 1)
                firetouchinterest(Handle, EnemyRoot, 0)

                if Stab and typeof(Stab.FireServer) == "function" then
                    Stab:FireServer(EnemyRoot.Position)
                end
                task.wait(0.1)
            end
        end
    end
end
end

do
local autoKillConn = nil
function Modules.ToggleAutoKillAll(enable)
    Modules.Config.AutoKill = enable
    
    if autoKillConn then
        autoKillConn:Disconnect()
        autoKillConn = nil
    end
    
    if enable then
        autoKillConn = AddConnection(RunService.Heartbeat:Connect(function()
            if Modules.Config.AutoKill and Modules.Backpack and Modules.Character then
                local Knife = Modules.Backpack:FindFirstChild("Knife") or Modules.Character:FindFirstChild("Knife")
                if Knife and Knife:IsA("Tool") then
                    Modules.KillAll()
                end
            end
        end))
    end
end
end

do
local KillAuraConnection = nil
function Modules.KillAura(enabled)
    Modules.Config.KillAura = enabled
    if KillAuraConnection then
        KillAuraConnection:Disconnect()
        KillAuraConnection = nil
    end

    if not enabled then
        return
    end

    KillAuraConnection = AddConnection(RunService.Heartbeat:Connect(function()
        local Knife = Modules.Character and Modules.Character:FindFirstChild("Knife")

        if not Knife or not Knife:IsA("Tool") then
            return
        end

        local Handle = Knife:FindFirstChild("Handle")
        local Stab = Knife:FindFirstChild("Stab")
        local RootPart = Modules.RootPart
        local Character = Modules.Character

        if not Handle or not RootPart or not Character then
            return
        end

        if Knife.Parent ~= Character then
            return
        end

        local range = math.max(1, tonumber(Modules.Config.AuraRadius) or 10)

        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= Modules.Player and v.Character and v.Character:FindFirstChildOfClass("Humanoid") and v.Character.Humanoid.Health > 0 then
                local EnemyRoot = v.Character:FindFirstChild("HumanoidRootPart") or v.Character.PrimaryPart
                if EnemyRoot then
                    local dist = (EnemyRoot.Position - RootPart.Position).Magnitude
                    if dist <= range then
                        firetouchinterest(Handle, EnemyRoot, 1)
                        firetouchinterest(Handle, EnemyRoot, 0)

                        if Stab and typeof(Stab.FireServer) == "function" then
                            Stab:FireServer(EnemyRoot.Position)
                        end
                        break
                    end
                end
            end
        end
    end))
end
end

do
    Modules.Config.NotifyGunDropped = false

    local _notifyConn = nil
    local _lastNotified = nil

    local function notifyGun(gunPart)
        if not gunPart or not gunPart.Parent then return end
        if _lastNotified == gunPart then return end
        _lastNotified = gunPart

        pcall(function()
            if Fluent and typeof(Fluent.Notify) == "function" then
                Fluent:Notify({
                    Title = "Gun Dropped",
                    Content = "A gun has been dropped in the map.",
                    SubContent = "Vision Hub",
                    Duration = 5,
                })
            end
        end)
    end

    local function findExistingGun()
        local map = getMap()
        if not map then return nil end
        local g = map:FindFirstChild("GunDrop", true)
        if g and g:IsA("BasePart") then
            return g
        end
        return nil
    end

    function Modules.ToggleNotifyGunDropped(enable)
        Modules.Config.NotifyGunDropped = enable

        if _notifyConn then
            _notifyConn:Disconnect()
            _notifyConn = nil
        end

        _lastNotified = nil

        if not enable then return end

        pcall(function()
            local existing = findExistingGun()
            if existing then
                notifyGun(existing)
            end
        end)

        _notifyConn = AddConnection(Workspace.DescendantAdded:Connect(function(desc)
            if not Modules.Config.NotifyGunDropped then return end
            if not desc or not desc.Parent then return end
            if desc.Name == "GunDrop" and desc:IsA("BasePart") then
                notifyGun(desc)
            end
        end))

        task.spawn(function()
            while Modules.Config.NotifyGunDropped do
                pcall(function()
                    if _lastNotified and (not _lastNotified.Parent) then
                        _lastNotified = nil
                    end
                end)
                task.wait(1)
            end
        end)
    end
end

do
    function Modules.PlayEmote(emoteName)
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("PlayEmote") then
            remotes.PlayEmote:Fire(emoteName)
        elseif ReplicatedStorage:FindFirstChild("PlayEmote", true) then
            ReplicatedStorage:FindFirstChild("PlayEmote", true):Fire(emoteName)
        end
    end
end

do
    local silentThrowConn = nil
    
    function Modules.ExecuteThrowAtNearest()
        local knife = Modules.Backpack:FindFirstChild("Knife") or (Modules.Character and Modules.Character:FindFirstChild("Knife"))
        
        if knife and knife.Parent == Modules.Backpack and Modules.Humanoid then
            Modules.Humanoid:EquipTool(knife)
            task.wait(0.1)
            knife = Modules.Character:FindFirstChild("Knife")
        end
        
        if not knife or not knife:FindFirstChild("Throw") then return end
        
        local myPos = Modules.RootPart.Position
        local target = nil
        local dist = 1000
        
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= Modules.Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                local h = v.Character:FindFirstChild("Humanoid")
                if h and h.Health > 0 then
                    local root = v.Character.HumanoidRootPart
                    local mag = (myPos - root.Position).Magnitude
                    if mag < dist then
                        dist = mag
                        target = root
                    end
                end
            end
        end
        
        if target then
            local prediction = target.Position + (target.AssemblyLinearVelocity * 0.05 * (dist / 100))
            local throwCFrame = CFrame.new(myPos, prediction)
            knife.Throw:FireServer(throwCFrame, prediction)
        end
    end
    
    function Modules.ToggleSilentThrow(enable)
        Modules.Config.SilentThrow = enable
        
        if silentThrowConn then
            task.cancel(silentThrowConn)
            silentThrowConn = nil
        end
        
        if enable then
            silentThrowConn = task.spawn(function()
                while Modules.Config.SilentThrow do
                    local isMurderer = Modules.FindMurderer() == Modules.Player
                    if isMurderer then
                        Modules.ExecuteThrowAtNearest()
                    end
                    task.wait(0.8)
                end
            end)
        end
    end
end

function Modules.ChatRoles()
    local murderer = Modules.FindMurderer()
    local sheriff = Modules.FindSheriff()
    
    local mName = murderer and murderer.Name or "Unknown"
    local sName = sheriff and sheriff.Name or "Unknown"
    
    local msg = "Vision Hub >> Murderer: " .. mName .. " | Sheriff: " .. sName
    
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local chan = TextChatService:FindFirstChild("TextChannels")
        if chan and chan:FindFirstChild("RBXGeneral") then
            chan.RBXGeneral:SendAsync(msg)
        end
    else
        local es = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if es and es:FindFirstChild("SayMessageRequest") then
            es.SayMessageRequest:FireServer(msg, "Normal")
        end
    end
end

do
    local timerConn = nil
    local timerGui = nil

    local function secondsToMinutes(seconds)
        if not seconds or seconds == -1 then
            return ""
        end
        local minutes = math.floor(seconds / 60)
        local remainingSeconds = seconds % 60
        return string.format("%dm %ds", minutes, remainingSeconds)
    end

    function Modules.ToggleRoundTimer(enable)
        Modules.Config.RoundTimer = enable

        if timerGui then
            timerGui:Destroy()
            timerGui = nil
        end

        if timerConn then
            pcall(task.cancel, timerConn)
            timerConn = nil
        end

        if not enable then
            return
        end

        timerGui = Instance.new("ScreenGui")
        timerGui.Name = "VisionTimerGUI"
        timerGui.ResetOnSpawn = false
        timerGui.IgnoreGuiInset = true
        timerGui.Parent = CoreGui

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromOffset(200, 50)
        label.Position = UDim2.fromScale(0.5, 0.15)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        label.TextColor3 = Color3.fromHex("#E6F7FF")
        label.TextStrokeColor3 = Color3.fromHex("#000000")
        label.TextStrokeTransparency = 0
        label.Text = "Loading..."
        label.Parent = timerGui

        timerConn = task.spawn(function()
            while timerGui and timerGui.Parent do
                local ok, timeLeft = pcall(function()
                    return game.ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer()
                end)

                if ok then
                    label.Text = secondsToMinutes(timeLeft)
                else
                    label.Text = "—"
                end

                task.wait(0.5)
            end
        end)
    end
end

do
    local roleMonitorTask = nil
    local notifiedMurd = false
    local notifiedSher = false

    local function loopRoleMonitor()
        while true do
            local ok, seconds = pcall(function()
                return game.ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer()
            end)
            
            if not ok or (type(seconds) == "number" and seconds <= 1) then
                 notifiedMurd = false
                 notifiedSher = false
            elseif ok and type(seconds) == "number" and seconds > 1 then
                if Modules.Config.NotifyMurderer and not notifiedMurd then
                    local p = Modules.FindMurderer()
                    if p then
                         notifiedMurd = true
                         pcall(function()
                             Fluent:Notify({
                                Title = "Murderer Detected!",
                                Content = p.Name,
                                SubContent = "Vision Hub",
                                Duration = 8,
                             })
                         end)
                    end
                end
                
                if Modules.Config.NotifySheriff and not notifiedSher then
                    local p = Modules.FindSheriff()
                    if p then
                         notifiedSher = true
                         pcall(function()
                             Fluent:Notify({
                                Title = "Sheriff Detected!",
                                Content = p.Name,
                                SubContent = "Vision Hub",
                                Duration = 8,
                             })
                         end)
                    end
                end
            end
            task.wait(1)
        end
    end

    function Modules.UpdateRoleNotify()
         if roleMonitorTask then task.cancel(roleMonitorTask) roleMonitorTask = nil end
         if Modules.Config.NotifyMurderer or Modules.Config.NotifySheriff then
             roleMonitorTask = task.spawn(loopRoleMonitor)
         end
    end
end

do
    function Modules.CreateGuiButton(id, settings, callback)
        if Modules.MobileButtons[id] then
            if Modules.MobileButtons[id].Parent then Modules.MobileButtons[id]:Destroy() end
            Modules.MobileButtons[id] = nil
        end

        if not settings.Enabled then return end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "VisionBtn_" .. id
        screenGui.Parent = CoreGui
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        Modules.MobileButtons[id] = screenGui

        local buttonCount = 0
        for _, gui in pairs(Modules.MobileButtons) do
            if gui and gui.Parent then buttonCount = buttonCount + 1 end
        end

        local btn = nil
        if settings.Type == "Text" then
            btn = Instance.new("TextButton")
            btn.Text = settings.Text or id
            btn.TextColor3 = settings.TextColor or Color3.new(1,1,1)
            btn.TextScaled = true
            btn.Font = Enum.Font.GothamBold
        else
            btn = Instance.new("ImageButton")
            btn.Image = settings.Icon or ""
            btn.ImageColor3 = settings.ImageColor or Color3.fromHex("#E6F7FF")
        end

        btn.Name = "ActionBtn"
        btn.Size = UDim2.fromOffset(60, 60)
        local initialY = 0.45 + (buttonCount * 0.08) 
        if initialY > 0.8 then initialY = 0.45 end
        btn.Position = UDim2.new(0.9, -20, initialY, 0)
        
        btn.BackgroundColor3 = Color3.fromHex("#09202B")
        btn.BackgroundTransparency = 0.3
        btn.AutoButtonColor = true
        btn.Parent = screenGui

        local uiCorner = Instance.new("UICorner")
        uiCorner.CornerRadius = UDim.new(1, 0)
        uiCorner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromHex("#00BFFF")
        stroke.Thickness = 2.5
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btn

        local dragging = false
        local dragStart
        local startPos
        local hasMoved = false

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                hasMoved = false
                dragStart = input.Position
                startPos = btn.Position
            end
        end)

        btn.InputChanged:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
                if Modules.Config.ButtonsLocked then return end

                local delta = input.Position - dragStart
                if delta.Magnitude > 3 then 
                    hasMoved = true 
                end

                local viewportSize = workspace.CurrentCamera.ViewportSize
                local startX = startPos.X.Scale * viewportSize.X + startPos.X.Offset
                local startY = startPos.Y.Scale * viewportSize.Y + startPos.Y.Offset
                
                btn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)

        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                
                if not hasMoved or Modules.Config.ButtonsLocked then
                    if callback then
                        local originalColor = stroke.Color
                        stroke.Color = Color3.new(1,1,1)
                        task.spawn(callback)
                        task.delay(0.15, function()
                             if stroke and stroke.Parent then stroke.Color = originalColor end
                        end)
                    end
                end
            end
        end)
    end
end

--// Fluent UI (Fluent-modded) //--

Fluent:RegisterCustomTheme("Dark", {
    Accent = Color3.fromRGB(255, 255, 255),

    AcrylicMain = Color3.fromRGB(0, 0, 0),
    AcrylicBorder = Color3.fromRGB(20, 20, 20),
    AcrylicGradient = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 0)),
    AcrylicNoise = 1,

    TitleBarLine = Color3.fromRGB(22, 22, 22),
    Tab = Color3.fromRGB(28, 28, 28),

    Element = Color3.fromRGB(10, 10, 10),
    ElementBorder = Color3.fromRGB(0, 0, 0),
    InElementBorder = Color3.fromRGB(30, 30, 30),
    ElementTransparency = 0,

    ToggleSlider = Color3.fromRGB(30, 30, 30),
    ToggleToggled = Color3.fromRGB(255, 255, 255),

    SliderRail = Color3.fromRGB(30, 30, 30),

    DropdownFrame = Color3.fromRGB(18, 18, 18),
    DropdownHolder = Color3.fromRGB(0, 0, 0),
    DropdownBorder = Color3.fromRGB(0, 0, 0),
    DropdownOption = Color3.fromRGB(22, 22, 22),

    Keybind = Color3.fromRGB(22, 22, 22),

    Input = Color3.fromRGB(12, 12, 12),
    InputFocused = Color3.fromRGB(0, 0, 0),
    InputIndicator = Color3.fromRGB(45, 45, 45),
    InputIndicatorFocus = Color3.fromRGB(255, 255, 255),

    Dialog = Color3.fromRGB(0, 0, 0),
    DialogHolder = Color3.fromRGB(0, 0, 0),
    DialogHolderLine = Color3.fromRGB(18, 18, 18),
    DialogButton = Color3.fromRGB(10, 10, 10),
    DialogButtonBorder = Color3.fromRGB(28, 28, 28),
    DialogBorder = Color3.fromRGB(22, 22, 22),
    DialogInput = Color3.fromRGB(10, 10, 10),
    DialogInputLine = Color3.fromRGB(45, 45, 45),

    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(150, 150, 150),
    Hover = Color3.fromRGB(22, 22, 22),
    HoverChange = 0.03,

    ShineEnabled = false,
    Shine = {
        Speed = 0,
        RotationSpeed = 0,
        ColorSequence = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 0)),
    },
    StrokeShine = false,
    StrokeDark = Color3.fromRGB(18, 18, 18),

    ButtonGradient = {
        Background = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 10)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        }),
        Stroke = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 30)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 60, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30)),
        }),
    },

    Background = "rbxassetid://89833510731367",
    BackgroundTransparency = 0,
    ThemeAccentColors = { Color3.fromRGB(255, 255, 255) },
})

Fluent:SetTheme("Dark")

local Window = Fluent:CreateWindow({
    Title = "W-Azeox [Freeminu]",
    SubTitle = "By @z._h. In Discord",
    TabWidth = IsMobile and 130 or 160,
    Size = IsMobile and UDim2.fromOffset(480, 490) or UDim2.fromOffset(580, 440),
    Acrylic = false,
    Theme = "Dark",
    Search = true,
    MinimizeKey = Enum.KeyCode.LeftControl,

    UserInfoTop = true,
    UserInfoTitle = "https://zeox.xyz/",
    UserInfoSubtitle = LocalPlayer.DisplayName,
    UserInfoColor = Color3.fromRGB(255, 255, 255),
})

local Tabs = {
    Main = Window:AddTab({ Title = "Home", Icon = "lucide/house" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "lucide/footprints" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "lucide/swords" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "lucide/eye" }),
    Buttons = Window:AddTab({ Title = "Buttons", Icon = "lucide/square-mouse-pointer" }),
    Teleports = Window:AddTab({ Title = "Teleports", Icon = "lucide/map-pin" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "lucide/box" }),
    Farming = Window:AddTab({ Title = "Farming", Icon = "lucide/dollar-sign" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "lucide/settings" }),
}

local Main = Tabs.Main
local Movement = Tabs.Movement
local Combat = Tabs.Combat
local Visuals = Tabs.Visuals
local Buttons = Tabs.Buttons
local Teleports = Tabs.Teleports
local Misc = Tabs.Misc
local Farming = Tabs.Farming
local Settings = Tabs.Settings

do
    local HomeSection = Main:AddSection("Vision Hub", "lucide/house")

    HomeSection:AddParagraph({
        Title = "Welcome to Vision Hub!",
        Content = "Thanks for using Vision Hub, join our Discord for support and updates.",
    })

    HomeSection:AddButton({
        Title = "Join Discord",
        Description = "Copies the Discord invite to your clipboard",
        Icon = "lucide/message-circle",
        Callback = function()
            if setclipboard then
                setclipboard("https://discord.gg/TZHgrMUKGJ")
                Window:Dialog({
                    Title = "Discord Link Copied",
                    Content = "The Discord invite link has been copied to your clipboard.",
                    Buttons = {
                        { Title = "OK" }
                    }
                })
            end
        end
    })

    HomeSection:AddSpace({ Height = 6 })

    local ChangelogSection = Main:AddSection("Changelog 1.8.0", "lucide/file-text")

    ChangelogSection:AddParagraph({
        Title = "Changelog 1.8.0",
        Content = [[
+ 1.8.0 released!
+ Fully rewritten codebase
+ Fixed several bugs and stability issues
+ UI reorganized with buttons for all features
+ Added Save/Load Config
+ Added Auto Knife Throw
+ Added Throw Knife
- Removed Fly
+ Reworked and optimized ESP Players
+ Reworked Grab Gun and Auto Grab Gun
+ Reworked and optimized God Mode
+ Reworked and optimized Anti-Fling
+ Reworked and optimized Noclip
+ Reworked Knife Aura
+ Reworked and optimized Kill All and Auto Kill All
+ Optimized Auto Shoot Murderer
+ Optimized Fling
+ Complete ESP redesign
+ UI migrated to Fluent
+ More features coming soon]]
    })

    ChangelogSection:AddParagraph({
        Title = "Did you find any error?",
        Content = "-- For any bugs or errors, contact us on Discord. --",
    })
end

do
    local CharacterSection = Movement:AddSection("Movement", "lucide/footprints")

    CharacterSection:AddToggle("EnableWalkspeedToggle", {
        Title = "Enable WalkSpeed",
        Description = "Allow custom WalkSpeed",
        Default = false,
        Callback = Modules.EnableWalkSpeed
    })

    CharacterSection:AddSlider("WalkspeedSlider", {
        Title = "WalkSpeed",
        Description = "Set your WalkSpeed",
        Default = Modules.Config.WalkSpeed,
        Min = 16,
        Max = 200,
        Rounding = 0,
        Callback = Modules.SetWalkSpeed
    })

    CharacterSection:AddSpace({ Height = 6 })

    CharacterSection:AddToggle("EnableJumppowerToggle", {
        Title = "Enable JumpPower",
        Description = "Allow custom JumpPower",
        Default = false,
        Callback = Modules.EnableJumpPower
    })

    CharacterSection:AddSlider("JumppowerSlider", {
        Title = "Jump Power",
        Description = "Set your JumpPower",
        Default = Modules.Config.JumpPower,
        Min = 50,
        Max = 300,
        Rounding = 0,
        Callback = Modules.SetJumpPower
    })

    CharacterSection:AddSpace({ Height = 6 })

    CharacterSection:AddToggle("NoclipToggle", {
        Title = "Enable Noclip",
        Description = "Walk through walls",
        Default = false,
        Callback = Modules.EnableNoclip
    })

    CharacterSection:AddToggle("InfiniteJumpToggle", {
        Title = "Infinite Jump",
        Description = "Jump infinitely",
        Default = false,
        Callback = Modules.InfiniteJump
    })

    CharacterSection:AddButton({
        Title = "Reset Character",
        Description = "Respawn your character",
        Icon = "lucide/refresh-cw",
        Callback = function()
            if Modules.Character then
                Modules.Character:BreakJoints()
            end
        end
    })
end

do
    local GeneralSection = Combat:AddSection("General", "lucide/backpack")
    local MurdererSection = Combat:AddSection("Murderer", "lucide/skull")
    local SheriffSection = Combat:AddSection("Sheriff", "lucide/shield")

    GeneralSection:AddButton({
        Title = "Grab Gun",
        Description = "Picks up gun from the map",
        Icon = "lucide/hand",
        Callback = function()
            Modules.GrabGun()
        end
    })

    GeneralSection:AddKeybind("GrabGunKeybind", {
        Title = "Grab Gun Keybind",
        Description = "Key to pick up the gun",
        Mode = "Hold",
        Default = "G",
        Callback = function(pressed)
            if pressed then Modules.GrabGun() end
        end
    })

    GeneralSection:AddToggle("AutoGrabGunToggle", {
        Title = "Auto Grab Gun",
        Description = "Automatically grab gun from the map",
        Default = false,
        Callback = Modules.ToggleAutoGrabGun
    })

    GeneralSection:AddSpace({ Height = 6 })

    GeneralSection:AddToggle("GodModeToggle", {
        Title = "God Mode",
        Description = "Grants an extra life",
        Default = false,
        Callback = function(enabled)
            Modules.EnableGodMode(enabled)
        end
    })

    GeneralSection:AddToggle("AntiFlingToggle", {
        Title = "Anti-Fling",
        Description = "Prevents players from flinging you",
        Default = false,
        Callback = Modules.ToggleAntiFling
    })

    MurdererSection:AddButton({
        Title = "Kill All",
        Description = "Kill all players in the round",
        Icon = "lucide/skull",
        Callback = function()
            Modules.KillAll()
        end
    })

    MurdererSection:AddKeybind("KillAllKeybind", {
        Title = "Kill All Keybind",
        Description = "Key to kill all players",
        Mode = "Hold",
        Default = "K",
        Callback = function(pressed)
            if pressed then Modules.KillAll() end
        end
    })

    MurdererSection:AddToggle("AutoKillToggle", {
        Title = "Auto Kill All",
        Description = "Automatically kill players",
        Default = false,
        Callback = function(state)
            Modules.ToggleAutoKillAll(state)
        end
    })

    MurdererSection:AddSpace({ Height = 6 })

    MurdererSection:AddToggle("KillAuraToggle", {
        Title = "Knife Aura",
        Description = "Kill players within a certain radius",
        Default = false,
        Callback = function(enabled)
            Modules.KillAura(enabled)
        end
    })

    MurdererSection:AddSlider("AuraRadiusSlider", {
        Title = "Knife Aura Radius",
        Description = "Sets the detection radius",
        Default = Modules.Config.AuraRadius,
        Min = 5,
        Max = 100,
        Rounding = 0,
        Callback = function(value)
            Modules.Config.AuraRadius = value
        end
    })

    MurdererSection:AddSpace({ Height = 6 })

    MurdererSection:AddToggle("ThrowKnifeFlag", {
        Title = "Auto Knife Throw",
        Description = "Automatically throws a knife at the nearest player",
        Default = false,
        Callback = function(enabled)
            Modules.ToggleSilentThrow(enabled)
        end
    })

    MurdererSection:AddButton({
        Title = "Throw Knife",
        Description = "Throws the knife at the nearest player",
        Icon = "lucide/crosshair",
        Callback = function()
            Modules.ExecuteThrowAtNearest()
        end
    })

    MurdererSection:AddKeybind("ThrowKnifeKeybind", {
        Title = "Throw Knife Keybind",
        Description = "Key to throw the knife",
        Mode = "Hold",
        Default = "Q",
        Callback = function(pressed)
            if pressed then Modules.ExecuteThrowAtNearest() end
        end
    })

    SheriffSection:AddToggle("AutoShootMurderer", {
        Title = "Auto Shoot Murderer",
        Description = "Automatically shoots the murderer",
        Default = false,
        Callback = function(state)
            Modules.ToggleAutoShootMurderer(state)
        end
    })

    SheriffSection:AddButton({
        Title = "Shoot Murderer",
        Description = "Press to shoot murderer",
        Icon = "lucide/crosshair",
        Callback = function()
            Modules.ShootMurdererOnce()
        end
    })

    SheriffSection:AddKeybind("ShootMurdererKeybind", {
        Title = "Shoot Murderer Keybind",
        Description = "Key to shoot the murderer",
        Mode = "Hold",
        Default = "E",
        Callback = function(pressed)
            if pressed then Modules.ShootMurdererOnce() end
        end
    })
end

do
    local ESP_Folder = CoreGui:FindFirstChild("VisionESP")
    if not ESP_Folder then
        ESP_Folder = Instance.new("Folder")
        ESP_Folder.Name = "VisionESP"
        ESP_Folder.Parent = CoreGui
    end

    local function CreateBillboard(targetHead)
        local bg = Instance.new("BillboardGui")
        bg.Name = "NameESP"
        bg.Adornee = targetHead
        bg.Size = UDim2.new(0, 200, 0, 50)
        bg.StudsOffset = Vector3.new(0, 3, 0)
        bg.AlwaysOnTop = true
        
        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.Size = UDim2.new(1, 0, 1, 0)
        text.TextSize = 16
        text.TextScaled = false
        text.Font = Enum.Font.SourceSansBold
        text.TextColor3 = Color3.new(1,1,1)
        text.TextStrokeTransparency = 0
        text.TextStrokeColor3 = Color3.new(0,0,0)
        text.Parent = bg
        return bg
    end

    local function UpdateESPState()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Modules.Player and plr.Character then
                local espColor = Color3.fromRGB(0, 255, 0)
                local espRole = "Innocent"

                local isMurderer = (Modules.FindMurderer() == plr)
                local isSheriff = (Modules.FindSheriff() == plr)
                
                if Modules.PlayerData[plr.Name] then
                    local data = Modules.PlayerData[plr.Name]
                    if data.Role == "Hero" then 
                        espColor = Color3.fromRGB(255, 255, 0)
                        espRole = "Hero"
                    end
                end

                if isMurderer then
                    espColor = Color3.fromRGB(255, 0, 0)
                    espRole = "Murderer"
                elseif isSheriff then
                    espColor = Color3.fromRGB(0, 0, 255)
                    espRole = "Sheriff"
                end

                local char = plr.Character
                if Modules.Config.EspPlayers then
                    if not char:FindFirstChild("VisionHighlight") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "VisionHighlight"
                        hl.FillTransparency = 0.85
                        hl.OutlineTransparency = 0
                        hl.Parent = char
                    end
                    local hl = char:FindFirstChild("VisionHighlight")
                    if hl then
                        hl.FillColor = espColor
                        hl.OutlineColor = espColor
                        hl.Enabled = true
                    end
                else
                    if char:FindFirstChild("VisionHighlight") then
                        char.VisionHighlight:Destroy()
                    end
                end

                if Modules.Config.ShowNames then
                    local head = char:FindFirstChild("Head")
                    if head then
                        if not head:FindFirstChild("NameESP") then
                            local bg = CreateBillboard(head)
                            bg.Parent = head
                        end
                        local bg = head:FindFirstChild("NameESP")
                        local label = bg and bg:FindFirstChild("TextLabel")
                        
                        local root = Modules.RootPart
                        local enemyRoot = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                        local dist = "Unknown"
                        
                        if root and enemyRoot then
                            dist = math.floor((root.Position - enemyRoot.Position).Magnitude)
                        end
                        
                        if label then
                            label.Text = string.format("%s\n[%s] [%s]", plr.Name, espRole, tostring(dist))
                            label.TextColor3 = espColor
                        end
                    end
                else
                    if char:FindFirstChild("Head") and char.Head:FindFirstChild("NameESP") then
                        char.Head.NameESP:Destroy()
                    end
                end
            end
        end
    end

    local espLoop = nil
    local function ToggleESP_System(enabled)
        if enabled then
            if not espLoop then
                espLoop = AddConnection(RunService.RenderStepped:Connect(UpdateESPState))
            end
        else
            if not Modules.Config.EspPlayers and not Modules.Config.ShowNames then
                if espLoop then
                    espLoop:Disconnect()
                    espLoop = nil
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character then
                        if p.Character:FindFirstChild("VisionHighlight") then p.Character.VisionHighlight:Destroy() end
                        if p.Character:FindFirstChild("Head") and p.Character.Head:FindFirstChild("NameESP") then p.Character.Head.NameESP:Destroy() end
                    end
                end
            end
        end
    end

    local gunESPConnection = nil

    local function RemoveGunESP()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "GunDrop" then
                if obj:FindFirstChild("VisionGunHighlight") then obj.VisionGunHighlight:Destroy() end
                if obj:FindFirstChild("VisionGunLabel") then obj.VisionGunLabel:Destroy() end
            end
        end
    end

    local function AddGunESP(gun)
        if not gun or not gun:IsA("BasePart") then return end
        
        if gun:FindFirstChild("VisionGunHighlight") then gun.VisionGunHighlight:Destroy() end
        if gun:FindFirstChild("VisionGunLabel") then gun.VisionGunLabel:Destroy() end

        local hl = Instance.new("Highlight")
        hl.Name = "VisionGunHighlight"
        hl.Adornee = gun
        hl.FillColor = Color3.fromRGB(0, 255, 255)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Parent = gun

        local bg = Instance.new("BillboardGui")
        bg.Name = "VisionGunLabel"
        bg.Adornee = gun
        bg.Size = UDim2.new(0, 150, 0, 50)
        bg.StudsOffset = Vector3.new(0, 2, 0)
        bg.AlwaysOnTop = true
        
        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.Size = UDim2.new(1, 0, 1, 0)
        text.TextSize = 14
        text.Font = Enum.Font.GothamBold
        text.Text = "DROPPED GUN"
        text.TextColor3 = Color3.fromRGB(0, 255, 255)
        text.TextStrokeTransparency = 0
        text.TextStrokeColor3 = Color3.new(0,0,0)
        text.Parent = bg
        
        bg.Parent = gun
    end

    function Modules.ToggleGunESP(enable)
        Modules.Config.EspDroppedGun = enable
        
        if gunESPConnection then
            gunESPConnection:Disconnect()
            gunESPConnection = nil
        end
        
        if enable then
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v.Name == "GunDrop" then
                    AddGunESP(v)
                end
            end
            
            gunESPConnection = AddConnection(Workspace.DescendantAdded:Connect(function(v)
                if v.Name == "GunDrop" then
                    task.wait()
                    AddGunESP(v)
                end
            end))
        else
            RemoveGunESP()
        end
    end

    local ESPSection = Visuals:AddSection("ESP", "lucide/eye")
    local NotifySection = Visuals:AddSection("Notify", "lucide/bell")

    ESPSection:AddToggle("EspToggle", {
        Title = "ESP Players",
        Description = "Highlight players in round",
        Default = false,
        Callback = function(state)
            Modules.Config.EspPlayers = state
            ToggleESP_System(state or Modules.Config.ShowNames)
        end
    })

    ESPSection:AddToggle("ShowNamesToggle", {
        Title = "Show Informations",
        Description = "Show name, role and distance",
        Default = false,
        Callback = function(state)
            Modules.Config.ShowNames = state
            ToggleESP_System(state or Modules.Config.EspPlayers)
        end
    })

    ESPSection:AddToggle("EspGunToggle", {
        Title = "ESP Dropped Gun",
        Description = "Highlights gun and shows text when dropped",
        Default = false,
        Callback = function(state)
            Modules.ToggleGunESP(state)
        end
    })

    ESPSection:AddSpace({ Height = 6 })

    ESPSection:AddToggle("RoundTimerToggle", {
        Title = "Round Timer",
        Description = "Displays the round timer",
        Default = false,
        Callback = function(state)
            Modules.ToggleRoundTimer(state)
        end
    })

    NotifySection:AddToggle("NotifyGunDroppedToggle", {
        Title = "Notify Gun Dropped",
        Description = "Get notified when a gun is dropped",
        Default = false,
        Callback = function(state)
            Modules.ToggleNotifyGunDropped(state)
        end
    })

    NotifySection:AddToggle("NotifyMurdererToggle", {
        Title = "Notify Murderer",
        Description = "Alert when the Murderer spawns",
        Default = false,
        Callback = function(state)
            Modules.Config.NotifyMurderer = state
            Modules.UpdateRoleNotify()
        end
    })

    NotifySection:AddToggle("NotifySheriffToggle", {
        Title = "Notify Sheriff",
        Description = "Alert when the Sheriff spawns",
        Default = false,
        Callback = function(state)
            Modules.Config.NotifySheriff = state
            Modules.UpdateRoleNotify()
        end
    })
end

do
    local buttonsSection = Buttons:AddSection("Buttons", "lucide/square-mouse-pointer")

    buttonsSection:AddToggle("lock_buttons", {
        Title = "Lock Buttons",
        Description = "Lock mobile button positions.",
        Default = false,
        Callback = function(locked)
            Modules.Config.ButtonsLocked = locked
        end
    })

    buttonsSection:AddSpace({ Height = 6 })

    buttonsSection:AddToggle("show_shoot_button", {
        Title = "Show Shoot Button",
        Description = "Adds shoot image button.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "Shoot",
                {
                    Enabled = enabled,
                    Type = "Image",
                    Icon = "rbxassetid://139650104834071",
                },
                Modules.ShootMurdererOnce
            )
        end
    })

    buttonsSection:AddSpace({ Height = 6 })

    buttonsSection:AddToggle("show_fmurderer_button", {
        Title = "Fling Murderer Button",
        Description = "Fling the murderer.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "FlingMurderer",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Fling Murderer",
                    TextColor = Color3.fromRGB(255, 255, 255),
                },
                function()
                    local murderer = Modules.FindMurderer()
                    if murderer and murderer.Character then
                        SkidFling(murderer)
                    end
                end
            )
        end
    })

    buttonsSection:AddToggle("show_fsheriff_button", {
        Title = "Fling Sheriff Button",
        Description = "Fling the sheriff.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "FlingSheriff",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Fling Sheriff",
                    TextColor = Color3.fromRGB(255, 255, 255),
                },
                function()
                    local sheriff = Modules.FindSheriff()
                    if sheriff and sheriff.Character then
                        SkidFling(sheriff)
                    end
                end
            )
        end
    })

    buttonsSection:AddToggle("show_fhero_button", {
        Title = "Fling Hero Button",
        Description = "Fling the Hero player.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "FlingHero",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Fling Hero",
                    TextColor = Color3.fromRGB(255, 255, 255),
                },
                function()
                    if Modules.PlayerData then
                        for name, data in pairs(Modules.PlayerData) do
                            if data and (data.Role == "Hero" or data.role == "Hero") then
                                local pl = Players:FindFirstChild(name)
                                if pl and pl.Character then
                                    SkidFling(pl)
                                    return
                                end
                            end
                        end
                    end
                end
            )
        end
    })

    buttonsSection:AddSpace({ Height = 6 })

    buttonsSection:AddToggle("show_kill_button", {
        Title = "Show Kill Button",
        Description = "Adds Kill All button.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "Kill",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Kill All",
                    TextColor = Color3.fromRGB(255, 255, 255),
                },
                Modules.KillAll
            )
        end
    })

    buttonsSection:AddToggle("show_throw_knife_button", {
        Title = "Show Throw Knife Button",
        Description = "Throw a knife at nearest.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "ThrowKnife",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Throw Knife",
                },
                Modules.ExecuteThrowAtNearest
            )
        end
    })

    buttonsSection:AddSpace({ Height = 6 })

    buttonsSection:AddToggle("show_grab_gun_button", {
        Title = "Show Grab Gun Button",
        Description = "Grab or pick up a gun.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "GrabGun",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Grab Gun",
                },
                Modules.GrabGun
            )
        end
    })

    buttonsSection:AddSpace({ Height = 6 })

    buttonsSection:AddToggle("show_teleport_button", {
        Title = "Show Teleport Map Button",
        Description = "Teleport to current map.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "Teleport",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Teleport to Map",
                },
                Modules.TeleportToMap
            )
        end
    })

    buttonsSection:AddToggle("show_teleport_lobby_button", {
        Title = "Show Teleport Lobby Button",
        Description = "Teleport back to lobby.",
        Default = false,
        Callback = function(enabled)
            Modules.CreateGuiButton(
                "TeleportLobby",
                {
                    Enabled = enabled,
                    Type = "Text",
                    Text = "Teleport to Lobby",
                },
                Modules.TeleportToLobby
            )
        end
    })
end

do
    local PlayersSection = Teleports:AddSection("Players", "lucide/user")
    local RolesSection = Teleports:AddSection("Roles", "lucide/crown")
    local LocationsSection = Teleports:AddSection("Locations", "lucide/map-pin")

    local selectedPlayer = nil

    local playerDropdown = PlayersSection:AddDropdown("TeleportPlayerDropdown", {
        Title = "Select Player",
        Description = "Choose a player to teleport to",
        Values = {},
        Multi = false,
        AllowNull = true,
        Callback = function(option)
            selectedPlayer = option and Modules.GetPlayerByName(option) or nil
        end
    })

    local function refreshPlayerList()
        local items = {}

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Modules.Player then
                table.insert(items, p.Name)
            end
        end

        playerDropdown:SetValues(items)
    end

    refreshPlayerList()

    AddConnection(Players.PlayerAdded:Connect(refreshPlayerList))
    AddConnection(Players.PlayerRemoving:Connect(refreshPlayerList))

    PlayersSection:AddButton({
        Title = "Teleport to Player",
        Description = "Teleport to the selected player",
        Icon = "lucide/arrow-right",
        Callback = function()
            if selectedPlayer then
                Modules.TeleportToPlayer(selectedPlayer)
            end
        end
    })

    RolesSection:AddButton({
        Title = "Teleport to Murderer",
        Description = "Teleport to the murderer",
        Icon = "lucide/skull",
        Callback = function()
            local murderer = Modules.FindMurderer()
            if murderer then Modules.TeleportToPlayer(murderer) end
        end
    })

    RolesSection:AddButton({
        Title = "Teleport to Sheriff",
        Description = "Teleport to the sheriff",
        Icon = "lucide/shield",
        Callback = function()
            local sheriff = Modules.FindSheriff()
            if sheriff then Modules.TeleportToPlayer(sheriff) end
        end
    })

    RolesSection:AddButton({
        Title = "Teleport to Hero",
        Description = "Teleport to the hero",
        Icon = "lucide/star",
        Callback = function()
            if Modules.PlayerData then
                for name, data in pairs(Modules.PlayerData) do
                    if data and (data.Role == "Hero" or data.role == "Hero") then
                        local pl = Players:FindFirstChild(name)
                        if pl then Modules.TeleportToPlayer(pl) return end
                    end
                end
            end
        end
    })

    LocationsSection:AddButton({
        Title = "Lobby",
        Description = "Return to the main lobby",
        Icon = "lucide/house",
        Callback = function()
            Modules.TeleportToLobby()
        end
    })

    LocationsSection:AddButton({
        Title = "Teleport to Map",
        Description = "Teleports you to the current Map",
        Icon = "lucide/map",
        Callback = function()
            Modules.TeleportToMap()
        end
    })
end

do
    local FlingSection = Misc:AddSection("Fling", "lucide/wind")
    local EmotesSection = Misc:AddSection("Emotes", "lucide/smile")
    local ChatSection = Misc:AddSection("Chat", "lucide/message-square")

    local selectedFlingPlayer = nil

    local flingDropdown = FlingSection:AddDropdown("FlingPlayerDropdown", {
        Title = "Select Player",
        Description = "Choose a player",
        Values = {},
        Multi = false,
        AllowNull = true,
        Callback = function(option)
            selectedFlingPlayer = option and Players:FindFirstChild(option) or nil
        end
    })

    local function updateDropdown()
        local items = {}

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Modules.Player then
                table.insert(items, p.Name)
            end
        end

        flingDropdown:SetValues(items)
    end

    updateDropdown()

    AddConnection(Players.PlayerAdded:Connect(updateDropdown))
    AddConnection(Players.PlayerRemoving:Connect(updateDropdown))

    FlingSection:AddButton({
        Title = "Fling Player",
        Description = "Fling the selected player into the air",
        Icon = "lucide/wind",
        Callback = function()
            if selectedFlingPlayer and selectedFlingPlayer.Character then
                SkidFling(selectedFlingPlayer)
            end
        end
    })

    FlingSection:AddButton({
        Title = "Fling All Players",
        Description = "Fling all players in the game",
        Icon = "lucide/wind",
        Callback = function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Modules.Player and p.Character then
                    SkidFling(p)
                end
            end
        end
    })

    FlingSection:AddSpace({ Height = 6 })

    FlingSection:AddButton({
        Title = "Fling Murderer",
        Description = "Fling the murderer into the air",
        Icon = "lucide/skull",
        Callback = function()
            local murderer = Modules.FindMurderer()
            if murderer and murderer.Character then
                SkidFling(murderer)
            end
        end
    })

    FlingSection:AddButton({
        Title = "Fling Sheriff",
        Description = "Fling the sheriff into the air",
        Icon = "lucide/shield",
        Callback = function()
            local sheriff = Modules.FindSheriff()
            if sheriff and sheriff.Character then
                SkidFling(sheriff)
            end
        end
    })

    FlingSection:AddButton({
        Title = "Fling Hero",
        Description = "Fling the hero into the air",
        Icon = "lucide/star",
        Callback = function()
            if Modules.PlayerData then
                for name, data in pairs(Modules.PlayerData) do
                    if data and (data.Role == "Hero" or data.role == "Hero") then
                        local pl = Players:FindFirstChild(name)
                        if pl and pl.Character then
                            SkidFling(pl)
                            return
                        end
                    end
                end
            end
        end
    })

    local selectedEmote = nil

    EmotesSection:AddDropdown("EmoteSelectDropdown", {
        Title = "Select Emote",
        Description = "Choose an emote to play",
        Values = {"sit", "zombie", "ninja", "zen", "floss", "dab"},
        Multi = false,
        Default = 1,
        Callback = function(v)
            selectedEmote = v
        end
    })

    EmotesSection:AddButton({
        Title = "Play Emote",
        Description = "Plays the selected emote",
        Icon = "lucide/play",
        Callback = function()
            if selectedEmote then
                Modules.PlayEmote(selectedEmote)
            end
        end
    })

    ChatSection:AddButton({
        Title = "Expose Roles in Chat",
        Description = "Says Murderer/Sheriff name in chat",
        Icon = "lucide/message-circle",
        Callback = function()
            Modules.ChatRoles()
        end
    })
end

do
    local ServerSection = Settings:AddSection("Server", "lucide/server")

    ServerSection:AddButton({
        Title = "Rejoin Server",
        Description = "Rejoins the current server",
        Icon = "lucide/refresh-cw",
        Callback = function()
            Window:Dialog({
                Title = "Confirm Rejoin",
                Content = "Are you sure you want to rejoin the server?",
                Buttons = {
                    { Title = "Rejoin", Callback = function() Modules.Rejoin() end },
                    { Title = "Cancel" }
                }
            })
        end
    })

    ServerSection:AddButton({
        Title = "Server Hop",
        Description = "Joins a different server",
        Icon = "lucide/shuffle",
        Callback = function()
            Window:Dialog({
                Title = "Confirm Server Hop",
                Content = "Are you sure you want to server hop?",
                Buttons = {
                    { Title = "Server Hop", Callback = function() Modules.ServerHop() end },
                    { Title = "Cancel" }
                }
            })
        end
    })

    ServerSection:AddSpace({ Height = 6 })

    ServerSection:AddToggle("AutoQueueToggle", {
        Title = "Queue on Teleport",
        Description = "Executes the script automatically when queuing",
        Default = Modules.Config.AutoQueue and true or false,
        Callback = function(state)
            Modules.Config.AutoQueue = state
        end
    })
end

do
    local FarmingSection = Farming:AddSection("Farming", "lucide/dollar-sign")

    FarmingSection:AddParagraph({
        Title = "Are you doing here?",
        Content = "Farming features are not yet implemented.",
    })
end

do
    local SaveManager = Fluent.SaveManager
    local InterfaceManager = Fluent.InterfaceManager

    if SaveManager and InterfaceManager then
        SaveManager:SetLibrary(Fluent)
        InterfaceManager:SetLibrary(Fluent)

        InterfaceManager:SetFolder("VisionHub")
        SaveManager:SetFolder("VisionHub/Config")

        SaveManager:IgnoreThemeSettings()

        InterfaceManager:BuildInterfaceSection(Settings)
        SaveManager:BuildConfigSection(Settings)

        pcall(function()
            SaveManager:LoadAutoloadConfig()
        end)
    end
end

Window:SelectTab(1)

return Modules
