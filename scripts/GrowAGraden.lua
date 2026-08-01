--[[
    Zoex Hub - Fluent Edition
    - HarvestObject: turbo mode, minimal waits, instant fire, no redundant checks
    - Auto Harvest loop: stripped down, 0.01s loop rate, direct CFrame + fire
    - Auto Expand Garden: fires ExpandGarden packet on a fast loop
    - Anti-Lag: full optimization (materials, textures, particles, lights, quality)
    - UI: FluentPro (Fluent-modded by StyearX)
    - All features preserved: Harvest, Plant, Steal, Shop, Defense, Sell, Misc, Extra
--]]


-- ============================================================
--  1. CORE LOGIC VARIABLES
-- ============================================================
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local PacketModule = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"))
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

-- Toggle states
local enabledHarvest      = false
local enabledAutoBuy      = false
local enabledAutoGear     = false
local enabledAutoPet      = false
local enabledDefense      = false
local enabledAutoSell     = false
local enabledAntiFling    = false
local enabledSellWhenFull = false
local autoSellDelay       = 5
local myPlot              = nil
local myPlotLastCheck     = 0
local selectedSeeds       = {}
local selectedGears       = {}
local selectedPets        = {}
local shecklesAmount      = ""

-- Harvest filters
local enabledHarvestSeedFilter      = false
local selectedHarvestSeeds          = {}   -- set of seed names to harvest (whitelist)
local enabledHarvestMutationFilter  = false
local selectedHarvestMutations      = {}   -- set of mutation names to harvest (e.g. Gold, Rainbow)

-- Auto Plant
local enabledAutoPlant      = false
local selectedPlantSeeds    = {}   -- set of seed names to plant (whitelist)
local autoPlantMaxPerSweep  = 30   -- max plants per sweep
local autoPlantConn         = nil

-- Steal Tab toggles
local enabledSteal        = false
local enabledNoFog        = false
local enabledNoclip       = false
local enabledSpeedBoost   = false
local enabledJumpBoost    = false
local stealTargetPlayer   = nil
local stealTweenSpeed     = 0.5
local speedBoostValue     = 50
local jumpBoostValue      = 100

-- Anti-Lag toggle
local enabledAntiLag      = false

-- Auto Expand Garden
local enabledAutoExpand   = false

-- Auto Collect Dropped Seeds (Gold/Rainbow)
local enabledAutoCollect  = false
local autoCollectConn     = nil

-- Harvest stats
local sessionItemsHarvested = 0

-- Safe harvest mode (set _G.SafeHarvest = true to skip teleporting)
if _G.SafeHarvest == nil then _G.SafeHarvest = false end

-- Auto-collect seeds global flag (used by AutoCollectSeedPacks loop)
if _G.AutoCollectSeeds == nil then _G.AutoCollectSeeds = false end

-- Saved position for tween return
local savedPosition       = nil

-- Defense tracking
local lastThief          = nil
local lastThiefTime      = 0
local defenseActive      = false
local retrievedDetected  = false

-- Stats
local statsStartTime     = tick()

-- Stock
local stockLastScan      = "Not scanned yet"
local stockScanTime      = 0

-- Anti-fling
local antiFlingConn      = nil

-- Noclip / Speed / Jump connections
local noclipConnection    = nil
local speedConnection     = nil
local jumpConnection      = nil
local originalWalkSpeed   = 16
local originalJumpPower   = 50

-- Valid seeds for stock scanning
local validSeeds = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Pumpkin",
    "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana",
    "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn", "Cherry", "Sunflower",
    "Pomegranate", "Poison Apple", "Lotus", "Beanstalk", "Venus Flytrap",
    "Moon Bloom", "Dragon's Breath", "Thorn Rose"
}

local allSeeds = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple",
    "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean",
    "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn",
    "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate",
    "Poison Apple", "Moon Bloom", "Dragon's Breath"
}

local allGears = {
    "Common Watering Can",
    "Trowel", "Trading Ticket", "Recall Wrench",
    "Basic Sprinkler", "Firework",
    "Advanced Sprinkler", "Medium Treat", "Medium Toy",
    "Night Staff", "Star Caller", "Magnifying Glass",
    "Godly Sprinkler", "Cleaning Spray", "Favorite Tool",
    "Harvest Tool", "Friendship Pot", "Honey Sprinkler",
    "Silver Fertilizer", "Lush Sprinkler",
    "Master Sprinkler", "Levelup Lollipop", "Grandmaster Sprinkler",
    "Rainbow Lollipop", "Silver Lollipop", "Gold Lollipop", "Mega Lollipop",
    "Lightning Rod", "Tanning Mirror", "Reclaimer",
    "Small Toy", "Small Treat", "Smith Hammer of Harvest",
    "Smith Treat", "Pet Pouch", "Thundelbringer", "Chimera Stone",
    "Berry Blusher Sprinkler", "Flower Froster Sprinkler", "Spice Spritzer Sprinkler",
    "Spray Mutation Verdant", "Spray Mutation Disco", "Spray Mutation Wet",
    "Spray Mutation Windstruck", "Spray Mutation Choc", "Spray Mutation Pollinated",
    "Spray Mutation Shocked", "Spray Mutation Cloudtouched", "Spray Mutation Burnt",
    "Spray Mutation Chilled", "Spray Mutation Amber", "Spray Mutation Tranquil",
    "Spray Mutation Corrupt", "Spray Mutation HoneyGlazed", "Spray Mutation Fried",
    "Spray Mutation Bloom", "Spray Mutation Glimmering", "Spray Mutation Luminous",
}

local allWildPets = {
    "Frog", "Bunny", "Owl", "Deer", "Bee", "Robin",
    "Monkey", "Golden_Dragonfly", "Unicorn",
    "Raccoon", "Black_Dragon", "Ice_Serpent",
}

-- ============================================================
--  4. HELPER FUNCTIONS
-- ============================================================

-- Get money from exact path
local function getMoney()
    local sheckles = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Sheckles")
    if sheckles then return sheckles.Value end
    return 0
end

-- Check if "Your inventory is full" text is visible
local function isInventoryFull()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, d in pairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            if d.Visible then
                local ok, v = pcall(function() return d.Text end)
                if ok and v and type(v) == "string" then
                    if v:lower():find("inventory is full") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Shovel helpers
local function findShovel()
    local char = player.Character
    if not char then return nil end
    for _, t in pairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower() == "shovel" then return t end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, t in pairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower() == "shovel" then return t end
        end
    end
    for _, folder in pairs(workspace:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            local s = folder:FindFirstChild("Shovel")
            if s and s:IsA("Tool") then
                local taken = false
                for _, op in pairs(Players:GetPlayers()) do
                    if op ~= player and op.Character then
                        for _, t in pairs(op.Character:GetChildren()) do
                            if t == s then taken = true break end
                        end
                    end
                end
                if not taken then return s end
            end
        end
    end
    return nil
end

local function equipShovel()
    local char = player.Character
    if not char then return end
    for _, t in pairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower() == "shovel" then return end
    end
    local s = findShovel()
    if s then s.Parent = char task.wait(0.05) end
end

local function clickM1()
    if mouse1click then
        mouse1click()
    else
        local char = player.Character
        if char then
            for _, t in pairs(char:GetChildren()) do
                if t:IsA("Tool") then pcall(function() t:Activate() end) end
            end
        end
    end
end

-- ============================================================
--  AUTO PLANT HELPERS (adapted from external planting script)
-- ============================================================

local function getLocalPlot()
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    local plotId = player:GetAttribute("PlotId")
    if plotId then
        return gardens:FindFirstChild("Plot" .. tostring(plotId))
    end
    return nil
end

local function getPlantAreas(plot)
    local areas = {}
    for _, inst in ipairs(CollectionService:GetTagged("PlantArea")) do
        if inst:IsA("BasePart") and inst:IsDescendantOf(plot) then
            table.insert(areas, inst)
        end
    end
    if #areas == 0 then
        local folder = plot:FindFirstChild("PlantableArea")
        if folder then
            for _, inst in ipairs(folder:GetChildren()) do
                if inst:IsA("BasePart") then
                    table.insert(areas, inst)
                end
            end
        end
    end
    -- Fallback: use PlotSizeReference part as the plantable bounds
    if #areas == 0 then
        local ref = plot:FindFirstChild("PlotSizeReference")
        if ref and ref:IsA("BasePart") then
            table.insert(areas, ref)
        end
    end
    return areas
end

local function getExistingPlantPositions(plot)
    local positions = {}
    -- Prefer reading directly from this plot's own Plants folder (reliable, scoped)
    local plantsFolder = plot and plot:FindFirstChild("Plants")
    if plantsFolder then
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            local part = plant.PrimaryPart or (plant:IsA("BasePart") and plant) or plant:FindFirstChildWhichIsA("BasePart", true)
            if part then
                table.insert(positions, part.Position)
            end
        end
        if #positions > 0 then return positions end
    end
    -- Fallback: global CollectionService tag scan
    for _, plant in ipairs(CollectionService:GetTagged("Plant")) do
        if plant:GetAttribute("OwnerUserId") == player.UserId then
            local part = plant.PrimaryPart or plant:FindFirstChildWhichIsA("BasePart", true)
            if part then
                table.insert(positions, part.Position)
            end
        end
    end
    return positions
end

local function isOccupied(pos, occupied, spacing)
    local threshold = spacing * spacing
    for _, other in ipairs(occupied) do
        local dx = pos.X - other.X
        local dz = pos.Z - other.Z
        if dx * dx + dz * dz < threshold then
            return true
        end
    end
    return false
end

local function buildPlantSpots(areas)
    local spots = {}
    local spacing = 2
    local margin = 1
    for _, area in ipairs(areas) do
        local cf = area.CFrame
        local size = area.Size
        local usableX = math.max(size.X - margin * 2, 0)
        local usableZ = math.max(size.Z - margin * 2, 0)
        for x = -usableX / 2, usableX / 2, spacing do
            for z = -usableZ / 2, usableZ / 2, spacing do
                table.insert(spots, cf:PointToWorldSpace(Vector3.new(x, size.Y / 2, z)))
            end
        end
    end
    return spots
end

-- findSeedTool: search Backpack + Character for a Tool whose SeedTool attribute
-- (or stripped Name) matches one of the selected seeds.
local function findSeedTool(selectedSeedsList)
    if not selectedSeedsList or #selectedSeedsList == 0 then return nil, nil end
    local containers = {
        player:FindFirstChild("Backpack"),
        player.Character,
    }
    for _, container in ipairs(containers) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local seedName = tool:GetAttribute("SeedTool") or tool.Name:gsub(" Seed$", "")
                    if table.find(selectedSeedsList, seedName) or table.find(selectedSeedsList, tool.Name) then
                        return seedName, tool
                    end
                end
            end
        end
    end
    return nil, nil
end

local function plantTweenTo(root, position)
    local targetCF = CFrame.new(position + Vector3.new(0, 3.5, 0))
    local distance = (root.Position - targetCF.Position).Magnitude
    if distance <= 3 then
        root.CFrame = targetCF
        return
    end
    local duration = math.clamp(distance / 50, 0.2, 2.5)
    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = targetCF }
    )
    tween:Play()
    tween.Completed:Wait()
end

-- equipSeedTool: explicit equip step, run before every plant fire.
-- Returns true once the tool is actually parented under the character.
local function equipSeedTool(seedTool)
    local character = player.Character
    if not character or not seedTool then return false end
    if seedTool.Parent == character then return true end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    humanoid:EquipTool(seedTool)
    -- wait briefly for the tool to actually parent under the character
    for _ = 1, 10 do
        if seedTool.Parent == character then return true end
        task.wait(0.05)
    end
    return seedTool.Parent == character
end

local function plantAt(position, seedName, seedTool, networking)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    plantTweenTo(root, position)
    if not equipSeedTool(seedTool) then return false end
    local seedKey = seedTool:GetAttribute("SeedTool") or seedName:gsub(" Seed$", "") or seedName
    local fired = false
    pcall(function()
        networking.Plant.PlantSeed:Fire(position, seedKey, seedTool)
        fired = true
    end)
    return fired
end

-- Convert the selectedPlantSeeds set (key=true) into a list for findSeedTool
local function getSelectedPlantSeedList()
    local list = {}
    for name, _ in pairs(selectedPlantSeeds) do
        table.insert(list, name)
    end
    return list
end

-- autoPlantOnce: do one full sweep of the plot, planting selected seeds in free spots.
-- Returns the number of plants placed.
local function autoPlantOnce()
    if not enabledAutoPlant then return 0 end
    local selectedList = getSelectedPlantSeedList()
    if #selectedList == 0 then return 0 end

    local plot = getLocalPlot()
    if not plot then return 0 end

    local areas = getPlantAreas(plot)
    if #areas == 0 then return 0 end

    local occupied = getExistingPlantPositions(plot)
    local spots = buildPlantSpots(areas)

    -- Use the already-loaded Packet module (loaded once at script start, no per-sweep require)
    local PlantSeedPacket = PacketModule("PlantSeed")
    if not PlantSeedPacket then return 0 end
    local networking = { Plant = { PlantSeed = PlantSeedPacket } }

    local planted = 0
    local consecutiveFails = 0
    for _, spot in ipairs(spots) do
        if not enabledAutoPlant then break end
        if planted >= autoPlantMaxPerSweep then break end
        if consecutiveFails >= 5 then break end -- avoid spinning when out of seeds
        if not isOccupied(spot, occupied, 1.6) then
            local seedName, seedTool = findSeedTool(selectedList)
            if not seedTool then break end
            if plantAt(spot, seedName, seedTool, networking) then
                planted = planted + 1
                consecutiveFails = 0
                table.insert(occupied, spot)
                task.wait(0.05)
            else
                consecutiveFails = consecutiveFails + 1
                task.wait(0.1)
            end
        end
    end
    return planted
end

-- Sell
local function sellAll()
    local PacketModule = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Packet"))
    local SellPacket = PacketModule("SellAll")
    if SellPacket then
        SellPacket:Fire()
    end
end

local enabledAutoDailyDeal = false

local function SellDailyDeal()
    local Packet
    for _, v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v:IsA("ModuleScript") and v.Name == "Packet" then
            Packet = require(v)
            break
        end
    end
    if not Packet then return warn("Packet not found") end
    Packet("UseDailyDealAll"):Response(Packet.Any):Fire()
end

-- ============================================================
--  5. IMPROVED HARVEST OBJECT FUNCTION
-- ============================================================
-- HarvestObject(obj, rp) -> bool
--   obj: the plant model or object containing a harvestable part
--   rp:  player's HumanoidRootPart (optional, auto-fetched if nil)
--
-- Improvements over original:
--   1. Auto-fetches HRP if rp is nil
--   2. Checks for prompt at multiple levels (HarvestPart, obj itself, descendants)
--   3. Validates ActionText/ObjectText contains "harvest" as fallback detection
--   4. Zero-velocity teleport with network ownership check
--   5. Retry logic (up to 3 attempts) if prompt re-enables after fire
--   6. Proper nil/error guards on every property access
--   7. Respects _G.SafeHarvest mode (no teleport, long-range fire only)
--   8. Returns false explicitly on failure (original returned nil)
--   9. Restores MaxActivationDistance even on error
--  10. Minimal yield times for speed

local function HarvestObject(obj, rp)
    if not obj then return false end

    -- Auto-fetch HRP if not provided
    if not rp then
        local char = player.Character
        if not char then return false end
        rp = char:FindFirstChild("HumanoidRootPart")
        if not rp then return false end
    end
    if not rp or not rp.Parent then return false end

    -- Find HarvestPart — direct child first, then deep scan for harvest prompts
    local hp = obj:FindFirstChild("HarvestPart")
    if not hp then
        for _, desc in pairs(obj:GetDescendants()) do
            if desc:IsA("BasePart") then
                for _, child in pairs(desc:GetChildren()) do
                    if child:IsA("ProximityPrompt") then
                        local n = child.Name or ""
                        local a = child.ActionText or ""
                        local o = child.ObjectText or ""
                        if n:lower():find("harvest") or a:lower():find("harvest") or o:lower():find("harvest") then
                            hp = desc
                            break
                        end
                    end
                end
                if hp then break end
            end
        end
    end
    if not hp or not hp.Parent then return false end

    -- Find the prompt
    local prompt = hp:FindFirstChild("HarvestPrompt")
    if not prompt or not prompt:IsA("ProximityPrompt") then
        prompt = hp:FindFirstChildWhichIsA("ProximityPrompt")
    end
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end

    -- Save distance, set to max
    local oldDist = prompt.MaxActivationDistance or 10
    prompt.MaxActivationDistance = 9999

    local success = false

    if _G.SafeHarvest then
        -- Safe mode: fire from distance, no teleport
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.01)
        if not prompt.Enabled or not prompt.Parent then
            success = true
        end
    else
        -- TURBO mode: zero velocity, instant teleport, instant fire
        rp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        rp.CFrame = hp.CFrame * CFrame.new(0, 1.5, 0)
        -- No yield — fire immediately after CFrame set
        if prompt.Parent and prompt.Enabled then
            pcall(function() fireproximityprompt(prompt) end)
        end
        task.wait(0.01)
        -- Check success
        if not prompt.Enabled or not prompt.Parent then
            success = true
        else
            -- One fast retry
            rp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            rp.CFrame = hp.CFrame * CFrame.new(0, 1.5, 0)
            if prompt.Parent and prompt.Enabled then
                pcall(function() fireproximityprompt(prompt) end)
            end
            task.wait(0.01)
            if not prompt.Enabled or not prompt.Parent then
                success = true
            end
        end
    end

    -- Restore distance
    pcall(function()
        if prompt and prompt.Parent then
            prompt.MaxActivationDistance = oldDist
        end
    end)

    if success then
        sessionItemsHarvested = sessionItemsHarvested + 1
    end
    return success
end

-- ============================================================
--  6. STEAL TAB HELPERS
-- ============================================================

local RootPart  -- set as side-effect of GetChar() (used by TP / AutoCollectSeedPacks)

local function GetChar()
    local char = player.Character
    if not char then RootPart = nil return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    RootPart = hrp
    return char, hrp, hum
end

-- TP helper: instant teleport RootPart to a world position (with small Y offset)
local function TP(pos)
    if not RootPart then return end
    pcall(function()
        RootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        RootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        RootPart.CFrame = CFrame.new(pos) * CFrame.new(0, 3, 0)
    end)
end

-- FirePrompt helper: fire a ProximityPrompt (instant fire, with InputHold fallback)
local function FirePrompt(prompt)
    if not prompt or not prompt.Parent then return end
    pcall(function() fireproximityprompt(prompt) end)
    if prompt and prompt.Parent and prompt.Enabled then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.1)
            prompt:InputHoldEnd()
        end)
    end
end

-- FindPlantFromPrompt: walk up the hierarchy from a prompt until we find an instance
-- that has the SeedName or Mutation attribute (the actual plant object).
-- Returns: plantInstance, seedName (string|nil), mutation (string|nil)
local function FindPlantFromPrompt(prompt)
    if not prompt then return nil, nil, nil end
    local cur = prompt.Parent
    local seedName, mutation
    -- Walk up to 8 levels — plant is usually prompt.Parent.Parent or prompt.Parent.Parent.Parent
    for _ = 1, 8 do
        if not cur or cur == workspace then break end
        local sn = cur:GetAttribute("SeedName")
        local mu = cur:GetAttribute("Mutation")
        if sn then seedName = sn end
        if mu then mutation = mu end
        if seedName or mutation then
            return cur, seedName, mutation
        end
        cur = cur.Parent
    end
    return nil, nil, nil
end

local function GetPlantTierPriority(name)
    local lower = name:lower()
    if lower:find("legendary") or lower:find("mythic") then return 5, "Legendary" end
    if lower:find("rare") then return 4, "Rare" end
    if lower:find("uncommon") then return 3, "Uncommon" end
    if lower:find("common") then return 2, "Common" end
    return 1, "Unknown"
end

local function FindStealPrompts()
    local results = {}
    for _,obj in pairs(Workspace:GetDescendants()) do
        if not obj:IsA("ProximityPrompt") then continue end
        if not obj.ActionText:lower():find("steal") then continue end
        if stealTargetPlayer and stealTargetPlayer ~= "" then
            local tun = stealTargetPlayer:lower()
            local inPlot = false
            local cur = obj.Parent
            while cur and cur ~= Workspace do
                local owner = cur:GetAttribute("Owner") or cur:GetAttribute("OwnerName")
                if owner and tostring(owner):lower() == tun then inPlot = true break end
                if cur.Name:lower():find(tun) then inPlot = true break end
                cur = cur.Parent
            end
            if not inPlot then continue end
        end
        local part = obj.Parent
        local pos = part and part:IsA("BasePart") and part.Position
        if pos then
            local _, hrp, _ = GetChar()
            local prio, tier = GetPlantTierPriority(part.Name)
            table.insert(results, {
                prompt=obj, pos=pos,
                dist=hrp and (hrp.Position-pos).Magnitude or 9999,
                name=part.Name, priority=prio, tier=tier,
            })
        end
    end
    table.sort(results, function(a,b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.dist < b.dist
    end)
    return results
end

-- No Fog
local function enableNoFog()
    pcall(function()
        Lighting.FogStart = 0
        Lighting.FogEnd = 100000
        Lighting.FogColor = Color3.new(1,1,1)
    end)
end

local function disableNoFog()
    pcall(function()
        Lighting.FogStart = 0
        Lighting.FogEnd = 1000
    end)
end

-- Noclip (Bypass using CanCollide loop + PhysicsService)
local function enableNoclip()
    if noclipConnection then return end
    local function setNoclip(char)
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    noclipConnection = RunService.Stepped:Connect(function()
        local char = player.Character
        if char then setNoclip(char) end
    end)
end

local function disableNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    local char = player.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- Speed Boost (Bypass using BodyVelocity + spoofed WalkSpeed)
local function enableSpeedBoost()
    if speedConnection then return end
    speedConnection = RunService.Heartbeat:Connect(function()
        local char, hrp, hum = GetChar()
        if not char or not hrp or not hum then return end
        hum.WalkSpeed = 16
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0.1 then
            local bv = hrp:FindFirstChild("AZCSpeedBoost")
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "AZCSpeedBoost"
                bv.MaxForce = Vector3.new(400000, 0, 400000)
                bv.Parent = hrp
            end
            bv.Velocity = moveDir.Unit * speedBoostValue
        else
            local bv = hrp:FindFirstChild("AZCSpeedBoost")
            if bv then bv:Destroy() end
        end
    end)
end

local function disableSpeedBoost()
    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end
    local char, hrp, hum = GetChar()
    if hrp then
        local bv = hrp:FindFirstChild("AZCSpeedBoost")
        if bv then bv:Destroy() end
    end
    if hum then
        hum.WalkSpeed = originalWalkSpeed
    end
end

-- Jump Boost (Bypass using AssemblyLinearVelocity on Jumping event)
local function enableJumpBoost()
    if jumpConnection then return end
    local char, _, hum = GetChar()
    if hum then
        originalJumpPower = hum.JumpPower
        hum.JumpPower = 50
        jumpConnection = hum.Jumping:Connect(function(active)
            if not active then return end
            local _, hrp, _ = GetChar()
            if hrp then
                local jumpVelocity = math.sqrt(2 * Workspace.Gravity * jumpBoostValue)
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpVelocity, hrp.AssemblyLinearVelocity.Z)
            end
        end)
    end
end

local function disableJumpBoost()
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    local _, _, hum = GetChar()
    if hum then
        hum.JumpPower = originalJumpPower
    end
end

-- Save Position
local function saveCurrentPosition()
    local _, hrp, _ = GetChar()
    if hrp then
        savedPosition = hrp.CFrame
        return true
    end
    return false
end

local function getPositionString()
    if not savedPosition then return "No position saved" end
    local pos = savedPosition.Position
    return string.format("X: %.1f, Y: %.1f, Z: %.1f", pos.X, pos.Y, pos.Z)
end

-- Tween to saved position (uses stealTweenSpeed)
local function tweenToSavedPosition(customSpeed)
    if not savedPosition then return false end
    local _, hrp, _ = GetChar()
    if not hrp then return false end
    local speed = customSpeed or stealTweenSpeed or 0.5
    local tween = TweenService:Create(hrp, TweenInfo.new(speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = savedPosition})
    tween:Play()
    tween.Completed:Wait()
    return true
end

-- Fetch player list for dropdown
local function getPlayerNames()
    local names = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    return names
end

-- ============================================================
--  7. ANTI-LAG SYSTEM (Functions Only — No UI)
-- ============================================================
-- Extracted from Universal Anti-Lag script.
-- All properties are saved and fully restored on disable.

local antiLagConnections = {}
local antiLagChangedProps = {}
local antiLagDescendantConn = nil
local antiLagOldQualityLevel = nil
local antiLagOldSavedQualityLevel = nil

local function antiLagAddConnection(conn)
    table.insert(antiLagConnections, conn)
    return conn
end

local function antiLagSafeGet(instance, propertyName)
    local ok, value = pcall(function() return instance[propertyName] end)
    return ok and value or nil
end

local function antiLagSafeSet(instance, propertyName, value)
    pcall(function() instance[propertyName] = value end)
end

local function antiLagRememberProperty(instance, propertyName)
    if not instance then return end
    local data = antiLagChangedProps[instance]
    if not data then
        data = {}
        antiLagChangedProps[instance] = data
    end
    if data[propertyName] == nil then
        data[propertyName] = antiLagSafeGet(instance, propertyName)
    end
end

local function antiLagRememberAndSet(instance, propertyName, value)
    if not instance then return end
    antiLagRememberProperty(instance, propertyName)
    antiLagSafeSet(instance, propertyName, value)
end

local function antiLagShouldSkip(instance)
    if not instance then return true end
    local character = player.Character
    if character and instance:IsDescendantOf(character) then
        return true
    end
    return false
end

local function antiLagOptimizeInstance(instance)
    if antiLagShouldSkip(instance) then return end

    if instance:IsA("BasePart") then
        antiLagRememberAndSet(instance, "Material", Enum.Material.SmoothPlastic)
        antiLagRememberAndSet(instance, "Reflectance", 0)
        antiLagRememberAndSet(instance, "CastShadow", false)
        if instance:IsA("MeshPart") then
            antiLagRememberAndSet(instance, "RenderFidelity", Enum.RenderFidelity.Performance)
            antiLagRememberAndSet(instance, "TextureID", "")
        end
    elseif instance:IsA("Decal") or instance:IsA("Texture") then
        antiLagRememberAndSet(instance, "Transparency", 1)
    elseif instance:IsA("ParticleEmitter")
        or instance:IsA("Trail")
        or instance:IsA("Beam")
        or instance:IsA("Smoke")
        or instance:IsA("Fire")
        or instance:IsA("Sparkles") then
        antiLagRememberAndSet(instance, "Enabled", false)
    elseif instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
        antiLagRememberAndSet(instance, "Enabled", false)
    elseif instance:IsA("SpecialMesh") then
        antiLagRememberAndSet(instance, "TextureId", "")
    elseif instance:IsA("SurfaceAppearance") then
        antiLagRememberAndSet(instance, "ColorMap", "")
        antiLagRememberAndSet(instance, "MetalnessMap", "")
        antiLagRememberAndSet(instance, "NormalMap", "")
        antiLagRememberAndSet(instance, "RoughnessMap", "")
    end
end

local function antiLagOptimizeLighting()
    antiLagRememberAndSet(Lighting, "Technology", Enum.Technology.Compatibility)
    antiLagRememberAndSet(Lighting, "GlobalShadows", false)
    antiLagRememberAndSet(Lighting, "FogEnd", 1e9)
    antiLagRememberAndSet(Lighting, "ShadowSoftness", 0)

    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") then
            antiLagRememberAndSet(effect, "Enabled", false)
        elseif effect:IsA("Atmosphere") then
            antiLagRememberAndSet(effect, "Density", 0)
            antiLagRememberAndSet(effect, "Haze", 0)
            antiLagRememberAndSet(effect, "Glare", 0)
        elseif effect:IsA("Sky") then
            antiLagRememberAndSet(effect, "CelestialBodiesShown", false)
            antiLagRememberAndSet(effect, "StarCount", 0)
        end
    end
end

local function antiLagOptimizeTerrain()
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    antiLagRememberAndSet(terrain, "Decoration", false)
    antiLagRememberAndSet(terrain, "WaterWaveSize", 0)
    antiLagRememberAndSet(terrain, "WaterWaveSpeed", 0)
    antiLagRememberAndSet(terrain, "WaterReflectance", 0)
    antiLagRememberAndSet(terrain, "WaterTransparency", 1)
end

local function antiLagRestoreAllProperties()
    for instance, propertyData in pairs(antiLagChangedProps) do
        if instance and instance.Parent then
            for propertyName, oldValue in pairs(propertyData) do
                antiLagSafeSet(instance, propertyName, oldValue)
            end
        end
        antiLagChangedProps[instance] = nil
    end
end

local function antiLagSetLowestQuality()
    pcall(function()
        local rendering = settings().Rendering
        if antiLagOldQualityLevel == nil then
            antiLagOldQualityLevel = rendering.QualityLevel
        end
        rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        local userGameSettings = UserSettings():GetService("UserGameSettings")
        if antiLagOldSavedQualityLevel == nil then
            antiLagOldSavedQualityLevel = userGameSettings.SavedQualityLevel
        end
        userGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
end

local function antiLagRestoreQuality()
    if antiLagOldQualityLevel ~= nil then
        pcall(function()
            settings().Rendering.QualityLevel = antiLagOldQualityLevel
        end)
    end
    if antiLagOldSavedQualityLevel ~= nil then
        pcall(function()
            local userGameSettings = UserSettings():GetService("UserGameSettings")
            userGameSettings.SavedQualityLevel = antiLagOldSavedQualityLevel
        end)
    end
end

local function enableAntiLag()
    if enabledAntiLag then return end
    enabledAntiLag = true

    antiLagSetLowestQuality()
    antiLagOptimizeLighting()
    antiLagOptimizeTerrain()

    -- Optimize all existing workspace descendants
    for _, instance in ipairs(workspace:GetDescendants()) do
        antiLagOptimizeInstance(instance)
    end

    -- Hook new descendants so they get optimized too
    antiLagDescendantConn = antiLagAddConnection(
        workspace.DescendantAdded:Connect(function(instance)
            if enabledAntiLag then
                antiLagOptimizeInstance(instance)
            end
        end)
    )
end

local function disableAntiLag()
    if not enabledAntiLag then return end
    enabledAntiLag = false

    -- Disconnect the descendant hook
    if antiLagDescendantConn then
        pcall(function() antiLagDescendantConn:Disconnect() end)
        antiLagDescendantConn = nil
    end

    -- Restore everything
    antiLagRestoreAllProperties()
    antiLagRestoreQuality()
end

-- ============================================================
--  8. STOCK SCANNER
-- ============================================================
local function scanStock()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return "PlayerGui not found" end

    local shopFolder = pg:FindFirstChild("SeedShop")
    if not shopFolder then return "SeedShop not found - open the shop once" end

    local frame = shopFolder:FindFirstChild("Frame")
    if not frame then return "Shop Frame not found" end

    local normalShop = frame:FindFirstChild("NormalShop")
    if not normalShop then return "NormalShop not found" end

    local inStock = {}

    for _, seedName in pairs(validSeeds) do
        local seedItem = normalShop:FindFirstChild(seedName)
        if seedItem then
            local mainFrameObj = seedItem:FindFirstChild("Main_Frame")
            local stockTextLabel = mainFrameObj and mainFrameObj:FindFirstChild("Stock_Text")

            if stockTextLabel then
                local ok, rawText = pcall(function() return stockTextLabel.Text end)
                if ok and rawText then
                    local stockNum = string.match(rawText, "x(%d+)")
                    if stockNum and tonumber(stockNum) > 0 then
                        table.insert(inStock, seedName .. ": " .. rawText)
                    end
                end
            end
        end
    end

    stockScanTime = tick()

    if #inStock == 0 then
        return "No seeds in stock right now"
    end

    local result = table.concat(inStock, "\n")
    return result
end

-- ============================================================
--  9. ANTI-FLING SYSTEM
-- ============================================================
local function enableAntiFling()
    if antiFlingConn then return end

    local function disableCollisions(char)
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.Massless = true
            end
        end
    end

    if player.Character then
        disableCollisions(player.Character)
    end

    antiFlingConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        char:WaitForChild("HumanoidRootPart", 10)
        disableCollisions(char)
        char.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") then
                desc.CanCollide = false
                desc.Massless = true
            end
        end)
    end)

    task.spawn(function()
        while enabledAntiFling do
            task.wait(1)
            if player.Character then
                disableCollisions(player.Character)
            end
        end
    end)
end

local function disableAntiFling()
    if antiFlingConn then
        antiFlingConn:Disconnect()
        antiFlingConn = nil
    end
    local char = player.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                part.Massless = false
            end
        end
    end
end

-- ============================================================
--  10. DEFENSE SYSTEM
-- ============================================================
local function checkForRetrieved()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, d in pairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            if d.Visible then
                local ok, v = pcall(function() return d.Text end)
                if ok and v and type(v) == "string" and v:lower():find("retrieved") then
                    return true
                end
            end
        end
    end
    return false
end

local function startDefenseWatch()
    local pg = player:WaitForChild("PlayerGui")
    local function checkForThief(txt)
        if txt:lower():find("stealing from you") then
            local name = txt:match("^(.-)%s+[Ii]s stealing")
            if name and name ~= "" then
                lastThief = name
                lastThiefTime = tick()
                retrievedDetected = false
            end
        end
    end
    pg.DescendantAdded:Connect(function(d)
        task.wait(0.05)
        if not enabledDefense then return end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local ok, v = pcall(function() return d.Text end)
            if ok then checkForThief(v) end
        end
    end)
    task.spawn(function()
        while true do
            task.wait(0.25)
            if not enabledDefense then continue end
            local pg2 = player:FindFirstChild("PlayerGui")
            if not pg2 then continue end
            for _, d in pairs(pg2:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local ok, v = pcall(function() return d.Text end)
                    if ok and type(v) == "string" then
                        checkForThief(v)
                        if v:lower():find("retrieved") and d.Visible then
                            retrievedDetected = true
                        end
                    end
                end
            end
        end
    end)
end

-- Main defense chase loop
task.spawn(function()
    startDefenseWatch()
    while true do
        task.wait(0.1)
        if not enabledDefense then continue end
        if not lastThief or tick() - lastThiefTime > 10 then continue end

        local tp = Players:FindFirstChild(lastThief)
        if not tp then
            for _, p in pairs(Players:GetPlayers()) do
                if p.Name:lower():find(lastThief:lower()) then tp = p break end
            end
        end
        if not tp or tp == player then continue end

        local tc = tp.Character
        if not tc then continue end
        local th = tc:FindFirstChild("HumanoidRootPart")
        if not th then continue end

        local char = player.Character
        if not char then continue end
        local mh = char:FindFirstChild("HumanoidRootPart")
        if not mh then continue end

        equipShovel()
        retrievedDetected = false
        defenseActive = true

        local chaseStart = tick()
        while enabledDefense and tick() - chaseStart < 20 and not retrievedDetected do
            local thiefChar = tp.Character
            if not thiefChar then break end
            local thiefHRP = thiefChar:FindFirstChild("HumanoidRootPart")
            if not thiefHRP then break end
            local myChar = player.Character
            if not myChar then break end
            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
            if not myHRP then break end

            -- TP BEHIND the stealer (opposite of their LookVector) and face them
            local behindPos = thiefHRP.Position - thiefHRP.LookVector * 2.5
            pcall(function() myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
            pcall(function() myHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end)
            myHRP.CFrame = CFrame.lookAt(behindPos, thiefHRP.Position)

            equipShovel()
            -- Spam M1 multiple times for maximum hits per tick
            clickM1()
            clickM1()
            clickM1()
            task.wait(0.02)

            if checkForRetrieved() then
                retrievedDetected = true
                break
            end
        end

        if retrievedDetected then task.wait(0.3) end

        defenseActive = false
        lastThief = nil
        lastThiefTime = 0
        retrievedDetected = false
    end
end)

-- ============================================================
--  11. AUTO EXPAND GARDEN
-- ============================================================
task.spawn(function()
    while true do
        if enabledAutoExpand then
            local ok, PacketModule = pcall(function()
                return require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"))
            end)
            if ok and PacketModule then
                local ExpandPacket = PacketModule("ExpandGarden")
                if ExpandPacket then
                    pcall(function() ExpandPacket:Fire() end)
                end
            end
            task.wait(0.5)
        else
            task.wait(1)
        end
    end
end)

-- ============================================================
--  12. AUTO HARVEST (TURBO — max speed, minimal waits)
-- ============================================================
-- Stripped-down loop for maximum speed:
--   - 0.01s loop rate (was 0.3s — 30x faster polling)
--   - No separate prompt collection table (saves one full iteration)
--   - Direct CFrame + fireproximityprompt with zero waits inside
--   - Uses HarvestObject for plants with proper structure
--   - Falls back to raw teleport + fire for edge cases
--   - Sell-when-full check after every single harvest
task.spawn(function()
    while true do
        if enabledHarvest then
            -- Find / re-find plot every 15s
            if not myPlot or tick() - myPlotLastCheck > 15 then
                local gardens = workspace:FindFirstChild("Gardens")
                if gardens then
                    -- Method 1: PlotId attribute (fastest)
                    local plotId = player:GetAttribute("PlotId")
                    if plotId then
                        myPlot = gardens:FindFirstChild("Plot" .. tostring(plotId))
                    end
                    -- Method 2: OwnerSign text match (handles @username format)
                    if not myPlot then
                        local lowerName = player.Name:lower()
                        for _, plot in pairs(gardens:GetChildren()) do
                            local ownerSign = plot:FindFirstChild("OwnerSign", true)
                            if ownerSign and ownerSign:IsA("BasePart") then
                                local lbl = ownerSign:FindFirstChildWhichIsA("TextLabel", true)
                                    or ownerSign:FindFirstChildWhichIsA("SurfaceGui", true)
                                local txt = lbl and lbl:IsA("TextLabel") and lbl.Text
                                if not txt then
                                    for _, d in pairs(ownerSign:GetDescendants()) do
                                        if d:IsA("TextLabel") then txt = d.Text break end
                                    end
                                end
                                if txt and txt:lower():find(lowerName, 1, true) then
                                    myPlot = plot
                                    break
                                end
                            end
                            if not myPlot then
                                -- Fallback: scan all TextLabels in Signs folder
                                local signs = plot:FindFirstChild("Signs")
                                if signs then
                                    for _, d in pairs(signs:GetDescendants()) do
                                        if d:IsA("TextLabel") then
                                            local t = d.Text:lower()
                                            -- Match "playername", "@playername", "playername's"
                                            if t:find(lowerName, 1, true) then
                                                myPlot = plot
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            if myPlot then break end
                        end
                    end
                end
                if myPlot then
                    myPlotLastCheck = tick()
                else
                    task.wait(2) continue
                end
            end

            -- Validate plot still exists in workspace
            if not myPlot or not myPlot.Parent then
                myPlot = nil
                myPlotLastCheck = 0
                continue
            end

            local myChar = player.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHRP then
                -- Single pass: find and harvest immediately, no table buildup
                for _, obj in pairs(myPlot:GetDescendants()) do
                    if not enabledHarvest then break end
                    if not obj:IsA("ProximityPrompt") then continue end
                    if not obj.Enabled then continue end
                    if not obj.Parent then continue end

                    -- Only harvest prompts
                    local isHarvest = obj.Name == "HarvestPrompt"
                        or (obj.ActionText and obj.ActionText:lower():find("harvest"))
                        or (obj.ObjectText and obj.ObjectText:lower():find("harvest"))
                    if not isHarvest then continue end

                    -- Apply seed / mutation filters (read plant attributes)
                    local _, pSeedName, pMutation = FindPlantFromPrompt(obj)
                    if enabledHarvestSeedFilter then
                        -- Only harvest if the plant's SeedName is in the whitelist
                        if not pSeedName or not selectedHarvestSeeds[pSeedName] then
                            continue
                        end
                    end
                    if enabledHarvestMutationFilter then
                        -- Only harvest if the plant's Mutation is in the whitelist
                        if not pMutation or not selectedHarvestMutations[pMutation] then
                            continue
                        end
                    end

                    local part = obj.Parent

                    -- Try HarvestObject on the plant model
                    local plantObj = part.Parent
                    if plantObj and plantObj.Parent then
                        if HarvestObject(plantObj, myHRP) then
                            if enabledSellWhenFull and isInventoryFull() then
                                sellAll()
                                task.wait(0.5)
                            end
                            continue
                        end
                    end

                    -- Raw turbo fallback: instant teleport + fire, zero extra waits
                    if part:IsA("BasePart") then
                        local dist = obj.MaxActivationDistance
                        obj.MaxActivationDistance = 9999
                        myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        myHRP.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                        pcall(function() fireproximityprompt(obj) end)
                        task.wait(0.01)
                        obj.MaxActivationDistance = dist

                        if enabledSellWhenFull and isInventoryFull() then
                            sellAll()
                            task.wait(0.5)
                        end
                    end
                end
            end
        end
        task.wait(0.01)
    end
end)

-- Auto Daily Deal loop
task.spawn(function()
    while true do
        if enabledAutoDailyDeal then
            pcall(SellDailyDeal)
            task.wait(5)
        else
            task.wait(1)
        end
    end
end)

-- Auto Steal loop
task.spawn(function()
    while true do
        if enabledSteal then
            -- Auto-save current position if none saved (so we can return to it)
            if not savedPosition then
                saveCurrentPosition()
            end

            local results = FindStealPrompts()
            local myChar = player.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHRP and #results > 0 then
                -- Steal only ONE fruit per cycle, then tween back to saved position
                for _, entry in ipairs(results) do
                    if not enabledSteal then break end
                    if not entry.prompt or not entry.prompt.Parent or not entry.prompt.Enabled then continue end

                    local targetPart = entry.prompt.Parent
                    if targetPart and targetPart:IsA("BasePart") then
                        pcall(function() myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
                        myHRP.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
                        task.wait(0.1)
                        pcall(function() fireproximityprompt(entry.prompt) end)
                        task.wait(0.15)

                        -- Tween back to saved position after stealing ONE fruit
                        if savedPosition then
                            tweenToSavedPosition()
                        end
                        break -- Only steal one fruit per cycle, then return
                    end
                end
            end
        end
        task.wait(1)
    end
end)

-- Auto Buy Seeds loop
task.spawn(function()
    while true do
        if enabledAutoBuy then
            local PacketModule = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Packet"))
            for seedName, _ in pairs(selectedSeeds) do
                local SeedPacket = PacketModule("PurchaseSeed")
                if SeedPacket then
                    SeedPacket:Fire(seedName)
                end
                task.wait(0.1)
            end
        end
        task.wait(1)
    end
end)

-- Auto Buy Gears loop
task.spawn(function()
    while true do
        if enabledAutoGear then
            local PacketModule = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Packet"))
            for gearName, _ in pairs(selectedGears) do
                local GearPacket = PacketModule("PurchaseGear")
                if GearPacket then
                    GearPacket:Fire(gearName)
                end
                task.wait(0.1)
            end
        end
        task.wait(1)
    end
end)

-- Auto Buy Pets loop
task.spawn(function()
    while true do
        if enabledAutoPet then
            local PacketModule = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Packet"))
            for petName, _ in pairs(selectedPets) do
                local PetPacket = PacketModule("PurchasePet")
                if PetPacket then
                    PetPacket:Fire(petName)
                end
                task.wait(0.1)
            end
        end
        task.wait(1)
    end
end)

-- Auto Sell timer loop
task.spawn(function()
    while true do
        if enabledAutoSell then
            sellAll()
            task.wait(autoSellDelay)
        else
            task.wait(1)
        end
    end
end)

-- Sell When Full check loop
task.spawn(function()
    while true do
        task.wait(0.5)
        if enabledSellWhenFull and isInventoryFull() then
            if not enabledHarvest and not enabledSteal then
                sellAll()
                task.wait(1)
            end
        end
    end
end)

-- Auto Plant loop: when enabled, sweeps the plot every 2 seconds and plants
-- selected seeds in free spots. Skips a sweep if character / tool isn't ready.
task.spawn(function()
    while true do
        if enabledAutoPlant then
            pcall(autoPlantOnce)
            task.wait(2)
        else
            task.wait(1)
        end
    end
end)

-- Stock restock detection loop
task.spawn(function()
    local pg = player:WaitForChild("PlayerGui")
    while true do
        task.wait(2)
        local function scanTexts()
            for _, d in pairs(pg:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local ok, v = pcall(function() return d.Text end)
                    if ok and type(v) == "string" then
                        local lower = v:lower()
                        if lower:find("stock has reset") or lower:find("restocked") or lower:find("shop restock") then
                            return true
                        end
                    end
                end
            end
            return false
        end
        if scanTexts() then
            stockLastScan = scanStock()
        end
    end
end)

-- ============================================================
--  13. DAY/NIGHT CHECK
-- ============================================================
local function IsNight()
    local t = tonumber(string.sub(Lighting.TimeOfDay, 1, 2))
    return t and (t >= 18 or t < 6)
end

-- ============================================================
--  14. AUTO COLLECT DROPPED SEED PACKS (SeedPack / Gold / Rainbow)
-- ============================================================
local function AutoCollectSeedPacks()
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    local sl = map:FindFirstChild("SeedPackSpawnServerLocations")
    if not sl then return end
    GetChar()
    if not RootPart then return end
    for _, part in ipairs(sl:GetChildren()) do
        if not _G.AutoCollectSeeds then break end
        if part:IsA("BasePart") and (part:GetAttribute("SeedPack") or part:GetAttribute("RainbowSeed") or part:GetAttribute("GoldSeed")) then
            TP(part.Position)
            task.wait(0.2)
            for _, d in pairs(part:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    FirePrompt(d)
                elseif d:IsA("ClickDetector") then
                    pcall(function() fireclickdetector(d) end)
                end
            end
            task.wait(0.3)
        end
    end
end

local autoCollectLoopThread = nil

local function startAutoCollect()
    if autoCollectLoopThread then return end
    _G.AutoCollectSeeds = true
    -- Hook new seeds as they spawn (instant pickup)
    pcall(function()
        local map = workspace:WaitForChild("Map", 10)
        local serverLocs = map and map:WaitForChild("SeedPackSpawnServerLocations", 10)
        if serverLocs then
            autoCollectConn = serverLocs.ChildAdded:Connect(function(child)
                if _G.AutoCollectSeeds and child:IsA("BasePart") then
                    task.spawn(function()
                        if child:GetAttribute("SeedPack") or child:GetAttribute("RainbowSeed") or child:GetAttribute("GoldSeed") then
                            GetChar()
                            if not RootPart then return end
                            TP(child.Position)
                            task.wait(0.2)
                            for _, d in pairs(child:GetDescendants()) do
                                if d:IsA("ProximityPrompt") then FirePrompt(d)
                                elseif d:IsA("ClickDetector") then pcall(function() fireclickdetector(d) end) end
                            end
                            task.wait(0.3)
                        end
                    end)
                end
            end)
        end
    end)
    -- Periodic full sweep loop
    autoCollectLoopThread = task.spawn(function()
        while _G.AutoCollectSeeds do
            pcall(AutoCollectSeedPacks)
            task.wait(0.5)
        end
    end)
end

local function stopAutoCollect()
    _G.AutoCollectSeeds = false
    if autoCollectConn then
        pcall(function() autoCollectConn:Disconnect() end)
        autoCollectConn = nil
    end
    autoCollectLoopThread = nil
end

-- Stats overlay
task.spawn(function()
    local sg = Instance.new("ScreenGui")
    sg.Name = "AZCStats"
    sg.ResetOnSpawn = false
    sg.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 82)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.BackgroundTransparency = 0.25
    frame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local moneyLabel = Instance.new("TextLabel")
    moneyLabel.Size = UDim2.new(1, 0, 0, 24)
    moneyLabel.Position = UDim2.new(0, 10, 0, 4)
    moneyLabel.BackgroundTransparency = 1
    moneyLabel.Font = Enum.Font.GothamBold
    moneyLabel.TextSize = 14
    moneyLabel.TextColor3 = Color3.fromRGB(130, 255, 130)
    moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
    moneyLabel.Parent = frame

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Size = UDim2.new(1, 0, 0, 20)
    timeLabel.Position = UDim2.new(0, 10, 0, 28)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 12
    timeLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    timeLabel.TextXAlignment = Enum.TextXAlignment.Left
    timeLabel.Parent = frame

    local dayNightLabel = Instance.new("TextLabel")
    dayNightLabel.Size = UDim2.new(1, 0, 0, 20)
    dayNightLabel.Position = UDim2.new(0, 10, 0, 48)
    dayNightLabel.BackgroundTransparency = 1
    dayNightLabel.Font = Enum.Font.GothamBold
    dayNightLabel.TextSize = 13
    dayNightLabel.TextXAlignment = Enum.TextXAlignment.Left
    dayNightLabel.Parent = frame

    while true do
        task.wait(0.5)
        pcall(function()
            moneyLabel.Text = "Sheckles: " .. tostring(getMoney())
            local elapsed = tick() - statsStartTime
            local h = math.floor(elapsed / 3600)
            local m = math.floor((elapsed % 3600) / 60)
            local s = math.floor(elapsed % 60)
            timeLabel.Text = string.format("Time: %02d:%02d:%02d | Harvested: %d", h, m, s, sessionItemsHarvested or 0)

            if IsNight() then
                dayNightLabel.Text = "Night"
                dayNightLabel.TextColor3 = Color3.fromRGB(130, 160, 255)
            else
                dayNightLabel.Text = "Day"
                dayNightLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
            end
        end)
    end
end)

-- ============================================================
--  12. STOCK PANEL
-- ============================================================
task.spawn(function()
    local sg = player:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AZCStockPanel"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.Parent = sg

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 200, 0, 300)
    main.Position = UDim2.new(1, -210, 0, 10)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    main.BackgroundTransparency = 0.2
    main.Active = true
    main.Draggable = true
    main.Parent = screenGui

    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 8)
    mc.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(34, 137, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Text = "Seed Stock"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Parent = main

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 8)
    tc.Parent = title

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -40)
    scroll.Position = UDim2.new(0, 5, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = main

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 2)
    list.Parent = scroll

    local function refreshPanel()
        for _, c in pairs(scroll:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        local text = stockLastScan
        local lines = {}
        for line in text:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        for _, line in ipairs(lines) do
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 20)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 12
            lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = line
            lbl.Parent = scroll
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, #lines * 22)
    end

    task.spawn(function()
        while true do
            task.wait(1)
            if screenGui.Enabled then
                refreshPanel()
            end
        end
    end)

    local meta = {}
    meta.__index = meta
    function meta:Toggle()
        screenGui.Enabled = not screenGui.Enabled
    end
    if type(getgenv) == "function" then
        getgenv().AZCStockPanel = setmetatable({}, meta)
    else
        _G.AZCStockPanel = setmetatable({}, meta)
    end
end)


-- ============================================================
--  FLUENT UI SETUP - ZOEX HUB (FluentPro by StyearX)
-- ============================================================
local Fluent = loadstring(game:HttpGet("https://github.com/StyearX/Fluent-modded/releases/download/1.5.1/FluentPro"))()

local LocalPlayer = Players.LocalPlayer
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

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
    Home    = Window:AddTab({ Title = "Home",    Icon = "solar/home-2-bold" }),
    Harvest = Window:AddTab({ Title = "Harvest", Icon = "solar/leaf-bold" }),
    Steal   = Window:AddTab({ Title = "Steal",   Icon = "solar/user-hand-up-bold" }),
    Shop    = Window:AddTab({ Title = "Shop",    Icon = "solar/cart-large-bold" }),
    Defense = Window:AddTab({ Title = "Defense", Icon = "solar/shield-check-bold" }),
    Sell    = Window:AddTab({ Title = "Sell",    Icon = "solar/dollar-minimalistic-bold" }),
    Events  = Window:AddTab({ Title = "Events",  Icon = "solar/star-bold" }),
    Misc    = Window:AddTab({ Title = "Misc",    Icon = "solar/settings-bold" }),
    Extra   = Window:AddTab({ Title = "Extra",   Icon = "solar/widget-add-bold" }),
    Config  = Window:AddTab({ Title = "Config",  Icon = "solar/floppy-disk-bold" }),
}

-- helper: turn a Fluent multi-select table into a { name = name } set
local function toNameSet(Selected)
    local set = {}
    if type(Selected) == "table" then
        for name, active in pairs(Selected) do
            if active then
                if type(name) == "number" then
                    set[active] = active
                else
                    set[name] = name
                end
            end
        end
    end
    return set
end

-- ============================================================
--  TAB: HOME
-- ============================================================
local secHome = Tabs.Home:AddSection("Ron Hub", "solar/crown-bold")

secHome:AddParagraph({
    Title = "˚ 🎩 . ᵎRon Communityᵎ .",
    Content = "رون كميونتي - سيرفر عربي متخصص في برمجة ونشر سكربتات روبلوكس .",
})

secHome:AddDiscord({
    InviteCode = "NrxsCzbPS4",
})

secHome:AddButton({
    Title = "Copy Discord Invite",
    Description = "https://discord.gg/NrxsCzbPS4",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/NrxsCzbPS4")
            Fluent:Notify({ Title = "Ron Hub", Content = "Invite copied to clipboard", Type = "Success", Duration = 3 })
        end
    end,
})

-- ============================================================
--  TAB: HARVEST
-- ============================================================
local secAutoFarm = Tabs.Harvest:AddSection("Auto Farm", "solar/refresh-bold")

secAutoFarm:AddToggle("AutoHarvest", {
    Title = "Auto Harvest",
    Description = "Automatically harvest your crops",
    Default = false,
    Callback = function(Value)
        enabledHarvest = Value
        if not enabledHarvest then myPlot = nil end
    end,
})

local secSeedFilter = Tabs.Harvest:AddSection("Seed Filter", "solar/filter-bold")

secSeedFilter:AddToggle("HarvestSeedFilter", {
    Title = "Enable Seed Filter",
    Description = "Only harvest selected seeds",
    Default = false,
    Callback = function(Value)
        enabledHarvestSeedFilter = Value
    end,
})

secSeedFilter:AddDropdown("SelectedHarvestSeeds", {
    Title = "Seeds to Harvest",
    Description = "Select which seeds to harvest",
    Values = allSeeds,
    Multi = true,
    Default = {},
    Callback = function(Selected)
        selectedHarvestSeeds = toNameSet(Selected)
    end,
})

local secMutationFilter = Tabs.Harvest:AddSection("Mutation Filter", "solar/magic-stick-3-bold")

secMutationFilter:AddToggle("HarvestMutationFilter", {
    Title = "Enable Mutation Filter",
    Description = "Only harvest selected mutations",
    Default = false,
    Callback = function(Value)
        enabledHarvestMutationFilter = Value
    end,
})

secMutationFilter:AddDropdown("SelectedHarvestMutations", {
    Title = "Mutations to Harvest",
    Description = "Select which mutations to harvest",
    Values = { "Gold", "Rainbow", "Electric", "Frozen", "Bloodlit", "Starstruck", "Shocked", "Chained", "Solarflare", "Pizza" },
    Multi = true,
    Default = {},
    Callback = function(Selected)
        selectedHarvestMutations = toNameSet(Selected)
    end,
})

local secGarden = Tabs.Harvest:AddSection("Garden", "solar/tree-bold")

secGarden:AddToggle("AutoExpandGarden", {
    Title = "Auto Expand Garden",
    Description = "Automatically expand your garden",
    Default = false,
    Callback = function(Value)
        enabledAutoExpand = Value
    end,
})

local secAutoPlant = Tabs.Harvest:AddSection("Auto Plant", "solar/bag-4-bold")

secAutoPlant:AddDropdown("SelectedPlantSeeds", {
    Title = "Seeds to Plant",
    Description = "Select which seeds to auto-plant",
    Values = allSeeds,
    Multi = true,
    Default = {},
    Callback = function(Selected)
        selectedPlantSeeds = toNameSet(Selected)
    end,
})

secAutoPlant:AddToggle("AutoPlant", {
    Title = "Auto Plant",
    Description = "Automatically plant selected seeds",
    Default = false,
    Callback = function(Value)
        enabledAutoPlant = Value
    end,
})

secAutoPlant:AddSlider("AutoPlantMaxPerSweep", {
    Title = "Max Plants Per Sweep",
    Description = "Maximum plants placed per sweep",
    Min = 1,
    Max = 60,
    Default = 30,
    Rounding = 0,
    Callback = function(Value)
        autoPlantMaxPerSweep = math.floor(Value)
    end,
})

-- ============================================================
--  TAB: STEAL
-- ============================================================
local secAutoSteal = Tabs.Steal:AddSection("Auto Steal", "solar/hand-stars-bold")

secAutoSteal:AddToggle("AutoSteal", {
    Title = "Auto Steal",
    Description = "Automatically steal from other players",
    Default = false,
    Callback = function(Value)
        enabledSteal = Value
    end,
})

secAutoSteal:AddSlider("StealTweenSpeed", {
    Title = "Tween Speed (seconds)",
    Description = "Speed of movement when stealing",
    Min = 1,
    Max = 30,
    Default = 5,
    Rounding = 0,
    Callback = function(Value)
        stealTweenSpeed = Value / 10
    end,
})

local playerNames = getPlayerNames()
local StealTargetDropdown = secAutoSteal:AddDropdown("StealTargetPlayer", {
    Title = "Target Player",
    Description = "Select the player to steal from",
    Values = playerNames,
    Multi = false,
    Default = playerNames[1],
    Callback = function(Value)
        stealTargetPlayer = Value
    end,
})

secAutoSteal:AddButton({
    Title = "Refresh Player List",
    Description = "Update the list of players",
    Callback = function()
        local names = getPlayerNames()
        pcall(function()
            StealTargetDropdown:SetValues(names)
        end)
        Fluent:Notify({ Title = "Steal", Content = "Player list refreshed", Type = "Success", Duration = 2 })
    end,
})

local secPosition = Tabs.Steal:AddSection("Position", "solar/map-point-bold")

secPosition:AddButton({
    Title = "Save Current Position",
    Description = "Save your current position to return to",
    Callback = function()
        saveCurrentPosition()
    end,
})

local secMovement = Tabs.Steal:AddSection("Movement", "solar/running-bold")

secMovement:AddToggle("Noclip", {
    Title = "Noclip",
    Description = "Walk through walls",
    Default = false,
    Callback = function(Value)
        enabledNoclip = Value
        if Value then enableNoclip() else disableNoclip() end
    end,
})

secMovement:AddToggle("SpeedBoost", {
    Title = "Speed Boost",
    Description = "Move faster than normal",
    Default = false,
    Callback = function(Value)
        enabledSpeedBoost = Value
        if Value then enableSpeedBoost() else disableSpeedBoost() end
    end,
})

secMovement:AddSlider("SpeedBoostValue", {
    Title = "Speed Value",
    Description = "Speed boost amount",
    Min = 20,
    Max = 200,
    Default = 50,
    Rounding = 0,
    Callback = function(Value)
        speedBoostValue = Value
    end,
})

secMovement:AddToggle("JumpBoost", {
    Title = "Jump Boost",
    Description = "Jump higher than normal",
    Default = false,
    Callback = function(Value)
        enabledJumpBoost = Value
        if Value then enableJumpBoost() else disableJumpBoost() end
    end,
})

secMovement:AddSlider("JumpBoostValue", {
    Title = "Jump Value",
    Description = "Jump boost amount",
    Min = 50,
    Max = 500,
    Default = 100,
    Rounding = 0,
    Callback = function(Value)
        jumpBoostValue = Value
    end,
})

-- ============================================================
--  TAB: SHOP
-- ============================================================
local secSeeds = Tabs.Shop:AddSection("Seeds", "solar/bag-smile-bold")

secSeeds:AddDropdown("SelectedSeeds", {
    Title = "Select Seeds",
    Description = "Choose seeds to auto-buy",
    Values = allSeeds,
    Multi = true,
    Default = {},
    Callback = function(Selected)
        selectedSeeds = toNameSet(Selected)
    end,
})

secSeeds:AddToggle("AutoBuySeeds", {
    Title = "Auto Buy Seeds",
    Description = "Automatically purchase selected seeds",
    Default = false,
    Callback = function(Value)
        enabledAutoBuy = Value
    end,
})

local secGear = Tabs.Shop:AddSection("Gear", "solar/shovel-bold")

secGear:AddDropdown("SelectedGears", {
    Title = "Select Gear",
    Description = "Choose gear to auto-buy",
    Values = allGears,
    Multi = true,
    Default = {},
    Callback = function(Selected)
        selectedGears = toNameSet(Selected)
    end,
})

secGear:AddToggle("AutoBuyGears", {
    Title = "Auto Buy Gear",
    Description = "Automatically purchase selected gear",
    Default = false,
    Callback = function(Value)
        enabledAutoGear = Value
    end,
})

local secPets = Tabs.Shop:AddSection("Pets", "solar/cat-bold")

secPets:AddDropdown("SelectedPets", {
    Title = "Select Pets",
    Description = "Choose pets to auto-buy",
    Values = allWildPets,
    Multi = true,
    Default = {},
    Callback = function(Selected)
        selectedPets = toNameSet(Selected)
    end,
})

secPets:AddToggle("AutoBuyPets", {
    Title = "Auto Buy Pets",
    Description = "Automatically purchase selected pets",
    Default = false,
    Callback = function(Value)
        enabledAutoPet = Value
    end,
})

local secStock = Tabs.Shop:AddSection("Stock Monitor", "solar/chart-2-bold")

secStock:AddButton({
    Title = "Toggle Stock Panel",
    Description = "Show or hide the seed stock panel",
    Callback = function()
        local panel = nil
        if type(getgenv) == "function" then
            panel = getgenv().AZCStockPanel
        else
            panel = _G.AZCStockPanel
        end
        if panel then panel:Toggle() end
    end,
})

-- ============================================================
--  TAB: DEFENSE
-- ============================================================
local secFarmProtection = Tabs.Defense:AddSection("Farm Protection", "solar/shield-warning-bold")

secFarmProtection:AddToggle("FarmDefense", {
    Title = "Farm Defense",
    Description = "Automatically chase and attack thieves",
    Default = false,
    Callback = function(Value)
        enabledDefense = Value
        if not Value then
            lastThief = nil
            lastThiefTime = 0
            defenseActive = false
            retrievedDetected = false
        end
    end,
})

local secAntiFling = Tabs.Defense:AddSection("Anti-Fling", "solar/wind-bold")

secAntiFling:AddToggle("AntiFling", {
    Title = "Anti-Fling",
    Description = "Prevent being flung by other players",
    Default = false,
    Callback = function(Value)
        enabledAntiFling = Value
        if Value then enableAntiFling() else disableAntiFling() end
    end,
})

-- ============================================================
--  TAB: SELL
-- ============================================================
local secAutoSell = Tabs.Sell:AddSection("Auto Sell", "solar/dollar-bold")

secAutoSell:AddToggle("AutoSell", {
    Title = "Auto Sell",
    Description = "Automatically sell all crops on a timer",
    Default = false,
    Callback = function(Value)
        enabledAutoSell = Value
    end,
})

secAutoSell:AddSlider("AutoSellDelay", {
    Title = "Sell Delay (seconds)",
    Description = "How often to auto sell",
    Min = 1,
    Max = 60,
    Default = 5,
    Rounding = 0,
    Callback = function(Value)
        autoSellDelay = Value
    end,
})

local secSmartSell = Tabs.Sell:AddSection("Smart Sell", "solar/box-bold")

secSmartSell:AddToggle("SellWhenFull", {
    Title = "Sell When Inventory Full",
    Description = "Auto sell when your inventory fills up",
    Default = false,
    Callback = function(Value)
        enabledSellWhenFull = Value
    end,
})

local secQuickActions = Tabs.Sell:AddSection("Quick Actions", "solar/bolt-bold")

secQuickActions:AddButton({
    Title = "Sell All Now",
    Description = "Instantly sell everything in your inventory",
    Callback = function()
        sellAll()
    end,
})

secQuickActions:AddButton({
    Title = "Use Daily Deal Now",
    Description = "Instantly use the daily deal",
    Callback = function()
        pcall(SellDailyDeal)
    end,
})

local secDailyDeal = Tabs.Sell:AddSection("Auto Daily Deal", "solar/calendar-bold")

secDailyDeal:AddToggle("AutoDailyDeal", {
    Title = "Auto Daily Deal",
    Description = "Automatically use the daily deal",
    Default = false,
    Callback = function(Value)
        enabledAutoDailyDeal = Value
    end,
})

-- ============================================================
--  TAB: EVENTS
-- ============================================================
local secAutoCollect = Tabs.Events:AddSection("Auto Collect", "solar/gift-bold")

secAutoCollect:AddToggle("AutoCollectSeeds", {
    Title = "Auto Collect Dropped Seeds",
    Description = "Automatically collect Gold and Rainbow seed drops",
    Default = false,
    Callback = function(Value)
        enabledAutoCollect = Value
        if Value then
            startAutoCollect()
        else
            stopAutoCollect()
        end
    end,
})

-- ============================================================
--  TAB: MISC
-- ============================================================
local secPerformance = Tabs.Misc:AddSection("Performance", "solar/speedometer-max-bold")

secPerformance:AddToggle("AntiLag", {
    Title = "Anti-Lag",
    Description = "Reduce lag by lowering graphics quality",
    Default = false,
    Callback = function(Value)
        if Value then enableAntiLag() else disableAntiLag() end
    end,
})

local secVisuals = Tabs.Misc:AddSection("Visuals", "solar/eye-bold")

secVisuals:AddToggle("NoFog", {
    Title = "No Fog",
    Description = "Remove fog from the game",
    Default = false,
    Callback = function(Value)
        enabledNoFog = Value
        if Value then enableNoFog() else disableNoFog() end
    end,
})

-- ============================================================
--  TAB: EXTRA
-- ============================================================
local secMoney = Tabs.Extra:AddSection("Money", "solar/wallet-money-bold")

secMoney:AddInput("ShecklesAmount", {
    Title = "Sheckles Amount",
    Description = "Amount used by the Set Money button",
    Default = "",
    Placeholder = "Enter amount (e.g. 1000000000)",
    Callback = function(Value)
        shecklesAmount = Value
    end,
})

secMoney:AddButton({
    Title = "Set Money",
    Description = "Set your Sheckles to the entered amount",
    Callback = function()
        local num = tonumber(shecklesAmount)
        if not num then
            Fluent:Notify({ Title = "Money", Content = "Enter a valid number first", Type = "Warning", Duration = 3 })
            return
        end
        local done = false
        local ls = player:FindFirstChild("leaderstats")
        if ls then
            local s = ls:FindFirstChild("Sheckles")
            if s then s.Value = num done = true end
            if not done then
                for _, name in pairs({"sheckles","Money","money","Cash","cash","Coins","coins"}) do
                    local s2 = ls:FindFirstChild(name)
                    if s2 then s2.Value = num done = true break end
                end
            end
            if not done then
                for _, c in pairs(ls:GetChildren()) do
                    if c:IsA("IntValue") or c:IsA("NumberValue") then
                        c.Value = num done = true break
                    end
                end
            end
        end
        if not done then
            for _, v in ipairs(player:GetDescendants()) do
                if (v:IsA("IntValue") or v:IsA("NumberValue")) and (
                    v.Name:lower():find("sheckle") or v.Name:lower():find("money") or
                    v.Name:lower():find("cash") or v.Name:lower():find("coin")
                ) then
                    v.Value = num done = true break
                end
            end
        end
        Fluent:Notify({
            Title = "Money",
            Content = done and "Value updated locally" or "No matching value found",
            Type = done and "Success" or "Error",
            Duration = 3,
        })
    end,
})

-- ============================================================
--  CONFIG / INTERFACE MANAGERS (persist toggle/slider flags)
-- ============================================================
pcall(function()
    local SaveManager = Fluent.SaveManager or (type(getgenv) == "function" and getgenv().SaveManager)
    local InterfaceManager = Fluent.InterfaceManager or (type(getgenv) == "function" and getgenv().InterfaceManager)
    local MediaManager = Fluent.MediaManager or (type(getgenv) == "function" and getgenv().MediaManager)

    if MediaManager then
        MediaManager:SetFolder("ZoexHub/MediaCache")
    end

    if InterfaceManager then
        InterfaceManager:SetLibrary(Fluent)
        InterfaceManager:SetFolder("ZoexHub")
        InterfaceManager:BuildInterfaceSection(Tabs.Config)
        InterfaceManager:LoadSettings()
    end

    if SaveManager then
        SaveManager:SetLibrary(Fluent)
        SaveManager:SetFolder("ZoexHub/Config")
        SaveManager:IgnoreThemeSettings()
        SaveManager:BuildConfigSection(Tabs.Config)
        SaveManager:LoadAutoloadConfig()
    end
end)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Ron Hub | GaG2",
    Content = "Loaded successfully - Fluent Edition",
    SubContent = "by @2.6ze And @36ax",
    Type = "Success",
    Duration = 5,
})
