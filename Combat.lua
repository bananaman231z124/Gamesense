getgenv = getgenv
gethui = gethui

local env = if typeof(getgenv) == "function" then getgenv() else _G

if typeof(env.GamesenseCleanup) == "function" then
    pcall(env.GamesenseCleanup)
    env.GamesenseCleanup = nil
    task.wait(0.1)
end

local ui_parents: { Instance } = {
    game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),
    if typeof(gethui) == "function" then gethui() else game:GetService("CoreGui"),
}
local ui_before: { [Instance]: boolean } = {}
for _, parent in ui_parents do
    for _, child in parent:GetChildren() do
        ui_before[child] = true
    end
end

local janitor: { () -> () } = {}

const function on_unload(callback: () -> ())
    table.insert(janitor, callback)
end

const function keep(connection: RBXScriptConnection): RBXScriptConnection
    table.insert(janitor, function()
        connection:Disconnect()
    end)
    return connection
end

local url = "https://raw.githubusercontent.com/bananaman231z124/Gamesense/refs/heads/main/ui_library.lua"
local source = game:HttpGet(url)

local loader, loadError = loadstring(source)
if not loader then
    error("LegendUI failed to compile: " .. tostring(loadError))
end

local LegendUI = loader()
if not LegendUI then
    error("LegendUI returned nil. Check the end of gpt.lua.")
end

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const HttpService = game:GetService("HttpService")
const StarterGui = game:GetService("StarterGui")
const LocalPlayer = Players.LocalPlayer
const Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
const Packets = require(Modules:WaitForChild("Packets"))
const ItemData = require(Modules:WaitForChild("ItemData"))
const ItemIDS = require(Modules:WaitForChild("ItemIDS"))
const Animations = require(game.ReplicatedStorage.Game.animations)
const VirtualUser = game:GetService("VirtualUser")
const Workspace = game:GetService("Workspace")
const Items = Workspace:WaitForChild("Items")
const TweenService = game:GetService("TweenService")

delfile = delfile
isfile = isfile
listfiles = listfiles
isfolder = isfolder
makefolder = makefolder
readfile = readfile
writefile = writefile
Drawing = Drawing
http_request = http_request
syn = syn
request = request

local window = LegendUI:CreateWindow({
    Title = "Gamesense",
    PatternStyle = "Text",
    PatternTexts = {
        {
            Text = "AsterhubK",
            Color = Color3.fromRGB(255,255,255),
            TextSize = 18,
        },
        {
            Text = "GS OT",
            CColor = Color3.fromRGB(255,255,255),
            TextSize = 14,
        },
        {
            Text = "BoohubK",
            Color = Color3.fromRGB(255,255,255),
            TextSize = 22,
        },
    },
    PatternAnimation = "Pulse",
    PatternTransparency = 0.99,
    PatternSpacing = 5,
    PatternTextSize = 14,
    PatternSpeed = 1,
    SubText = "Gamesense Dev",
    SubText2 = "Developer Build",
    AutoSave = false,
    AutoLoad = false,
    ConfigName = "DevProfile",
})

local ui_instances: { Instance } = {}
for _, parent in ui_parents do
    for _, child in parent:GetChildren() do
        if not ui_before[child] then
            table.insert(ui_instances, child)
        end
    end
end

env.GamesenseCleanup = function()
    for index = #janitor, 1, -1 do
        pcall(janitor[index])
    end
    table.clear(janitor)

    pcall(function()
        for _, method in { "Destroy", "Unload", "Close" } do
            local fn = (window :: any)[method]
            if typeof(fn) == "function" then
                fn(window)
                break
            end
        end
    end)

    for _, instance in ui_instances do
        pcall(function()
            instance:Destroy()
        end)
    end
end

-- local Main_Nav = window:AddNavTab("Automations")
local CombatNav = window:AddNavTab("Combat")
local VisualsNav = window:AddNavTab("Visuals")
local MiscNav = window:AddNavTab("Misc")
-- local Automations = Main_Nav:AddPageTab("Automations")
-- local Fruit_Farming = Main_Nav:AddPageTab("Farming")
-- local Farm_Building = Main_Nav:AddPageTab("Build")
local Config_Page = MiscNav:AddPageTab("Config")
local Hub_Page = MiscNav:AddPageTab("Hud")
local Stats_Page = MiscNav:AddPageTab("Stats")
local Combat = CombatNav:AddPageTab("Players")
local Visuals_Page = VisualsNav:AddPageTab("Visuals")

-- local FruitFarming_Left = Fruit_Farming:AddColumn()
-- local FruitFarming_Right = Fruit_Farming:AddColumn()
-- local Farm_BuildColumn = Farm_Building:AddColumn()
-- local Farm_DockColumn = Farm_Building:AddColumn()
-- local AutomationsColumn = Automations:AddColumn()
-- local AutomationsColumn_Right = Automations:AddColumn()
local ConfigColumn = Config_Page:AddColumn()
local CombatColumn = Combat:AddColumn()
local HudColumn = Hub_Page:AddColumn()
local VisualsColumn_Left = Visuals_Page:AddColumn()
local VisualsColumn_Right = Visuals_Page:AddColumn()
local StatsColumn_Left = Stats_Page:AddColumn()
local StatsColumn_Right = Stats_Page:AddColumn()

-- local Auto_Tween = FruitFarming_Right:AddBox("Movement")
-- local Auto_Plant = FruitFarming_Left:AddBox("Auto Farm")
-- local Auto_Performance = FruitFarming_Left:AddBox("Performance")
-- local Auto_PlantBox = Farm_BuildColumn:AddBox("Farm Builder")
-- local Auto_DockBox = Farm_DockColumn:AddBox("Dock Builder")
-- local Auto_Pickup = AutomationsColumn:AddBox("Auto Pickup")
-- local AutoEat = AutomationsColumn_Right:AddBox("Auto Eat")
local Config_Box = ConfigColumn:AddBox("Configs")
local CombatBox = CombatColumn:AddBox("Combat")
local HudBox = HudColumn:AddBox("HUD")
local ESP_Box = VisualsColumn_Left:AddBox("Player ESP")
local ESP_Settings = VisualsColumn_Right:AddBox("ESP Settings")
local ESP_Search = VisualsColumn_Right:AddBox("Search ESP")
local Stats_Box = StatsColumn_Left:AddBox("Farming Stats")
local Webhook_Box = StatsColumn_Right:AddBox("Webhook")

const GlobalConfigs = {
    HUD = {
        Watermark = false,
        KeybindList = false,
        Private = true,
    },
    Stats = {
        Enabled = false,
        Item = "Bloodfruit",
        WebhookEnabled = false,
        Webhook = "",
        Interval = 5,
        Log = {"Items Gained", "Rate Per Hour", "Session Time"},
    },
    ObjectESP = {
        Enabled = false,
        Filter = "",
        Box = true,
        Name = true,
        Distance = true,
        Tracers = false,
        Chams = false,
        MaxDistance = 1500,
        Color = Color3.fromRGB(255, 215, 0),
    },
    AutoEat = {
        Enabled = false,
        Threshold = 50,
        Fruit = "Bloodfruit",
        HungerCap = 100,
        LastEatTime = 0,
    },
    Combat = {
        AutoSwing = false,
        AnimCooldown = 0.35,
        AutoHit = false,
        Targets = {"Players"},
    },
    AutoPickup = {
        Enabled = false,
        Distance = 25,
        Speed = 0.5,
        Filter = "",
    },
    AutoPlant = {
        Enabled = false,
        Speed = 0.00001,
        Distance = 50,
        Cooldown = 0.00001,
        SelectedFruits = {"Berry"},
    },
    AutoHarvest = {
        Enabled = false,
        Speed = 0.05,
        Distance = 25,
        StopAt = 0,
    },
    FarmTween = {
        Enabled = false,
        Speed = 19.5,
        Distance = 100,
        StopDistance = 0.5,
        Type = {
            ["EmptyPlantBoxTween"] = false,
            ["PrioritizeBushes"] = false,
        },
        AvoidPlayers = false,
        AvoidRadius = 20,
    },
    Performance = {
        HidePlantBoxes = false,
        HideBushes = false,
    },
    FarmBuilder = {
        Amount = 5,
        Shape = "Square",
        Speed = 0.00001,
        Preview = false,
        Enabled = true,
        AvoidWater = false,
    },
    Water = {
        Enabled = false,
    },
    DockBuilder = {
        Amount = 5,
        Shape = "Square",
        Speed = 0.00001,
        Preview = false,
        Enabled = false,
    },
    ESP = {
        Enabled = false,
        Box = true,
        Name = true,
        Distance = true,
        Skeleton = false,
        HealthBar = true,
        HealthText = false,
        Tracers = false,
        Chams = false,
        TeamCheck = false,
        MaxDistance = 1000,
        TracerOrigin = "Bottom",
        BoxColor = Color3.fromRGB(255, 255, 255),
        NameColor = Color3.fromRGB(255, 255, 255),
        DistanceColor = Color3.fromRGB(200, 200, 200),
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(255, 255, 255),
        ChamsFill = Color3.fromRGB(255, 60, 60),
        ChamsOutline = Color3.fromRGB(255, 255, 255),
    },
}

on_unload(function()
    for _, section in GlobalConfigs do
        if typeof(section) ~= "table" then
            continue
        end
        for key, value in section do
            if typeof(value) == "boolean" then
                section[key] = false
            end
        end
    end
end)

local keybinds = window:CreateKeybindList({ Title = "Keybind List" })
local watermark = window:CreateWatermark({ Title = "Gamesense", Private = GlobalConfigs.HUD.Private })

const speed_presets: { [string]: number } = {
    ["Fast"] = 0.00001,
    ["Optimized"] = 0.05,
    ["Slow"] = 0.2,
}

const tween_modes: { [string]: string } = {
    ["Plant Boxes"] = "EmptyPlantBoxTween",
    ["Prioritize Bushes"] = "PrioritizeBushes",
}

type Entry = {
    id: number,
    distance: number,
}

type SwingTarget = {
    entityID: number,
}

type BuilderSettings = {
    Amount: number,
    Shape: string,
    Speed: number,
    AvoidWater: boolean,
}

type DockSettings = {
    Amount: number,
    Shape: string,
    Speed: number,
}

type PlantBox = {
    model: Model,
    position: Vector3,
    is_empty: boolean,
    id: number?,
    cell: number,
}

type OverrideRecord = {
    original: any,
    changed: RBXScriptConnection,
    destroying: RBXScriptConnection,
}

type Override = {
    track: (root: Instance) -> (),
    untrack: (root: Instance) -> (),
    set_enabled: (enabled: boolean, roots: { Instance }) -> (),
}

type ConfigEntry = {
    kind: string,
    default: any,
    value: any,
    callback: (any) -> (),
    element: any?,
    persist: boolean,
}

const function create_override(property: string, forced: any, is_target: (Instance) -> boolean): Override
    local enabled = false
    local records: { [Instance]: OverrideRecord } = {}
    local watchers: { [Instance]: RBXScriptConnection } = {}

    local function release(instance: Instance)
        local record = records[instance]
        if not record then
            return
        end
        records[instance] = nil
        record.changed:Disconnect()
        record.destroying:Disconnect()
        local target = instance :: any
        target[property] = record.original
    end

    local function apply(instance: Instance)
        if records[instance] or not is_target(instance) then
            return
        end

        local target = instance :: any
        local record = { original = target[property] } :: OverrideRecord

        record.changed = instance:GetPropertyChangedSignal(property):Connect(function()
            local current = target[property]
            if current == forced then
                return
            end
            record.original = current
            target[property] = forced
        end)

        record.destroying = instance.Destroying:Connect(function()
            local stale = records[instance]
            if not stale then
                return
            end
            records[instance] = nil
            stale.changed:Disconnect()
            stale.destroying:Disconnect()
        end)

        records[instance] = record
        target[property] = forced
    end

    local function track(root: Instance)
        if not enabled or watchers[root] then
            return
        end
        apply(root)
        for _, descendant in root:GetDescendants() do
            apply(descendant)
        end
        watchers[root] = root.DescendantAdded:Connect(apply)
    end

    local function untrack(root: Instance)
        local watcher = watchers[root]
        if watcher then
            watcher:Disconnect()
            watchers[root] = nil
        end
        release(root)
        for _, descendant in root:GetDescendants() do
            release(descendant)
        end
    end

    local function set_enabled(on: boolean, roots: { Instance })
        enabled = on
        if on then
            for _, root in roots do
                track(root)
            end
            return
        end
        for _, watcher in watchers do
            watcher:Disconnect()
        end
        watchers = {}
        local pending: { Instance } = {}
        for instance in records do
            table.insert(pending, instance)
        end
        for _, instance in pending do
            release(instance)
        end
    end

    return {
        track = track,
        untrack = untrack,
        set_enabled = set_enabled,
    }
end

const function hide_override(): Override
    return create_override("Transparency", 1, function(instance)
        return instance:IsA("BasePart") or instance:IsA("Decal")
    end)
end

const function collide_override(): Override
    return create_override("CanCollide", false, function(instance)
        return instance:IsA("BasePart")
    end)
end

const functionbank = (function()
    local deployables = Workspace:WaitForChild("Deployables")
    local plant_boxes: { [Model]: PlantBox } = {}
    local box_cells: { [number]: { [Model]: PlantBox } } = {}
    local docks: { [Model]: Vector3 } = {}

    local function cell_index(cx: number, cz: number): number
        return (cx + 32768) * 65536 + (cz + 32768)
    end

    local function cell_of(position: Vector3): number
        return cell_index(math.floor(position.X / 5), math.floor(position.Z / 5))
    end

    local combat_folder_names = {
        "Resources",
        "Critters",
        "Players",
        "Deployables",
        "Rubble",
    }

    local combat_targets: { [string]: { [Model]: boolean } } = {}
    local combat_connections: { [Instance]: { RBXScriptConnection } } = {}

    local hide_folder_overrides = { Resources = hide_override(), Critters = hide_override() }
    local hide_collision_overrides = { Resources = collide_override(), Critters = collide_override() }
    local hide_plant_boxes = hide_override()
    local hide_bushes = hide_override()
    local no_collide_bushes = collide_override()

    local deployable_collision: { [string]: Override } = {}
    for _, name in { "Bed", "Clan Bed", "Plant Box" } do
        deployable_collision[name] = collide_override()
    end

    local function cache_combat_target(folder_name: string, instance: Instance)
        if not instance:IsA("Model") then
            return
        end
        combat_targets[folder_name][instance] = true
        local override = hide_folder_overrides[folder_name]
        if override then
            override.track(instance)
        end
    end

    local function uncache_combat_target(folder_name: string, instance: Instance)
        if not instance:IsA("Model") then
            return
        end
        combat_targets[folder_name][instance] = nil
        local override = hide_folder_overrides[folder_name]
        if override then
            override.untrack(instance)
        end
    end

    local function track_combat_folder(folder_name: string, folder: Instance)
        if combat_connections[folder] then
            return
        end

        combat_targets[folder_name] = combat_targets[folder_name] or {}

        for _, model in folder:GetChildren() do
            cache_combat_target(folder_name, model)
        end

        combat_connections[folder] = {
            folder.ChildAdded:Connect(function(model)
                cache_combat_target(folder_name, model)
            end),
            folder.ChildRemoved:Connect(function(model)
                uncache_combat_target(folder_name, model)
            end),
        }
    end

    for _, folder_name in combat_folder_names do
        combat_targets[folder_name] = {}

        local folder = Workspace:FindFirstChild(folder_name)
        if folder then
            track_combat_folder(folder_name, folder)
        end
    end

    keep(Workspace.ChildAdded:Connect(function(folder)
        for _, folder_name in combat_folder_names do
            if folder.Name == folder_name then
                track_combat_folder(folder_name, folder)
                break
            end
        end
    end))

    local function deployable_added(model: Instance)
        if not model:IsA("Model") then
            return
        end

        local collision = deployable_collision[model.Name]
        if collision then
            collision.track(model)
        end

        if model.Name == "Dock" then
            docks[model] = model:GetPivot().Position
            return
        end

        if model.Name ~= "Plant Box" then
            return
        end

        local position = model:GetPivot().Position
        local data: PlantBox = {
            model = model,
            position = position,
            is_empty = not model:FindFirstChild("Seed"),
            id = nil,
            cell = cell_of(position),
        }

        plant_boxes[model] = data
        local bucket = box_cells[data.cell]
        if not bucket then
            bucket = {}
            box_cells[data.cell] = bucket
        end
        bucket[model] = data

        hide_plant_boxes.track(model)
    end

    local function deployable_removed(model: Instance)
        if not model:IsA("Model") then
            return
        end

        local collision = deployable_collision[model.Name]
        if collision then
            collision.untrack(model)
        end

        docks[model] = nil

        local box = plant_boxes[model]
        if not box then
            return
        end

        plant_boxes[model] = nil
        local bucket = box_cells[box.cell]
        if bucket then
            bucket[model] = nil
            if next(bucket) == nil then
                box_cells[box.cell] = nil
            end
        end
        hide_plant_boxes.untrack(model)
    end

    for _, model in deployables:GetChildren() do
        task.spawn(deployable_added, model)
    end
    keep(deployables.ChildAdded:Connect(deployable_added))
    keep(deployables.ChildRemoved:Connect(deployable_removed))

    keep(deployables.DescendantAdded:Connect(function(instance)
        if instance.Name ~= "Seed" then
            return
        end
        local parent = instance.Parent
        local box = parent and plant_boxes[parent :: Model]
        if box then
            box.is_empty = false
        end
    end))

    keep(deployables.DescendantRemoving:Connect(function(instance)
        if instance.Name ~= "Seed" then
            return
        end
        local parent = instance.Parent
        local box = parent and plant_boxes[parent :: Model]
        if box then
            box.is_empty = true
        end
    end))

    local planted_counts: { [string]: number } = {}
    local last_sent: { [number]: number } = {}

    local crops_folder = Workspace:WaitForChild("Crops")
    local crop_positions: { [Model]: Vector3 } = {}
    local crop_ids: { [Model]: number } = {}

    local function crop_id(model: Model): number?
        local cached = crop_ids[model]
        if cached then
            return cached
        end
        local id = model:GetAttribute("EntityID")
        if typeof(id) == "number" then
            crop_ids[model] = id
            return id
        end
        return nil
    end

    local function crop_added(model: Instance)
        if not model:IsA("Model") then
            return
        end
        crop_positions[model] = model:GetPivot().Position
        hide_bushes.track(model)
        no_collide_bushes.track(model)
    end

    local function crop_removed(model: Instance)
        if not model:IsA("Model") then
            return
        end
        crop_positions[model] = nil
        crop_ids[model] = nil
        hide_bushes.untrack(model)
        no_collide_bushes.untrack(model)
    end

    for _, model in crops_folder:GetChildren() do
        task.spawn(crop_added, model)
    end
    keep(crops_folder.ChildAdded:Connect(crop_added))
    keep(crops_folder.ChildRemoved:Connect(crop_removed))

    local function get_root(): BasePart?
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            return root
        end
        return nil
    end

    local BUILD_GRID = 5.01
    local BUILD_TIMEOUT = 1
    local WALK_SPEED = 16
    local ROOT_HEIGHT = 3

    local preview_folder: Folder? = nil
    local preview_signature = ""
    local building = false

    local function snap(value: number): number
        return math.floor(value / BUILD_GRID + 0.5) * BUILD_GRID
    end

    local function ground_at(position: Vector3, lift: number?, avoid_water: boolean?): Vector3?
        local ignore: { Instance } = { crops_folder }
        local character = LocalPlayer.Character
        if character then
            table.insert(ignore, character)
        end
        if preview_folder then
            table.insert(ignore, preview_folder)
        end

        local resources = Workspace:FindFirstChild("Resources")
        if resources then
            table.insert(ignore, resources)
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = not avoid_water

        local origin = position + Vector3.new(0, lift or 50, 0)
        local result = Workspace:Raycast(origin, Vector3.new(0, -300, 0), params)

        if not result then
            return nil
        end

        if avoid_water and result.Material == Enum.Material.Water then
            return nil
        end

        return result.Position
    end

    local function feet_surface(): number?
        local root = get_root()
        if not root then
            return nil
        end
        local hit = ground_at(root.Position, 0)
        return if hit then hit.Y else nil
    end

    local function grid_points(center: Vector3, amount: number, shape: string, step_x: number, step_z: number, outer_is_x: boolean): { Vector3 }
        local points: { Vector3 } = {}
        local low = -math.floor((amount - 1) / 2)
        local high = low + amount - 1
        local middle = (low + high) / 2
        local radius = amount / 2
        local radius_squared = radius * radius

        for outer = low, high do
            local first, last, step = low, high, 1
            if (outer - low) % 2 == 1 then
                first, last, step = high, low, -1
            end
            for inner = first, last, step do
                local xi = if outer_is_x then outer else inner
                local zi = if outer_is_x then inner else outer
                local dx, dz = xi - middle, zi - middle

                local keep_point = true
                if shape == "Circle" then
                    keep_point = dx * dx + dz * dz <= radius_squared
                elseif shape == "Diamond" then
                    keep_point = math.abs(dx) + math.abs(dz) <= radius
                elseif shape == "Hollow Square" then
                    keep_point = xi == low or xi == high or zi == low or zi == high
                elseif shape == "Line" then
                    keep_point = zi == 0
                end

                if keep_point then
                    table.insert(points, Vector3.new(center.X + xi * step_x, center.Y, center.Z + zi * step_z))
                end
            end
        end

        return points
    end

    local function make_preview_part(position: Vector3, parent: Instance)
        local part = Instance.new("Part")
        part.Name = "Preview"
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.one
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(50, 255, 50)
        part.Transparency = 0.25
        part.Position = position
        part.Parent = parent
    end

    local function clear_preview()
        if preview_folder then
            preview_folder:Destroy()
            preview_folder = nil
        end
        preview_signature = ""
    end

    local preview_level = 0
    local function refresh_preview(amount: number, shape: string)
        local root = get_root()
        if not root then
            return
        end

        local avoid_water = GlobalConfigs.FarmBuilder.AvoidWater
        local level = (feet_surface() or root.Position.Y - 3) + 0.5
        local center = Vector3.new(snap(root.Position.X), level, snap(root.Position.Z))

        local signature = string.format(
            "%.2f|%.2f|%d|%s|%s",
            center.X,
            center.Z,
            amount,
            shape,
            tostring(avoid_water)
        )

        if signature == preview_signature and preview_folder then
            if not avoid_water and math.abs(level - preview_level) > 0.05 then
                preview_level = level
                for _, part in preview_folder:GetChildren() do
                    if part:IsA("BasePart") then
                        part.Position = Vector3.new(part.Position.X, level, part.Position.Z)
                    end
                end
            end
            return
        end

        preview_signature = signature
        preview_level = level

        if preview_folder then
            preview_folder:ClearAllChildren()
        else
            preview_folder = Instance.new("Folder")
            preview_folder.Name = "BuildPreview"
            preview_folder.Parent = Workspace
        end

        for _, point in grid_points(center, amount, shape, BUILD_GRID, BUILD_GRID, true) do
            local preview_position = point

            if avoid_water then
                local ground = ground_at(Vector3.new(point.X, level, point.Z), 50, true)

                if not ground or math.abs(ground.Y - (level - 0.5)) > 4 then
                    continue
                end

                preview_position = Vector3.new(point.X, ground.Y + 0.5, point.Z)
            end

            make_preview_part(preview_position, preview_folder :: Folder)
        end
    end

    local function box_exists_near(position: Vector3): boolean
        local cx, cz = math.floor(position.X / 5), math.floor(position.Z / 5)
        for dx = -1, 1 do
            for dz = -1, 1 do
                local bucket = box_cells[cell_index(cx + dx, cz + dz)]
                if not bucket then
                    continue
                end
                for _, box in bucket do
                    local ox, oz = box.position.X - position.X, box.position.Z - position.Z
                    if ox * ox + oz * oz < 4 then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function walk_to(destination: Vector3, rotation: CFrame, is_active: () -> boolean): boolean
        local root = get_root()
        if not root then
            return false
        end

        local distance = (destination - root.Position).Magnitude
        if distance < 0.1 then
            return true
        end

        local tween = TweenService:Create(
            root,
            TweenInfo.new(distance / WALK_SPEED, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(destination) * rotation }
        )
        tween:Play()

        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if not is_active() then
                tween:Cancel()
                return false
            end
            task.wait()
        end
        return true
    end

    local water_enabled = false
    local water_platform: Part? = nil
    local water_connection: RBXScriptConnection? = nil

    local function water_surface_at(position: Vector3, ignore_docks: boolean?): number?
        local ignore: { Instance } = { crops_folder }
        local character = LocalPlayer.Character
        if character then
            table.insert(ignore, character)
        end
        if ignore_docks then
            for model in docks do
                table.insert(ignore, model)
            end
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = false

        local result = Workspace:Raycast(position + Vector3.new(0, 25, 0), Vector3.new(0, -400, 0), params)
        if result and result.Material == Enum.Material.Water then
            return result.Position.Y
        end
        return nil
    end

    local function water_step()
        local root = get_root()
        if not root then
            return
        end
        local surface = water_surface_at(root.Position, false)
        local feet = root.Position.Y - ROOT_HEIGHT
        if not surface or feet < surface - 1.5 then
            if water_platform then
                water_platform.CanCollide = false
            end
            return
        end
        if not water_platform then
            local platform = Instance.new("Part")
            platform.Name = "WaterPlatform"
            platform.Size = Vector3.new(10, 1, 10)
            platform.Anchored = true
            platform.CanCollide = true
            platform.CanTouch = false
            platform.CanQuery = false
            platform.CastShadow = false
            platform.Transparency = 1
            platform.Parent = Workspace
            water_platform = platform
        end
        local platform = water_platform :: Part
        platform.CanCollide = true
        platform.CFrame = CFrame.new(root.Position.X, surface - platform.Size.Y / 2, root.Position.Z)
    end

    local function set_walk_on_water(on: boolean)
        if on == water_enabled then
            return
        end
        water_enabled = on
        if on then
            water_connection = RunService.Heartbeat:Connect(water_step)
            return
        end
        if water_connection then
            water_connection:Disconnect()
            water_connection = nil
        end
        if water_platform then
            water_platform:Destroy()
            water_platform = nil
        end
    end

    local DOCK_SIZE = Vector3.new(10, 1.2, 1.8)
    local measured_x: number? = nil
    local measured_z: number? = nil

    local dock_preview_folder: Folder? = nil
    local dock_preview_signature = ""

    local function snap_to(value: number, step: number): number
        return math.floor(value / step + 0.5) * step
    end

    local function measure_dock(scan: boolean): Vector3?
        local root = get_root()
        if not root then
            return nil
        end
        local nearest: Model? = nil
        local best = math.huge
        local function consider(instance: Instance)
            if not instance:IsA("Model") or instance.Name ~= "Dock" then
                return
            end
            local distance = (instance:GetPivot().Position - root.Position).Magnitude
            if distance < best then
                best = distance
                nearest = instance
            end
        end
        for model in docks do
            consider(model)
        end
        if not nearest and scan then
            for _, descendant in Workspace:GetDescendants() do
                consider(descendant)
            end
        end
        if not nearest then
            return nil
        end
        return (nearest :: Model):GetExtentsSize()
    end

    local function detect_dock_size(scan: boolean)
        if measured_x then
            return
        end
        local size = measure_dock(scan)
        if not size then
            return
        end
        measured_x = math.floor((size.X + 0.01) * 100 + 0.5) / 100
        measured_z = math.floor((size.Z + 0.01) * 100 + 0.5) / 100
        print(string.format("[DockBuilder] detected dock size %.2f x %.2f x %.2f", size.X, size.Y, size.Z))
    end

    local function dock_steps(): (number, number)
        detect_dock_size(false)
        return measured_x or (DOCK_SIZE.X + 0.01), measured_z or (DOCK_SIZE.Z + 0.01)
    end

    local function clear_dock_preview()
        if dock_preview_folder then
            dock_preview_folder:Destroy()
            dock_preview_folder = nil
        end
        dock_preview_signature = ""
    end

    local function refresh_dock_preview(amount: number, shape: string)
        local root = get_root()
        if not root then
            return
        end

        local level = water_surface_at(root.Position, true)
        if not level then
            clear_dock_preview()
            return
        end

        local step_x, step_z = dock_steps()
        local center = Vector3.new(snap_to(root.Position.X, step_x), level, snap_to(root.Position.Z, step_z))

        local signature = string.format(
            "%.2f|%.2f|%.2f|%d|%s|%.2f|%.2f",
            center.X, center.Y, center.Z, amount, shape, step_x, step_z
        )
        if signature == dock_preview_signature and dock_preview_folder then
            return
        end
        dock_preview_signature = signature

        if dock_preview_folder then
            dock_preview_folder:ClearAllChildren()
        else
            dock_preview_folder = Instance.new("Folder")
            dock_preview_folder.Name = "DockPreview"
            dock_preview_folder.Parent = Workspace
        end

        for _, point in grid_points(center, amount, shape, step_x, step_z, false) do
            make_preview_part(point, dock_preview_folder :: Folder)
        end
    end

    local function dock_exists_near(position: Vector3, step_x: number, step_z: number): boolean
        for _, dock_position in docks do
            if math.abs(dock_position.X - position.X) < step_x / 2
                and math.abs(dock_position.Z - position.Z) < step_z / 2 then
                return true
            end
        end
        return false
    end

    local function place_dock(point: Vector3, surface: number, speed: number, step_x: number, step_z: number, is_active: () -> boolean)
        local placement = CFrame.new(point.X, surface, point.Z)
        local deadline = os.clock() + BUILD_TIMEOUT
        while is_active() and os.clock() < deadline and not dock_exists_near(point, step_x, step_z) do
            Packets.PlaceStructure.send({
                buildingName = "Dock",
                cframe = placement,
            })
            task.wait(speed)
        end
    end

    local function build_docks(settings: DockSettings, is_active: () -> boolean)
        if building then
            return
        end
        local root = get_root()
        if not root then
            return
        end
        local level = water_surface_at(root.Position, true)
        if not level then
            warn("[DockBuilder] stand on or above water to build")
            return
        end
        building = true
        local rotation = root.CFrame.Rotation
        local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
        local auto_rotate = humanoid and humanoid.AutoRotate
        if humanoid then
            humanoid.AutoRotate = false
        end
        local was_walking = water_enabled
        set_walk_on_water(true)
        local ok, err = pcall(function()
            detect_dock_size(true)
            local step_x, step_z = dock_steps()
            local center = Vector3.new(snap_to(root.Position.X, step_x), level, snap_to(root.Position.Z, step_z))
            if not measured_x then
                center = Vector3.new(root.Position.X, level, root.Position.Z)
                place_dock(center, level, settings.Speed, 4, 4, is_active)
                detect_dock_size(false)
                step_x, step_z = dock_steps()
            end
            for _, point in grid_points(center, settings.Amount, settings.Shape, step_x, step_z, false) do
                if not is_active() then
                    break
                end
                if dock_exists_near(point, step_x, step_z) then
                    continue
                end
                local surface = water_surface_at(point, true)
                if not surface or math.abs(surface - level) > 4 then
                    continue
                end
                local stand = Vector3.new(point.X, surface + ROOT_HEIGHT + DOCK_SIZE.Y, point.Z)
                if not walk_to(stand, rotation, is_active) then
                    break
                end
                place_dock(point, surface, settings.Speed, step_x, step_z, is_active)
            end
        end)
        if not was_walking then
            set_walk_on_water(false)
        end
        if humanoid then
            humanoid.AutoRotate = auto_rotate
        end
        building = false
        if not ok then
            warn("[DockBuilder] " .. tostring(err))
        end
    end

    local COMBAT_RANGE_SQUARED = 15 * 15

    local function scan_swing_targets(): ({ SwingTarget }, Vector3?, Vector3?)
        local found: { SwingTarget } = {}

        local root = get_root()
        if not root then
            return found, nil, nil
        end

        local character = root.Parent
        local origin = root.Position
        local first_position: Vector3? = nil

        for _, folder_name in GlobalConfigs.Combat.Targets do
            local targets = combat_targets[folder_name]
            if not targets then
                continue
            end

            for model in targets do
                if model == character then
                    continue
                end

                local id = model:GetAttribute("EntityID")
                if typeof(id) ~= "number" then
                    continue
                end

                local offset = model:GetPivot().Position - origin
                if offset:Dot(offset) > COMBAT_RANGE_SQUARED then
                    continue
                end

                table.insert(found, { entityID = id })
                first_position = first_position or (origin + offset)
            end
        end

        return found, first_position, origin
    end

    local auto_eat_generation = 0

    local function get_hunger(): number
        local player_gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local main_gui = player_gui and player_gui:FindFirstChild("MainGui")
        local panels = main_gui and main_gui:FindFirstChild("Panels")
        local stats_panel = panels and panels:FindFirstChild("Stats")
        local bars = stats_panel and stats_panel:FindFirstChild("Bars")
        local hunger_bar = bars and bars:FindFirstChild("Hunger")
        local value_label = hunger_bar and hunger_bar:FindFirstChild("ValueLabel")

        if not value_label or not value_label:IsA("TextLabel") then
            return 100
        end

        return tonumber(value_label.Text) or 100
    end

    local function get_fruit_restore_amount(fruit_name: string): number?
        local item_id = ItemIDS[fruit_name]
        if not item_id then
            return nil
        end

        local data = ItemData[item_id] or ItemData[fruit_name]
        if not data then
            return nil
        end

        local restore = data.food
            or data.hunger
            or data.restore
            or data.restoreValue
            or data.heal

        return if typeof(restore) == "number" then restore else nil
    end

    local function get_fruit_slot(fruit_name: string): number?
        local player_gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local main_gui = player_gui and player_gui:FindFirstChild("MainGui")
        local right_panel = main_gui and main_gui:FindFirstChild("RightPanel")
        local inventory = right_panel and right_panel:FindFirstChild("Inventory")
        local inventory_list = inventory and inventory:FindFirstChild("List")
        local slot = inventory_list and inventory_list:FindFirstChild(fruit_name)

        if not slot then
            return nil
        end

        local layout_order = slot.LayoutOrder
        return if layout_order > 0 then layout_order else nil
    end

    local function run_auto_eat(generation: number)
        while GlobalConfigs.AutoEat.Enabled
            and generation == auto_eat_generation do

            local config = GlobalConfigs.AutoEat
            local hunger = get_hunger()

            if hunger <= config.Threshold
                and os.clock() - config.LastEatTime >= 0.4 then

                local slot = get_fruit_slot(config.Fruit)
                local restore = get_fruit_restore_amount(config.Fruit)

                if slot
                    and (not restore or hunger + restore <= config.HungerCap)
                    and Packets.UseBagItem
                    and Packets.UseBagItem.send then

                    Packets.UseBagItem.send(slot)
                    config.LastEatTime = os.clock()
                end
            end

            task.wait(0.3)
        end
    end

    local function other_player_positions(): { Vector3 }
        local positions: { Vector3 } = {}
        for _, player in Players:GetPlayers() do
            if player == LocalPlayer then
                continue
            end
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                table.insert(positions, root.Position)
            end
        end
        return positions
    end

    local function near_player(position: Vector3, positions: { Vector3 }, radius: number): boolean
        local radius_squared = radius * radius
        for _, other in positions do
            local offset = Vector3.new(other.X - position.X, 0, other.Z - position.Z)
            if offset:Dot(offset) <= radius_squared then
                return true
            end
        end
        return false
    end

    local function player_gap(position: Vector3, positions: { Vector3 }): number
        local best = math.huge
        for _, other in positions do
            local offset = Vector3.new(other.X - position.X, 0, other.Z - position.Z)
            best = math.min(best, offset.Magnitude)
        end
        return best
    end

    on_unload(function()
        auto_eat_generation += 1

        for _, folder_connections in combat_connections do
            for _, connection in folder_connections do
                connection:Disconnect()
            end
        end
        table.clear(combat_connections)

        local overrides: { Override } = { hide_plant_boxes, hide_bushes, no_collide_bushes }
        for _, group in { hide_folder_overrides, hide_collision_overrides, deployable_collision } do
            for _, override in group do
                table.insert(overrides, override)
            end
        end
        for _, override in overrides do
            override.set_enabled(false, {})
        end

        set_walk_on_water(false)
        clear_preview()
        clear_dock_preview()

        local root = get_root()
        if root then
            root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        end
    end)

    return {
        SetAutoEat = function(enabled: boolean)
            GlobalConfigs.AutoEat.Enabled = enabled
            auto_eat_generation += 1

            if enabled then
                local generation = auto_eat_generation
                task.spawn(run_auto_eat, generation)
            end
        end,

        GetItemsByID = function(item_filter: string?, max_distance: number?): { number }
            local root = get_root()
            if not root then
                return {}
            end

            local filter = string.lower(item_filter or "")
            local entries: { Entry } = {}
            for _, item in Items:GetChildren() do
                if not item:IsA("PVInstance") then
                    continue
                end
                if filter ~= "" and not string.find(string.lower(item.Name), filter, 1, true) then
                    continue
                end
                local id = item:GetAttribute("EntityID")
                if typeof(id) ~= "number" then
                    continue
                end
                local distance = (item:GetPivot().Position - root.Position).Magnitude
                if max_distance and distance > max_distance then
                    continue
                end
                table.insert(entries, { id = id, distance = distance })
            end
            table.sort(entries, function(a, b)
                return a.distance < b.distance
            end)
            local ids: { number } = {}
            for _, entry in entries do
                table.insert(ids, entry.id)
            end
            return ids
        end,

        GetFruitOptions = function(): { string }
            local fruits: { string } = {}
            for name, data in ItemData do
                if not data.grows then
                    continue
                end
                table.insert(fruits, name)
            end
            table.sort(fruits)
            return fruits
        end,

        ClaimNearestPlant = function(range: number, fruits: { string }, cooldown: number): (number?, string?)
            local root = get_root()
            if not root then
                return nil, nil
            end

            local best_fruit: string? = nil
            local best_count = math.huge
            for _, fruit in fruits do
                if not ItemIDS[fruit] then
                    continue
                end
                local count = planted_counts[fruit] or 0
                if count < best_count then
                    best_fruit = fruit
                    best_count = count
                end
            end
            if not best_fruit then
                return nil, nil
            end

            local origin = root.Position
            local now = os.clock()
            local nearest_id: number? = nil
            local nearest = range * range

            for _, box in plant_boxes do
                if not box.is_empty then
                    continue
                end
                local offset = box.position - origin
                local distance_squared = offset:Dot(offset)
                if distance_squared > nearest then
                    continue
                end

                local id = box.id
                if not id then
                    local value = box.model:GetAttribute("EntityID")
                    if typeof(value) ~= "number" then
                        continue
                    end
                    box.id = value
                    id = value
                end

                local sent_at = last_sent[id]
                if sent_at and now - sent_at < cooldown then
                    continue
                end

                nearest = distance_squared
                nearest_id = id
            end

            if not nearest_id then
                return nil, nil
            end

            planted_counts[best_fruit] = (planted_counts[best_fruit] or 0) + 1
            last_sent[nearest_id] = now
            return nearest_id, best_fruit
        end,

        GetCropsInRange = function(range: number): { number }
            local root = get_root()
            if not root then
                return {}
            end
            local origin = root.Position
            local range_squared = range * range
            local ids: { number } = {}
            for model, position in crop_positions do
                local offset = position - origin
                if offset:Dot(offset) > range_squared then
                    continue
                end
                local id = crop_id(model)
                if id then
                    table.insert(ids, id)
                end
            end
            return ids
        end,

        SetHidePlantBoxes = function(enabled: boolean)
            local roots: { Instance } = {}
            for model in plant_boxes do
                table.insert(roots, model)
            end
            hide_plant_boxes.set_enabled(enabled, roots)
        end,

        SetHideBushes = function(enabled: boolean)
            local roots: { Instance } = {}
            for model in crop_positions do
                table.insert(roots, model)
            end
            hide_bushes.set_enabled(enabled, roots)
        end,

        SetNoCollide = function(selected: { string })
            local wanted: { [string]: boolean } = {}
            for _, name in selected do
                wanted[name] = true
            end

            local bush_roots: { Instance } = {}
            for model in crop_positions do
                table.insert(bush_roots, model)
            end
            no_collide_bushes.set_enabled(wanted["Bushes"] == true, bush_roots)

            for name, override in deployable_collision do
                local roots: { Instance } = {}
                for _, child in deployables:GetChildren() do
                    if child.Name == name then
                        table.insert(roots, child)
                    end
                end
                override.set_enabled(wanted[name] == true, roots)
            end
        end,

        SetHiddenFolders = function(selected: { string })
            local wanted: { [string]: boolean } = {}
            for _, name in selected do
                wanted[name] = true
            end

            for folder_name, override in hide_folder_overrides do
                local roots: { Instance } = {}
                for model in combat_targets[folder_name] do
                    table.insert(roots, model)
                end

                local enabled = wanted[folder_name] == true
                override.set_enabled(enabled, roots)

                local collision_override = hide_collision_overrides[folder_name]
                if collision_override then
                    collision_override.set_enabled(enabled, roots)
                end
            end
        end,

        GetTweenTarget = function(modes: { [string]: boolean }, range: number, avoid_radius: number?): Vector3?
            local root = get_root()
            if not root then
                return nil
            end
            local origin = root.Position
            local range_squared = range * range
            local players_nearby = if avoid_radius then other_player_positions() else {}

            if modes.PrioritizeBushes then
                local nearest: Vector3? = nil
                local best = range_squared
                for model, position in crop_positions do
                    if not crop_id(model) then
                        continue
                    end
                    if avoid_radius and near_player(position, players_nearby, avoid_radius) then
                        continue
                    end
                    local offset = position - origin
                    local distance_squared = offset:Dot(offset)
                    if distance_squared <= best then
                        best = distance_squared
                        nearest = position
                    end
                end
                if nearest then
                    return nearest
                end
            end

            if modes.EmptyPlantBoxTween then
                local nearest: Vector3? = nil
                local best = range_squared
                local fallback: Vector3? = nil
                local fallback_gap = -1

                for _, box in plant_boxes do
                    if not box.is_empty then
                        continue
                    end
                    local offset = box.position - origin
                    local distance_squared = offset:Dot(offset)
                    if distance_squared > range_squared then
                        continue
                    end

                    if avoid_radius then
                        local gap = player_gap(box.position, players_nearby)
                        if gap <= avoid_radius then
                            if gap > fallback_gap then
                                fallback_gap = gap
                                fallback = box.position
                            end
                            continue
                        end
                    end

                    if distance_squared <= best then
                        best = distance_squared
                        nearest = box.position
                    end
                end

                return nearest or fallback
            end

            return nil
        end,

        MoveToward = function(target: Vector3, speed: number, stop_distance: number, dt: number): boolean
            local root = get_root()
            if not root then
                return false
            end

            local current = root.AssemblyLinearVelocity
            local offset = target - root.Position
            local flat = Vector3.new(offset.X, 0, offset.Z)
            local distance = flat.Magnitude

            root.AssemblyLinearVelocity = Vector3.new(0, current.Y, 0)

            if distance <= stop_distance then
                return false
            end

            local step = math.min(speed * math.min(dt, 0.1), distance - stop_distance)
            root.CFrame = root.CFrame + (flat / distance) * step
            return true
        end,

        StopMoving = function()
            local root = get_root()
            if not root then
                return
            end
            root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        end,

        RefreshPreview = refresh_preview,
        ClearPreview = clear_preview,

        SetWalkOnWater = set_walk_on_water,
        RefreshDockPreview = refresh_dock_preview,
        ClearDockPreview = clear_dock_preview,
        BuildDocks = build_docks,

        IsBuilding = function(): boolean
            return building
        end,

        BuildFarm = function(settings: BuilderSettings, is_active: () -> boolean)
            if building then
                return
            end
            local root = get_root()
            local feet_y = feet_surface()
            if not root or not feet_y then
                return
            end
            building = true
            local center = Vector3.new(snap(root.Position.X), feet_y, snap(root.Position.Z))
            local rotation = root.CFrame.Rotation
            local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
            local auto_rotate = humanoid and humanoid.AutoRotate
            if humanoid then
                humanoid.AutoRotate = false
            end
            local ok, err = pcall(function()
                for _, point in grid_points(center, settings.Amount, settings.Shape, BUILD_GRID, BUILD_GRID, true) do
                    if not is_active() then
                        break
                    end
                    if box_exists_near(point) then
                        continue
                    end
                    local ground = ground_at(Vector3.new(point.X, feet_y, point.Z), 50, settings.AvoidWater)
                    if not ground or math.abs(ground.Y - feet_y) > 4 then
                        continue
                    end
                    local stand = Vector3.new(point.X + 0.5, ground.Y + ROOT_HEIGHT, point.Z)
                    if not walk_to(stand, rotation, is_active) then
                        break
                    end
                    local placement = CFrame.new(point.X, ground.Y, point.Z)
                    local deadline = os.clock() + BUILD_TIMEOUT
                    while is_active() and os.clock() < deadline and not box_exists_near(point) do
                        Packets.PlaceStructure.send({
                            buildingName = "Plant Box",
                            cframe = placement,
                        })
                        task.wait(settings.Speed)
                    end
                end
            end)
            if humanoid then
                humanoid.AutoRotate = auto_rotate
            end
            building = false
            if not ok then
                warn("[FarmBuilder] " .. tostring(err))
            end
        end,

        SwingTool = function(): boolean
            local targets, first_position, origin = scan_swing_targets()
            if #targets == 0 or not first_position or not origin then
                return false
            end
            Packets.SwingTool.send({
                entityIDs = targets,
                cframe = CFrame.new(origin, first_position),
                timestamp = Workspace:GetServerTimeNow(),
            })
            return true
        end,
    }
end)()

type StatsSnapshot = {
    gained: number,
    current: number,
    elapsed: number,
    rate: number,
}

const stats = (function()
    local active_time = 0
    local resumed_at: number? = nil
    local last_count: number? = nil
    local current = 0
    local gained = 0
    local poll_generation = 0
    local webhook_generation = 0
    local label_cache: { [string]: TextLabel } = {}
    local list_cache: Instance? = nil

    local COUNT_NAMES = { count = true, amount = true, quantity = true, stack = true }

    local LOG_OPTIONS = {
        "Items Gained",
        "Rate Per Hour",
        "Session Time",
        "Current Inventory",
        "Player",
        "Server",
    }

    local function parse_count(text: string): number?
        local digits = text:gsub(",", ""):match("%d+")
        return if digits then tonumber(digits) else nil
    end

    local function parse_exact(text: string): number?
        local digits = text:gsub(",", ""):match("^%s*x?(%d+)%s*$")
        return if digits then tonumber(digits) else nil
    end

    local function find_count_label(slot: Instance): TextLabel?
        local exact: TextLabel? = nil
        local loose: TextLabel? = nil
        for _, descendant in slot:GetDescendants() do
            if not descendant:IsA("TextLabel") then
                continue
            end
            local text = descendant.Text
            if COUNT_NAMES[string.lower(descendant.Name)] and parse_count(text) then
                return descendant
            end
            if not exact and parse_exact(text) then
                exact = descendant
            end
            if not loose and parse_count(text) then
                loose = descendant
            end
        end
        return exact or loose
    end

    local function get_list(): Instance?
        if list_cache and list_cache:IsDescendantOf(game) then
            return list_cache
        end
        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local main_gui = gui and gui:FindFirstChild("MainGui")
        local panel = main_gui and main_gui:FindFirstChild("RightPanel")
        local inventory = panel and panel:FindFirstChild("Inventory")
        list_cache = inventory and inventory:FindFirstChild("List")
        return list_cache
    end

    local function read_count(item: string): number?
        local wanted = string.lower(item)

        local cached = label_cache[wanted]
        if cached and cached:IsDescendantOf(game) then
            return parse_count(cached.Text) or 1
        end
        label_cache[wanted] = nil

        local list = get_list()
        if not list then
            return nil
        end

        for _, slot in list:GetChildren() do
            if string.lower(slot.Name) ~= wanted then
                continue
            end
            local label = find_count_label(slot)
            if not label then
                return 1
            end
            label_cache[wanted] = label
            return parse_count(label.Text) or 1
        end

        return 0
    end

    local function format_number(value: number): string
        local text = tostring(math.floor(value))
        local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return (formatted:gsub("^,", ""))
    end

    local function format_time(seconds: number): string
        local total = math.floor(seconds)
        return string.format("%dh %02dm %02ds", total // 3600, (total % 3600) // 60, total % 60)
    end

    local function snapshot(): StatsSnapshot
        local elapsed = active_time + (if resumed_at then os.clock() - resumed_at else 0)
        return {
            gained = gained,
            current = current,
            elapsed = elapsed,
            rate = if elapsed > 1 then gained / (elapsed / 3600) else 0,
        }
    end

    local function poll(generation: number)
        while generation == poll_generation do
            local count = read_count(GlobalConfigs.Stats.Item)
            if count then
                if last_count and count > last_count then
                    gained += count - last_count
                end
                last_count = count
                current = count
            end
            task.wait(0.25)
        end
    end

    local function get_request(): ((any) -> any)?
        if typeof(request) == "function" then
            return request
        end
        if typeof(http_request) == "function" then
            return http_request
        end
        if typeof(syn) == "table" and typeof(syn.request) == "function" then
            return syn.request
        end
        return nil
    end

    local function valid_webhook(webhook_url: string): boolean
        return webhook_url:match("^https://discord%.com/api/webhooks/") ~= nil
            or webhook_url:match("^https://discordapp%.com/api/webhooks/") ~= nil
            or webhook_url:match("^https://[%w]+%.discord%.com/api/webhooks/") ~= nil
    end

    local function build_embed(title: string): any
        local config = GlobalConfigs.Stats
        local data = snapshot()
        local selected: { [string]: boolean } = {}
        for _, name in config.Log do
            selected[name] = true
        end

        local fields = {}
        if selected["Items Gained"] then
            table.insert(fields, { name = config.Item .. " Gained", value = "```" .. format_number(data.gained) .. "```", inline = true })
        end
        if selected["Rate Per Hour"] then
            table.insert(fields, { name = "Rate Per Hour", value = "```" .. format_number(data.rate) .. "/hr```", inline = true })
        end
        if selected["Session Time"] then
            table.insert(fields, { name = "Session Time", value = "```" .. format_time(data.elapsed) .. "```", inline = true })
        end
        if selected["Current Inventory"] then
            table.insert(fields, { name = "In Inventory", value = "```" .. format_number(data.current) .. "```", inline = true })
        end
        if selected["Player"] then
            table.insert(fields, { name = "Player", value = "```" .. LocalPlayer.Name .. "```", inline = true })
        end
        if selected["Server"] then
            table.insert(fields, { name = "Server", value = "```" .. #Players:GetPlayers() .. " players```", inline = true })
        end

        return {
            title = title,
            description = "Session summary for **" .. LocalPlayer.DisplayName .. "**",
            color = 0x57F287,
            fields = fields,
            thumbnail = {
                url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png",
            },
            footer = { text = "Gamesense • " .. config.Item .. " Tracker" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end

    local function send_report(title: string?): boolean
        local config = GlobalConfigs.Stats
        local send = get_request()
        if not send then
            warn("[Stats] this executor has no request function")
            return false
        end
        if not valid_webhook(config.Webhook) then
            warn("[Stats] webhook URL is not a valid Discord webhook")
            return false
        end

        local ok, response = pcall(send, {
            Url = config.Webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                username = "Gamesense Stats",
                embeds = { build_embed(title or "Farming Report") },
            }),
        })

        if not ok then
            warn("[Stats] webhook failed: " .. tostring(response))
            return false
        end
        local status = if typeof(response) == "table" then response.StatusCode else nil
        return status == nil or (status >= 200 and status < 300)
    end

    local function webhook_loop(generation: number)
        while generation == webhook_generation do
            local waited = 0
            local interval = GlobalConfigs.Stats.Interval * 60
            while waited < interval and generation == webhook_generation do
                task.wait(1)
                waited += 1
            end
            if generation == webhook_generation then
                send_report()
            end
        end
    end

    return {
        LogOptions = LOG_OPTIONS,
        Snapshot = snapshot,
        ReadCount = read_count,
        FormatNumber = format_number,
        FormatTime = format_time,

        SendNow = function(): boolean
            return send_report("Farming Report")
        end,

        SetTracking = function(on: boolean)
            poll_generation += 1
            last_count = nil
            if on then
                if not resumed_at then
                    resumed_at = os.clock()
                end
                task.spawn(poll, poll_generation)
            elseif resumed_at then
                active_time += os.clock() - resumed_at
                resumed_at = nil
            end
        end,

        Reset = function()
            active_time = 0
            resumed_at = if resumed_at then os.clock() else nil
            gained = 0
            last_count = nil
        end,

        SetWebhookLoop = function(on: boolean)
            webhook_generation += 1
            if on then
                task.spawn(webhook_loop, webhook_generation)
            end
        end,
    }
end)()

const Registry: { [string]: ConfigEntry } = {}
const RegistryOrder: { string } = {}
local loading = false

local shared_chams: Folder? = nil

const function new_drawing(kind: string, properties: { [string]: any }): any
    local object = Drawing.new(kind)
    for key, value in properties do
        object[key] = value
    end
    return object
end

const function get_chams_folder(): Folder
    if shared_chams and shared_chams.Parent then
        return shared_chams
    end
    local folder = Instance.new("Folder")
    folder.Name = "Chams"
    folder.Parent = if typeof(gethui) == "function" then gethui() else game:GetService("CoreGui")
    shared_chams = folder
    return folder
end

type ObjectTarget = {
    instance: Instance,
    box_outline: any,
    box: any,
    name: any,
    distance: any,
    tracer: any,
    highlight: Highlight?,
    ancestry: RBXScriptConnection,
}

const object_esp = (function()
    local targets: { [Instance]: ObjectTarget } = {}
    local terms: { string } = {}
    local enabled = false
    local generation = 0
    local render_connection: RBXScriptConnection? = nil
    local added_connection: RBXScriptConnection? = nil

    local CORNERS = {
        Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
        Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1),
    }

    local function matches(name: string): boolean
        local lowered = string.lower(name)
        for _, term in terms do
            if string.find(lowered, term, 1, true) then
                return true
            end
        end
        return false
    end

    local function covered(instance: Instance): boolean
        local parent = instance.Parent
        while parent do
            if targets[parent] then
                return true
            end
            parent = parent.Parent
        end
        return false
    end

    local function is_candidate(instance: Instance): boolean
        if not (instance:IsA("Model") or instance:IsA("BasePart")) or instance:IsA("Terrain") then
            return false
        end
        local character = LocalPlayer.Character
        if character and instance:IsDescendantOf(character) then
            return false
        end
        return matches(instance.Name) and not covered(instance)
    end

    local function hide_target(target: ObjectTarget)
        target.box_outline.Visible = false
        target.box.Visible = false
        target.name.Visible = false
        target.distance.Visible = false
        target.tracer.Visible = false
        if target.highlight then
            target.highlight.Enabled = false
        end
    end

    local function remove_target(instance: Instance)
        local target = targets[instance]
        if not target then
            return
        end
        targets[instance] = nil
        target.ancestry:Disconnect()
        for _, drawing in { target.box_outline, target.box, target.name, target.distance, target.tracer } do
            pcall(function()
                drawing:Remove()
            end)
        end
        if target.highlight then
            target.highlight:Destroy()
        end
    end

    local function add_target(instance: Instance)
        if targets[instance] or not is_candidate(instance) then
            return
        end
        targets[instance] = {
            instance = instance,
            box_outline = new_drawing("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), Visible = false }),
            box = new_drawing("Square", { Thickness = 1, Filled = false, Visible = false }),
            name = new_drawing("Text", { Size = 13, Center = true, Outline = true, Font = 2, Visible = false }),
            distance = new_drawing("Text", { Size = 12, Center = true, Outline = true, Font = 2, Visible = false }),
            tracer = new_drawing("Line", { Thickness = 1, Visible = false }),
            highlight = nil,
            ancestry = instance.AncestryChanged:Connect(function()
                if not instance:IsDescendantOf(Workspace) then
                    remove_target(instance)
                end
            end),
        } :: ObjectTarget
    end

    local function clear_targets()
        local pending: { Instance } = {}
        for instance in targets do
            table.insert(pending, instance)
        end
        for _, instance in pending do
            remove_target(instance)
        end
    end

    local function get_bounds(instance: Instance): (CFrame?, Vector3?)
        if instance:IsA("Model") then
            return instance:GetBoundingBox()
        end
        if instance:IsA("BasePart") then
            return instance.CFrame, instance.Size
        end
        return nil, nil
    end

    local function update_chams(target: ObjectTarget, visible: boolean)
        local config = GlobalConfigs.ObjectESP
        if not (visible and config.Chams) then
            if target.highlight then
                target.highlight.Enabled = false
            end
            return
        end
        local highlight = target.highlight
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Adornee = target.instance
            highlight.Parent = get_chams_folder()
            target.highlight = highlight
        end
        local active = highlight :: Highlight
        active.FillColor = config.Color
        active.OutlineColor = Color3.new(1, 1, 1)
        active.Enabled = true
    end

    local function render()
        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        local config = GlobalConfigs.ObjectESP
        local viewport = camera.ViewportSize
        local origin = camera.CFrame.Position
        local stale: { Instance } = {}

        for instance, target in targets do
            if not instance.Parent then
                table.insert(stale, instance)
                continue
            end

            local cframe, size = get_bounds(instance)
            if not cframe or not size then
                hide_target(target)
                continue
            end

            local distance = (cframe.Position - origin).Magnitude
            if distance > config.MaxDistance then
                hide_target(target)
                continue
            end

            update_chams(target, true)

            local center, on_screen = camera:WorldToViewportPoint(cframe.Position)
            if not on_screen then
                target.box_outline.Visible = false
                target.box.Visible = false
                target.name.Visible = false
                target.distance.Visible = false
                target.tracer.Visible = false
                continue
            end

            local min_x, min_y = math.huge, math.huge
            local max_x, max_y = -math.huge, -math.huge
            local half = size * 0.5
            for _, corner in CORNERS do
                local point = camera:WorldToViewportPoint(cframe:PointToWorldSpace(half * corner))
                if point.Z > 0 then
                    min_x = math.min(min_x, point.X)
                    min_y = math.min(min_y, point.Y)
                    max_x = math.max(max_x, point.X)
                    max_y = math.max(max_y, point.Y)
                end
            end

            if min_x == math.huge then
                hide_target(target)
                continue
            end

            local position = Vector2.new(math.floor(min_x), math.floor(min_y))
            local box_size = Vector2.new(math.max(4, math.floor(max_x - min_x)), math.max(4, math.floor(max_y - min_y)))

            target.box_outline.Visible = config.Box
            target.box.Visible = config.Box
            if config.Box then
                target.box_outline.Position = position
                target.box_outline.Size = box_size
                target.box.Position = position
                target.box.Size = box_size
                target.box.Color = config.Color
            end

            target.name.Visible = config.Name
            if config.Name then
                target.name.Text = instance.Name
                target.name.Position = Vector2.new(center.X, position.Y - 16)
                target.name.Color = config.Color
            end

            target.distance.Visible = config.Distance
            if config.Distance then
                target.distance.Text = string.format("[%dm]", math.floor(distance))
                target.distance.Position = Vector2.new(center.X, position.Y + box_size.Y + 2)
                target.distance.Color = Color3.fromRGB(200, 200, 200)
            end

            target.tracer.Visible = config.Tracers
            if config.Tracers then
                target.tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
                target.tracer.To = Vector2.new(center.X, position.Y + box_size.Y)
                target.tracer.Color = config.Color
            end
        end

        for _, instance in stale do
            remove_target(instance)
        end
    end

    local function disconnect()
        if render_connection then
            render_connection:Disconnect()
            render_connection = nil
        end
        if added_connection then
            added_connection:Disconnect()
            added_connection = nil
        end
        clear_targets()
    end

    local function scan(current: number)
        local count = 0
        for _, descendant in Workspace:GetDescendants() do
            if current ~= generation then
                return
            end
            add_target(descendant)
            count += 1
            if count % 4000 == 0 then
                task.wait()
            end
        end
    end

    local function refresh()
        generation += 1
        local current = generation
        disconnect()

        if not enabled or #terms == 0 then
            return
        end

        render_connection = RunService.RenderStepped:Connect(render)
        added_connection = Workspace.DescendantAdded:Connect(add_target)
        task.spawn(scan, current)
    end

    return {
        SetEnabled = function(on: boolean)
            enabled = on
            refresh()
        end,

        SetFilter = function(text: string)
            local parsed: { string } = {}
            for part in string.gmatch(text, "[^,]+") do
                local trimmed = string.lower(part):match("^%s*(.-)%s*$") or ""
                if trimmed ~= "" then
                    table.insert(parsed, trimmed)
                end
            end
            terms = parsed
            refresh()
        end,
    }
end)()

type ESPObject = {
    all: { any },
    box_outline: any,
    box: any,
    name: any,
    distance: any,
    health_text: any,
    bar_back: any,
    bar_fill: any,
    tracer: any,
    bones: { any },
    highlight: Highlight?,
}

const esp = (function()
    local R15_BONES = {
        { "Head", "UpperTorso" },
        { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" },
        { "LeftUpperArm", "LeftLowerArm" },
        { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" },
        { "RightUpperArm", "RightLowerArm" },
        { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" },
        { "LeftUpperLeg", "LeftLowerLeg" },
        { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" },
        { "RightUpperLeg", "RightLowerLeg" },
        { "RightLowerLeg", "RightFoot" },
    }

    local R6_BONES = {
        { "Head", "Torso" },
        { "Torso", "Left Arm" },
        { "Torso", "Right Arm" },
        { "Torso", "Left Leg" },
        { "Torso", "Right Leg" },
    }

    local HEAD_OFFSET = Vector3.new(0, 2.8, 0)
    local FEET_OFFSET = Vector3.new(0, -3.2, 0)
    local BOX_RATIO = 0.6
    local BAR_GAP = 5
    local BAR_WIDTH = 2

    local objects: { [Player]: ESPObject } = {}
    local connection: RBXScriptConnection? = nil
    local removing_connection: RBXScriptConnection? = nil

    local function create_object(): ESPObject
        local all: { any } = {}
        local function track(kind: string, properties: { [string]: any }): any
            local object = new_drawing(kind, properties)
            table.insert(all, object)
            return object
        end

        local bones: { any } = {}
        for _ = 1, #R15_BONES do
            table.insert(bones, track("Line", { Thickness = 1, Visible = false }))
        end

        return {
            all = all,
            box_outline = track("Square", { Thickness = 3, Filled = false, Color = Color3.new(0, 0, 0), Visible = false }),
            box = track("Square", { Thickness = 1, Filled = false, Visible = false }),
            name = track("Text", { Size = 13, Center = true, Outline = true, Font = 2, Visible = false }),
            distance = track("Text", { Size = 12, Center = true, Outline = true, Font = 2, Visible = false }),
            health_text = track("Text", { Size = 12, Center = false, Outline = true, Font = 2, Visible = false }),
            bar_back = track("Square", { Filled = true, Color = Color3.new(0, 0, 0), Transparency = 0.6, Visible = false }),
            bar_fill = track("Square", { Filled = true, Visible = false }),
            tracer = track("Line", { Thickness = 1, Visible = false }),
            bones = bones,
            highlight = nil,
        }
    end

    local function hide_object(object: ESPObject)
        for _, drawing in object.all do
            drawing.Visible = false
        end
        if object.highlight then
            object.highlight.Enabled = false
        end
    end

    local function destroy_object(object: ESPObject)
        for _, drawing in object.all do
            pcall(function()
                drawing:Remove()
            end)
        end
        if object.highlight then
            object.highlight:Destroy()
            object.highlight = nil
        end
    end

    local function read_health(character: Model): (number?, number?)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return humanoid.Health, humanoid.MaxHealth
        end
        local health = character:GetAttribute("Health")
        local max_health = character:GetAttribute("MaxHealth")
        if typeof(health) == "number" then
            return health, if typeof(max_health) == "number" then max_health else 100
        end
        return nil, nil
    end

    local function update_chams(object: ESPObject, character: Model, visible: boolean)
        local config = GlobalConfigs.ESP
        if not (visible and config.Chams) then
            if object.highlight then
                object.highlight.Enabled = false
            end
            return
        end

        local highlight = object.highlight
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.Parent = get_chams_folder()
            object.highlight = highlight
        end

        local active = highlight :: Highlight
        if active.Adornee ~= character then
            active.Adornee = character
        end
        active.FillColor = config.ChamsFill
        active.OutlineColor = config.ChamsOutline
        active.Enabled = true
    end

    local function tracer_origin(viewport: Vector2): Vector2
        local origin = GlobalConfigs.ESP.TracerOrigin
        if origin == "Top" then
            return Vector2.new(viewport.X / 2, 0)
        elseif origin == "Center" then
            return Vector2.new(viewport.X / 2, viewport.Y / 2)
        end
        return Vector2.new(viewport.X / 2, viewport.Y)
    end

    local function update_skeleton(object: ESPObject, character: Model, camera: Camera, enabled: boolean)
        local pairs_list = if character:FindFirstChild("UpperTorso") then R15_BONES else R6_BONES
        local color = GlobalConfigs.ESP.SkeletonColor

        for index, line in object.bones do
            local pair = pairs_list[index]
            if not enabled or not pair then
                line.Visible = false
                continue
            end

            local part_a = character:FindFirstChild(pair[1])
            local part_b = character:FindFirstChild(pair[2])
            if not part_a or not part_b or not part_a:IsA("BasePart") or not part_b:IsA("BasePart") then
                line.Visible = false
                continue
            end

            local a, a_visible = camera:WorldToViewportPoint(part_a.Position)
            local b, b_visible = camera:WorldToViewportPoint(part_b.Position)
            if not a_visible or not b_visible then
                line.Visible = false
                continue
            end

            line.From = Vector2.new(a.X, a.Y)
            line.To = Vector2.new(b.X, b.Y)
            line.Color = color
            line.Visible = true
        end
    end

    local function update_player(player: Player, object: ESPObject, camera: Camera, viewport: Vector2)
        local config = GlobalConfigs.ESP
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not character or not root or not root:IsA("BasePart") then
            hide_object(object)
            return
        end

        if config.TeamCheck and player.Team ~= nil and player.Team == LocalPlayer.Team then
            hide_object(object)
            return
        end

        local health, max_health = read_health(character)
        if health and health <= 0 then
            hide_object(object)
            return
        end

        local distance = (root.Position - camera.CFrame.Position).Magnitude
        if distance > config.MaxDistance then
            hide_object(object)
            return
        end

        update_chams(object, character, true)

        local center, on_screen = camera:WorldToViewportPoint(root.Position)
        if not on_screen then
            for _, drawing in object.all do
                drawing.Visible = false
            end
            return
        end

        local top = camera:WorldToViewportPoint(root.Position + HEAD_OFFSET)
        local bottom = camera:WorldToViewportPoint(root.Position + FEET_OFFSET)
        local height = math.abs(bottom.Y - top.Y)
        local width = height * BOX_RATIO
        local x = math.floor(center.X - width / 2)
        local y = math.floor(top.Y)
        local size = Vector2.new(math.floor(width), math.floor(height))

        local show_box = config.Box
        object.box_outline.Visible = show_box
        object.box.Visible = show_box
        if show_box then
            object.box_outline.Position = Vector2.new(x, y)
            object.box_outline.Size = size
            object.box.Position = Vector2.new(x, y)
            object.box.Size = size
            object.box.Color = config.BoxColor
        end

        object.name.Visible = config.Name
        if config.Name then
            object.name.Text = player.DisplayName
            object.name.Position = Vector2.new(center.X, y - 16)
            object.name.Color = config.NameColor
        end

        object.distance.Visible = config.Distance
        if config.Distance then
            object.distance.Text = string.format("[%dm]", math.floor(distance))
            object.distance.Position = Vector2.new(center.X, y + size.Y + 2)
            object.distance.Color = config.DistanceColor
        end

        local ratio = if health and max_health and max_health > 0 then math.clamp(health / max_health, 0, 1) else nil
        local health_color = if ratio then Color3.fromRGB(255, 50, 50):Lerp(Color3.fromRGB(60, 255, 90), ratio) else Color3.new(1, 1, 1)

        local show_bar = config.HealthBar and ratio ~= nil
        object.bar_back.Visible = show_bar
        object.bar_fill.Visible = show_bar
        if show_bar and ratio then
            local bar_x = x - BAR_GAP - BAR_WIDTH
            local fill_height = math.max(1, math.floor(size.Y * ratio))
            object.bar_back.Position = Vector2.new(bar_x - 1, y - 1)
            object.bar_back.Size = Vector2.new(BAR_WIDTH + 2, size.Y + 2)
            object.bar_fill.Position = Vector2.new(bar_x, y + size.Y - fill_height)
            object.bar_fill.Size = Vector2.new(BAR_WIDTH, fill_height)
            object.bar_fill.Color = health_color
        end

        local show_health_text = config.HealthText and health ~= nil
        object.health_text.Visible = show_health_text
        if show_health_text and health then
            object.health_text.Text = tostring(math.floor(health)) .. " HP"
            object.health_text.Position = Vector2.new(x + size.X + 4, y)
            object.health_text.Color = health_color
        end

        object.tracer.Visible = config.Tracers
        if config.Tracers then
            object.tracer.From = tracer_origin(viewport)
            object.tracer.To = Vector2.new(center.X, y + size.Y)
            object.tracer.Color = config.TracerColor
        end

        update_skeleton(object, character, camera, config.Skeleton)
    end

    local function render()
        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end
        local viewport = camera.ViewportSize

        for _, player in Players:GetPlayers() do
            if player == LocalPlayer then
                continue
            end
            local object = objects[player]
            if not object then
                object = create_object()
                objects[player] = object
            end
            update_player(player, object, camera, viewport)
        end
    end

    local function release_player(player: Player)
        local object = objects[player]
        if not object then
            return
        end
        objects[player] = nil
        destroy_object(object)
    end

    local function set_enabled(on: boolean)
        if on then
            if connection then
                return
            end
            connection = RunService.RenderStepped:Connect(render)
            removing_connection = Players.PlayerRemoving:Connect(release_player)
            return
        end

        if connection then
            connection:Disconnect()
            connection = nil
        end
        if removing_connection then
            removing_connection:Disconnect()
            removing_connection = nil
        end
        for player in objects do
            release_player(player)
        end
    end

    return {
        SetEnabled = set_enabled,
        IsSupported = function(): boolean
            return typeof(Drawing) == "table" or typeof(Drawing) == "userdata"
        end,
    }
end)()

const function bind(key: string, kind: string, default: any, callback: (any) -> (), persist: boolean?): (any) -> ()
    local entry: ConfigEntry = {
        kind = kind,
        default = default,
        value = default,
        callback = callback,
        element = nil,
        persist = persist ~= false,
    }
    Registry[key] = entry
    table.insert(RegistryOrder, key)

    return function(value: any)
        entry.value = value
        if loading then
            return
        end
        callback(value)
    end
end

const function attach(key: string, element: any): any
    local entry = Registry[key]
    if entry then
        entry.element = element
    end
    return element
end

const function call_first(element: any, methods: { string }, ...: any): boolean
    if not element then
        return false
    end
    for _, method in methods do
        local ok, fn = pcall(function()
            return element[method]
        end)
        if ok and typeof(fn) == "function" then
            if pcall(fn, element, ...) then
                return true
            end
        end
    end
    return false
end

const function add_control(box: any, methods: { string }, options: { [string]: any }): any
    for _, method in methods do
        local ok, fn = pcall(function()
            return box[method]
        end)
        if ok and typeof(fn) == "function" then
            return fn(box, options)
        end
    end
    return nil
end

const CONFIG_ROOT = "LegendUI"
const CONFIG_FOLDER = "LegendUI/FarmConfigs"

const function notify(text: string)
    print("[Config] " .. text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Config",
            Text = text,
            Duration = 3,
        })
    end)
end

const function files_supported(): boolean
    return typeof(writefile) == "function"
        and typeof(readfile) == "function"
        and typeof(isfile) == "function"
        and typeof(isfolder) == "function"
        and typeof(makefolder) == "function"
        and typeof(listfiles) == "function"
end

const function ensure_folders()
    for _, path in { CONFIG_ROOT, CONFIG_FOLDER } do
        if not isfolder(path) then
            makefolder(path)
        end
    end
end

const function clean_name(name: string?): string
    local cleaned = tostring(name or ""):gsub("[^%w _%-]", "")
    cleaned = cleaned:match("^%s*(.-)%s*$") or ""
    return cleaned:sub(1, 32)
end

const function config_path(name: string): string
    return CONFIG_FOLDER .. "/" .. name .. ".json"
end

const function list_configs(): { string }
    local names: { string } = {}
    if not files_supported() then
        return names
    end
    ensure_folders()
    for _, path in listfiles(CONFIG_FOLDER) do
        local name = tostring(path):match("([^/\\]+)%.json$")
        if name then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

const function save_config(raw_name: string?): boolean
    if not files_supported() then
        notify("Executor has no file support")
        return false
    end
    local name = clean_name(raw_name)
    if name == "" then
        notify("Enter a config name first")
        return false
    end

    local data = {}
    for _, key in RegistryOrder do
        local entry = Registry[key]
        if entry.persist then
            data[key] = entry.value
        end
    end

    ensure_folders()
    local ok, err = pcall(function()
        writefile(config_path(name), HttpService:JSONEncode(data))
    end)
    if not ok then
        warn("[Config] save failed: " .. tostring(err))
        notify("Failed to save " .. name)
        return false
    end
    notify("Saved " .. name)
    return true
end

const function load_config(raw_name: string?): boolean
    if not files_supported() then
        notify("Executor has no file support")
        return false
    end
    local name = clean_name(raw_name)
    if name == "" or not isfile(config_path(name)) then
        notify("Config not found")
        return false
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(config_path(name)))
    end)
    if not ok or typeof(data) ~= "table" then
        notify("Config is corrupted")
        return false
    end
    loading = true
    for pass = 1, 2 do
        for _, key in RegistryOrder do
            local entry = Registry[key]
            local value = data[key]
            if value == nil or not entry.persist then
                continue
            end
            if (entry.kind == "toggle") ~= (pass == 2) then
                continue
            end
            if typeof(value) ~= typeof(entry.default) then
                continue
            end
            local previous = entry.value
            entry.value = value
            pcall(call_first, entry.element, { "Set" }, value)
            if entry.kind == "toggle" and previous == value then
                continue
            end
            task.spawn(entry.callback, value)
        end
    end
    task.delay(0.3, function()
        loading = false
    end)
    notify("Loaded " .. name)
    return true
end

const function delete_config(raw_name: string?): boolean
    local name = clean_name(raw_name)
    if not files_supported() or typeof(delfile) ~= "function" or name == "" or not isfile(config_path(name)) then
        notify("Nothing to delete")
        return false
    end
    pcall(delfile, config_path(name))
    notify("Deleted " .. name)
    return true
end

local FarmVelocityConnection: RBXScriptConnection? = nil
local harvest_limit_generation = 0

on_unload(function()
    harvest_limit_generation += 1
    if FarmVelocityConnection then
        FarmVelocityConnection:Disconnect()
        FarmVelocityConnection = nil
    end
end)

-- FarmTween_Toggle = attach("FarmTween.Enabled", Auto_Tween:AddToggle({
--     Text = "Velocity Tween",
--     Callback = bind("FarmTween.Enabled", "toggle", false, function(_FarmTween: boolean)
--         GlobalConfigs.FarmTween.Enabled = _FarmTween

--         if FarmVelocityConnection then
--             FarmVelocityConnection:Disconnect()
--             FarmVelocityConnection = nil
--         end

--         if not _FarmTween then
--             functionbank.StopMoving()
--             return
--         end

--         local target: Vector3? = nil
--         local retarget_at = 0

--         FarmVelocityConnection = RunService.Heartbeat:Connect(function(dt)
--             if not GlobalConfigs.FarmTween.Enabled then
--                 if FarmVelocityConnection then
--                     FarmVelocityConnection:Disconnect()
--                     FarmVelocityConnection = nil
--                 end
--                 functionbank.StopMoving()
--                 return
--             end

--             local avoid_radius = if GlobalConfigs.FarmTween.AvoidPlayers then GlobalConfigs.FarmTween.AvoidRadius else nil

--             local now = os.clock()
--             if now >= retarget_at then
--                 retarget_at = now + 0.1
--                 target = functionbank.GetTweenTarget(
--                     GlobalConfigs.FarmTween.Type,
--                     GlobalConfigs.FarmTween.Distance,
--                     avoid_radius
--                 )
--             end

--             if not target then
--                 functionbank.StopMoving()
--                 return
--             end

--             functionbank.MoveToward(
--                 target,
--                 GlobalConfigs.FarmTween.Speed,
--                 GlobalConfigs.FarmTween.StopDistance,
--                 dt
--             )
--         end)
--     end),
-- }))

-- FarmTween_AvoidPlayers = attach("FarmTween.AvoidPlayers", Auto_Tween:AddToggle({
--     Text = "Avoid Players",
--     Callback = bind("FarmTween.AvoidPlayers", "toggle", false, function(_Value: boolean)
--         GlobalConfigs.FarmTween.AvoidPlayers = _Value
--     end),
-- }))

-- FarmTween_AvoidRadius = attach("FarmTween.AvoidRadius", Auto_Tween:AddSlider({
--     Text = "Avoid Radius",
--     Min = 5,
--     Max = 60,
--     Default = GlobalConfigs.FarmTween.AvoidRadius,
--     Increment = 1,
--     Suffix = " studs",
--     Callback = bind("FarmTween.AvoidRadius", "slider", GlobalConfigs.FarmTween.AvoidRadius, function(_Radius: number)
--         GlobalConfigs.FarmTween.AvoidRadius = _Radius
--     end),
-- }))

-- WalkOnWater_Toggle = attach("Water.Enabled", Auto_Tween:AddToggle({
--     Text = "Walk On Water",
--     Callback = bind("Water.Enabled", "toggle", false, function(_Water: boolean)
--         GlobalConfigs.Water.Enabled = _Water
--         functionbank.SetWalkOnWater(_Water)
--     end),
-- }))

-- Auto_Tween:AddSeparator("Settings")

-- FarmTween_Type = attach("FarmTween.Targets", Auto_Tween:AddMultiDropdown({
--     Text = "Targets",
--     Options = { "Plant Boxes", "Prioritize Bushes" },
--     Default = {},
--     Callback = bind("FarmTween.Targets", "multi", {}, function(_Selected: { string })
--         for _, key in tween_modes do
--             GlobalConfigs.FarmTween.Type[key] = false
--         end
--         for _, name in _Selected do
--             local key = tween_modes[name]
--             if key then
--                 GlobalConfigs.FarmTween.Type[key] = true
--             end
--         end
--     end),
-- }))

-- FarmTween_Speed = attach("FarmTween.Speed", Auto_Tween:AddSlider({
--     Text = "Tween Speed",
--     Min = 1,
--     Max = 20,
--     Default = GlobalConfigs.FarmTween.Speed,
--     Increment = 0.5,
--     Suffix = " studs/s",
--     Callback = bind("FarmTween.Speed", "slider", GlobalConfigs.FarmTween.Speed, function(_Speed: number)
--         GlobalConfigs.FarmTween.Speed = _Speed
--     end),
-- }))

-- FarmTween_Distance = attach("FarmTween.Distance", Auto_Tween:AddSlider({
--     Text = "Tween Distance",
--     Min = 0,
--     Max = 1500,
--     Default = GlobalConfigs.FarmTween.Distance,
--     Increment = 1,
--     Suffix = " studs",
--     Callback = bind("FarmTween.Distance", "slider", GlobalConfigs.FarmTween.Distance, function(_Distance: number)
--         GlobalConfigs.FarmTween.Distance = _Distance
--     end),
-- }))

-- AutoPickup_Toggle = attach("AutoPickup.Enabled", Auto_Pickup:AddToggle({
--     Text = "Auto Pickup",
--     Keybind = Enum.KeyCode.E,
--     Callback = bind("AutoPickup.Enabled", "toggle", false, function(_AutoPickup: boolean)
--         GlobalConfigs.AutoPickup.Enabled = _AutoPickup
--         task.spawn(function()
--             while GlobalConfigs.AutoPickup.Enabled and _AutoPickup do
--                 task.wait(GlobalConfigs.AutoPickup.Speed)
--                 local ids = functionbank.GetItemsByID(GlobalConfigs.AutoPickup.Filter, GlobalConfigs.AutoPickup.Distance)
--                 if #ids == 0 then
--                     continue
--                 end
--                 for _, id in ids do
--                     Packets.Pickup.send(id)
--                 end
--             end
--         end)
--     end),
-- }))

-- Auto_Pickup:AddSeparator("Settings")

-- AutoPickup_Slider = attach("AutoPickup.Distance", Auto_Pickup:AddSlider({
--     Text = "Distance",
--     Min = 10,
--     Max = 100,
--     Default = GlobalConfigs.AutoPickup.Distance,
--     Increment = 1,
--     Suffix = " studs",
--     Callback = bind("AutoPickup.Distance", "slider", GlobalConfigs.AutoPickup.Distance, function(_Distance: number)
--         GlobalConfigs.AutoPickup.Distance = _Distance
--     end),
-- }))

-- AutoPickup_Filter = attach("AutoPickup.Filter", Auto_Pickup:AddTextbox({
--     Text = "Item Filter",
--     Default = GlobalConfigs.AutoPickup.Filter,
--     Placeholder = "Leave empty for everything",
--     Callback = bind("AutoPickup.Filter", "textbox", GlobalConfigs.AutoPickup.Filter, function(_Filter: string)
--         GlobalConfigs.AutoPickup.Filter = (tostring(_Filter or "")):match("^%s*(.-)%s*$") or ""
--     end),
-- }))

-- AutoEat_Toggle = attach("AutoEat.Enabled", AutoEat:AddToggle({
--     Text = "Auto Eat",
--     Callback = bind("AutoEat.Enabled", "toggle", false, function(_Enabled: boolean)
--         functionbank.SetAutoEat(_Enabled)
--     end),
-- }))

-- AutoEat_Threshold = attach("AutoEat.Threshold", AutoEat:AddSlider({
--     Text = "Hunger Threshold",
--     Min = 1,
--     Max = 100,
--     Default = GlobalConfigs.AutoEat.Threshold,
--     Increment = 1,
--     Suffix = "%",
--     Callback = bind("AutoEat.Threshold", "slider", GlobalConfigs.AutoEat.Threshold, function(_Threshold: number)
--         GlobalConfigs.AutoEat.Threshold = _Threshold
--     end),
-- }))

-- AutoEat_Fruit = attach("AutoEat.Fruit", AutoEat:AddDropdown({
--     Text = "Fruit",
--     Options = functionbank.GetFruitOptions(),
--     Searchable = true,
--     Default = GlobalConfigs.AutoEat.Fruit,
--     Callback = bind("AutoEat.Fruit", "dropdown", GlobalConfigs.AutoEat.Fruit, function(_Fruit: string)
--         GlobalConfigs.AutoEat.Fruit = _Fruit
--     end),
-- }))

-- AutoPlant_Toggle = attach("AutoPlant.Enabled", Auto_Plant:AddToggle({
--     Text = "Auto Plant",
--     Callback = bind("AutoPlant.Enabled", "toggle", false, function(_AutoPlant: boolean)
--         GlobalConfigs.AutoPlant.Enabled = _AutoPlant
--         task.spawn(function()
--             while GlobalConfigs.AutoPlant.Enabled and _AutoPlant do
--                 task.wait(GlobalConfigs.AutoPlant.Speed)
--                 local fruits = GlobalConfigs.AutoPlant.SelectedFruits
--                 if #fruits == 0 then
--                     continue
--                 end
--                 local id, fruit = functionbank.ClaimNearestPlant(
--                     GlobalConfigs.AutoPlant.Distance,
--                     fruits,
--                     GlobalConfigs.AutoPlant.Cooldown
--                 )
--                 if not id or not fruit then
--                     continue
--                 end
--                 Packets.InteractStructure.send({
--                     entityID = id,
--                     itemID = ItemIDS[fruit],
--                 })
--             end
--         end)
--     end),
-- }))

-- AutoHarvest_Toggle = attach("AutoHarvest.Enabled", Auto_Plant:AddToggle({
--     Text = "Auto Harvest",
--     Callback = bind("AutoHarvest.Enabled", "toggle", false, function(_AutoHarvest: boolean)
--         GlobalConfigs.AutoHarvest.Enabled = _AutoHarvest
--         task.spawn(function()
--             while GlobalConfigs.AutoHarvest.Enabled and _AutoHarvest do
--                 task.wait(GlobalConfigs.AutoHarvest.Speed)
--                 local ids = functionbank.GetCropsInRange(GlobalConfigs.AutoHarvest.Distance)
--                 if #ids == 0 then
--                     continue
--                 end
--                 for _, id in ids do
--                     Packets.Pickup.send(id)
--                 end
--             end
--         end)
--     end),
-- }))

-- Auto_Plant:AddSeparator("Settings")

-- AutoPlant_Distance = attach("AutoPlant.Distance", Auto_Plant:AddSlider({
--     Text = "Distance",
--     Min = 10,
--     Max = 100,
--     Default = GlobalConfigs.AutoPlant.Distance,
--     Increment = 1,
--     Suffix = " studs",
--     Callback = bind("AutoPlant.Distance", "slider", GlobalConfigs.AutoPlant.Distance, function(_Distance: number)
--         GlobalConfigs.AutoPlant.Distance = _Distance
--     end),
-- }))

-- AutoHarvest_Distance = attach("AutoHarvest.Distance", Auto_Plant:AddSlider({
--     Text = "Harvest Distance",
--     Min = 10,
--     Max = 100,
--     Default = GlobalConfigs.AutoHarvest.Distance,
--     Increment = 1,
--     Suffix = " studs",
--     Callback = bind("AutoHarvest.Distance", "slider", GlobalConfigs.AutoHarvest.Distance, function(_Distance: number)
--         GlobalConfigs.AutoHarvest.Distance = _Distance
--     end),
-- }))

-- const function stop_harvest_and_bushes()
--     GlobalConfigs.AutoHarvest.Enabled = false
--     local harvest_entry = Registry["AutoHarvest.Enabled"]
--     if harvest_entry then
--         harvest_entry.value = false
--     end
--     call_first(AutoHarvest_Toggle, { "Set" }, false)

--     GlobalConfigs.FarmTween.Type["PrioritizeBushes"] = false
--     local targets_entry = Registry["FarmTween.Targets"]
--     local remaining: { string } = {}
--     if targets_entry and typeof(targets_entry.value) == "table" then
--         for _, name in targets_entry.value do
--             if name ~= "Prioritize Bushes" then
--                 table.insert(remaining, name)
--             end
--         end
--         targets_entry.value = remaining
--     end
--     call_first(FarmTween_Type, { "Set" }, remaining)
-- end

-- const function selected_fruit_total(): number?
--     local names = GlobalConfigs.AutoPlant.SelectedFruits
--     if #names == 0 then
--         names = { GlobalConfigs.Stats.Item }
--     end

--     local total = 0
--     for _, name in names do
--         local count = stats.ReadCount(name)
--         if not count then
--             return nil
--         end
--         total += count
--     end
--     return total
-- end

-- const function run_harvest_limit(generation: number)
--     while generation == harvest_limit_generation do
--         task.wait(0.5)

--         local limit = GlobalConfigs.AutoHarvest.StopAt
--         if limit <= 0 then
--             continue
--         end

--         local active = GlobalConfigs.AutoHarvest.Enabled or GlobalConfigs.FarmTween.Type["PrioritizeBushes"]
--         if not active then
--             continue
--         end

--         local total = selected_fruit_total()
--         if total and total >= limit then
--             stop_harvest_and_bushes()
--             notify("Reached " .. stats.FormatNumber(limit) .. " fruit")
--         end
--     end
-- end

-- AutoHarvest_StopAt = attach("AutoHarvest.StopAt", Auto_Plant:AddTextbox({
--     Text = "Stop Harvest At",
--     Default = "",
--     Placeholder = "Fruit amount (empty = off)",
--     Callback = bind("AutoHarvest.StopAt", "textbox", "", function(_Amount: string)
--         local cleaned = (tostring(_Amount or "")):gsub(",", "")
--         local amount = tonumber(cleaned) or 0
--         GlobalConfigs.AutoHarvest.StopAt = math.max(0, math.floor(amount))
--         harvest_limit_generation += 1
--         if GlobalConfigs.AutoHarvest.StopAt > 0 then
--             task.spawn(run_harvest_limit, harvest_limit_generation)
--         end
--     end),
-- }))

-- AutoPlant_Fruit = attach("AutoPlant.Fruits", Auto_Plant:AddMultiDropdown({
--     Text = "Fruits",
--     Searchable = true,
--     Options = functionbank.GetFruitOptions(),
--     Default = GlobalConfigs.AutoPlant.SelectedFruits,
--     Callback = bind("AutoPlant.Fruits", "multi", GlobalConfigs.AutoPlant.SelectedFruits, function(_Selected: { string })
--         GlobalConfigs.AutoPlant.SelectedFruits = _Selected
--     end),
-- }))

-- AutoPlant_Speed = attach("AutoPlant.Speed", Auto_Plant:AddDropdown({
--     Text = "Speed",
--     Options = { "Fast", "Optimized", "Slow" },
--     Default = "Fast",
--     Callback = bind("AutoPlant.Speed", "dropdown", "Optimized", function(_Selected: string)
--         local speed = speed_presets[_Selected]
--         if speed then
--             GlobalConfigs.AutoPlant.Speed = speed
--         end
--     end),
-- }))

-- HidePlantBoxes_Toggle = attach("Performance.HidePlantBoxes", Auto_Performance:AddToggle({
--     Text = "Hide Plant Boxes",
--     Callback = bind("Performance.HidePlantBoxes", "toggle", false, function(_Hide: boolean)
--         GlobalConfigs.Performance.HidePlantBoxes = _Hide
--         functionbank.SetHidePlantBoxes(_Hide)
--     end),
-- }))

-- HideBushes_Toggle = attach("Performance.HideBushes", Auto_Performance:AddToggle({
--     Text = "Hide Bushes",
--     Callback = bind("Performance.HideBushes", "toggle", false, function(_Hide: boolean)
--         GlobalConfigs.Performance.HideBushes = _Hide
--         functionbank.SetHideBushes(_Hide)
--     end),
-- }))

-- NoCollide_Dropdown = attach("Performance.NoCollide", Auto_Performance:AddMultiDropdown({
--     Text = "No Collision",
--     Options = { "Bushes", "Plant Box", "Bed", "Clan Bed" },
--     Default = {},
--     Callback = bind("Performance.NoCollide", "multi", {}, function(_Selected: { string })
--         functionbank.SetNoCollide(_Selected)
--     end),
-- }))

-- HideWorld_Dropdown = attach("Performance.HideWorld", Auto_Performance:AddMultiDropdown({
--     Text = "Hide",
--     Options = { "Resources", "Critters" },
--     Default = {},
--     Callback = bind("Performance.HideWorld", "multi", {}, function(_Selected: { string })
--         functionbank.SetHiddenFolders(_Selected)
--     end),
-- }))

-- FarmBuilder_Preview = attach("FarmBuilder.Preview", Auto_PlantBox:AddToggle({
--     Text = "Preview",
--     Callback = bind("FarmBuilder.Preview", "toggle", false, function(_Preview: boolean)
--         GlobalConfigs.FarmBuilder.Preview = _Preview
--         if not _Preview then
--             functionbank.ClearPreview()
--             return
--         end
--         task.spawn(function()
--             while GlobalConfigs.FarmBuilder.Preview and _Preview do
--                 if not functionbank.IsBuilding() then
--                     functionbank.RefreshPreview(GlobalConfigs.FarmBuilder.Amount, GlobalConfigs.FarmBuilder.Shape)
--                 end
--                 task.wait(0.2)
--             end
--             functionbank.ClearPreview()
--         end)
--     end, false),
-- }))

-- FarmBuilder_Toggle = attach("FarmBuilder.Enabled", Auto_PlantBox:AddToggle({
--     Text = "Auto Build",
--     Callback = bind("FarmBuilder.Enabled", "toggle", false, function(_Build: boolean)
--         GlobalConfigs.FarmBuilder.Enabled = _Build
--         if not _Build then
--             return
--         end
--         task.spawn(function()
--             functionbank.BuildFarm(GlobalConfigs.FarmBuilder, function()
--                 return GlobalConfigs.FarmBuilder.Enabled and _Build
--             end)
--         end)
--     end, false),
-- }))

-- Auto_PlantBox:AddSeparator("Settings")

-- FarmBuilder_Amount = attach("FarmBuilder.Amount", Auto_PlantBox:AddSlider({
--     Text = "Size",
--     Min = 1,
--     Max = 150,
--     Default = GlobalConfigs.FarmBuilder.Amount,
--     Increment = 1,
--     Suffix = " boxes",
--     Callback = bind("FarmBuilder.Amount", "slider", GlobalConfigs.FarmBuilder.Amount, function(_Amount: number)
--         GlobalConfigs.FarmBuilder.Amount = _Amount
--     end),
-- }))

-- FarmBuilder_AvoidWater = attach("FarmBuilder.AvoidWater", Auto_PlantBox:AddToggle({
--     Text = "Detect Terrain / Avoid Water",
--     Callback = bind("FarmBuilder.AvoidWater", "toggle", GlobalConfigs.FarmBuilder.AvoidWater, function(_AvoidWater: boolean)
--         GlobalConfigs.FarmBuilder.AvoidWater = _AvoidWater
--     end),
-- }))

-- FarmBuilder_Shape = attach("FarmBuilder.Shape", Auto_PlantBox:AddDropdown({
--     Text = "Shape",
--     Options = { "Square", "Hollow Square", "Circle", "Diamond", "Line" },
--     Default = GlobalConfigs.FarmBuilder.Shape,
--     Callback = bind("FarmBuilder.Shape", "dropdown", GlobalConfigs.FarmBuilder.Shape, function(_Shape: string)
--         GlobalConfigs.FarmBuilder.Shape = _Shape
--     end),
-- }))

-- FarmBuilder_Speed = attach("FarmBuilder.Speed", Auto_PlantBox:AddDropdown({
--     Text = "Speed",
--     Options = { "Fast", "Optimized", "Slow" },
--     Default = "Fast",
--     Callback = bind("FarmBuilder.Speed", "dropdown", "Fast", function(_Selected: string)
--         local speed = speed_presets[_Selected]
--         if speed then
--             GlobalConfigs.FarmBuilder.Speed = speed
--         end
--     end),
-- }))

-- DockBuilder_Preview = attach("DockBuilder.Preview", Auto_DockBox:AddToggle({
--     Text = "Preview",
--     Callback = bind("DockBuilder.Preview", "toggle", false, function(_Preview: boolean)
--         GlobalConfigs.DockBuilder.Preview = _Preview
--         if not _Preview then
--             functionbank.ClearDockPreview()
--             return
--         end
--         task.spawn(function()
--             while GlobalConfigs.DockBuilder.Preview and _Preview do
--                 if not functionbank.IsBuilding() then
--                     functionbank.RefreshDockPreview(GlobalConfigs.DockBuilder.Amount, GlobalConfigs.DockBuilder.Shape)
--                 end
--                 task.wait(0.2)
--             end
--             functionbank.ClearDockPreview()
--         end)
--     end, false),
-- }))

-- DockBuilder_Toggle = attach("DockBuilder.Enabled", Auto_DockBox:AddToggle({
--     Text = "Auto Build",
--     Callback = bind("DockBuilder.Enabled", "toggle", false, function(_Build: boolean)
--         GlobalConfigs.DockBuilder.Enabled = _Build
--         if not _Build then
--             return
--         end
--         task.spawn(function()
--             functionbank.BuildDocks(GlobalConfigs.DockBuilder, function()
--                 return GlobalConfigs.DockBuilder.Enabled and _Build
--             end)
--         end)
--     end, false),
-- }))

-- Auto_DockBox:AddSeparator("Settings")

-- DockBuilder_Amount = attach("DockBuilder.Amount", Auto_DockBox:AddSlider({
--     Text = "Size",
--     Min = 1,
--     Max = 40,
--     Default = GlobalConfigs.DockBuilder.Amount,
--     Increment = 1,
--     Suffix = " docks",
--     Callback = bind("DockBuilder.Amount", "slider", GlobalConfigs.DockBuilder.Amount, function(_Amount: number)
--         GlobalConfigs.DockBuilder.Amount = _Amount
--     end),
-- }))

-- DockBuilder_Shape = attach("DockBuilder.Shape", Auto_DockBox:AddDropdown({
--     Text = "Shape",
--     Options = { "Square", "Hollow Square", "Circle", "Diamond", "Line" },
--     Default = GlobalConfigs.DockBuilder.Shape,
--     Callback = bind("DockBuilder.Shape", "dropdown", GlobalConfigs.DockBuilder.Shape, function(_Shape: string)
--         GlobalConfigs.DockBuilder.Shape = _Shape
--     end),
-- }))

-- DockBuilder_Speed = attach("DockBuilder.Speed", Auto_DockBox:AddDropdown({
--     Text = "Speed",
--     Options = { "Fast", "Optimized", "Slow" },
--     Default = "Fast",
--     Callback = bind("DockBuilder.Speed", "dropdown", "Fast", function(_Selected: string)
--         local speed = speed_presets[_Selected]
--         if speed then
--             GlobalConfigs.DockBuilder.Speed = speed
--         end
--     end),
-- }))

AutoHit_Toggle = attach("Combat.AutoHit", CombatBox:AddToggle({
    Text = "Auto Hit",
    Callback = bind("Combat.AutoHit", "toggle", false, function(_AutoHit: boolean)
        GlobalConfigs.Combat.AutoHit = _AutoHit
        task.spawn(function()
            local last_anim = 0
            while GlobalConfigs.Combat.AutoHit and _AutoHit do
                task.wait()
                if not functionbank.SwingTool() then
                    continue
                end
                if not GlobalConfigs.Combat.AutoSwing then
                    continue
                end
                local now = os.clock()
                if now - last_anim >= GlobalConfigs.Combat.AnimCooldown then
                    last_anim = now
                    Animations.playAnimation("Slash")
                end
            end
        end)
    end),
}))

AutoSwing_Toggle = attach("Combat.AutoSwing", CombatBox:AddToggle({
    Text = "Auto Swing",
    Callback = bind("Combat.AutoSwing", "toggle", false, function(_AutoSwing: boolean)
        GlobalConfigs.Combat.AutoSwing = _AutoSwing
    end),
}))

CombatBox:AddSeparator("Settings")

AutoHit_Targets = attach("Combat.Targets", CombatBox:AddMultiDropdown({
    Text = "Targets",
    Options = { "Resources", "Critters", "Players", "Deployables", "Rubble" },
    Default = GlobalConfigs.Combat.Targets,
    Callback = bind("Combat.Targets", "multi", GlobalConfigs.Combat.Targets, function(_Selected: { string })
        GlobalConfigs.Combat.Targets = _Selected
    end),
}))

local config_name = "default"
local config_options = list_configs()

ConfigName_Input = Config_Box:AddTextbox({
    Text = "Config Name",
    Default = config_name,
    Placeholder = "Type a config name...",
    Callback = function(_Name: string, _Entered: boolean?)
        config_name = clean_name(_Name)
    end,
})

ConfigList_Dropdown = Config_Box:AddDropdown({
    Text = "Saved Configs",
    Options = if #config_options > 0 then config_options else { "None" },
    Default = if #config_options > 0 then config_options[1] else "None",
    Callback = function(_Selected: string)
        if _Selected ~= "None" then
            config_name = _Selected
            call_first(ConfigName_Input, { "Set" }, _Selected)
        end
    end,
})

const function refresh_config_list()
    local names = list_configs()
    call_first(ConfigList_Dropdown, { "SetOptions", "Refresh", "UpdateOptions", "SetValues" }, if #names > 0 then names else { "None" })
end

add_control(Config_Box, { "AddButton" }, {
    Text = "Save Config",
    Callback = function()
        if save_config(config_name) then
            refresh_config_list()
        end
    end,
})

add_control(Config_Box, { "AddButton" }, {
    Text = "Load Config",
    Callback = function()
        load_config(config_name)
    end,
})

add_control(Config_Box, { "AddButton" }, {
    Text = "Delete Config",
    Callback = function()
        if delete_config(config_name) then
            refresh_config_list()
        end
    end,
})

add_control(Config_Box, { "AddButton" }, {
    Text = "Refresh List",
    Callback = refresh_config_list,
})

keep(LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end))

Config_Box:AddDropdown({
    Text = "UI-SIZE",
    Options = {
        "100%",
        "125%",
        "150%",
        "200%"
    },
    Default = "100%",
    Callback = function(value)
        local percentage = tonumber(tostring(value):match("%d+"))

        if percentage then
            window:SetUIScale(percentage)
            print("UI scale:", window:GetUIScale())
        end
    end,
})

SearchESP_Toggle = attach("ObjectESP.Enabled", ESP_Search:AddToggle({
    Text = "Enable Search ESP",
    Callback = bind("ObjectESP.Enabled", "toggle", false, function(_Enabled: boolean)
        GlobalConfigs.ObjectESP.Enabled = _Enabled
        if _Enabled and not esp.IsSupported() then
            warn("[ESP] this executor has no Drawing library")
            return
        end
        object_esp.SetEnabled(_Enabled)
    end),
}))

SearchESP_Filter = attach("ObjectESP.Filter", ESP_Search:AddTextbox({
    Text = "Search",
    Default = GlobalConfigs.ObjectESP.Filter,
    Placeholder = "Gold Node, Iron Node",
    Callback = bind("ObjectESP.Filter", "textbox", GlobalConfigs.ObjectESP.Filter, function(_Filter: string)
        GlobalConfigs.ObjectESP.Filter = tostring(_Filter or "")
        object_esp.SetFilter(GlobalConfigs.ObjectESP.Filter)
    end),
}))

ESP_Search:AddSeparator("Features")

SearchESP_Box = attach("ObjectESP.Box", ESP_Search:AddToggle({
    Text = "Box",
    Default = true,
    Callback = bind("ObjectESP.Box", "toggle", true, function(_Value: boolean)
        GlobalConfigs.ObjectESP.Box = _Value
    end),
}))

SearchESP_Name = attach("ObjectESP.Name", ESP_Search:AddToggle({
    Text = "Name",
    Default = true,
    Callback = bind("ObjectESP.Name", "toggle", true, function(_Value: boolean)
        GlobalConfigs.ObjectESP.Name = _Value
    end),
}))

SearchESP_Distance = attach("ObjectESP.Distance", ESP_Search:AddToggle({
    Text = "Distance",
    Default = true,
    Callback = bind("ObjectESP.Distance", "toggle", true, function(_Value: boolean)
        GlobalConfigs.ObjectESP.Distance = _Value
    end),
}))

SearchESP_Tracers = attach("ObjectESP.Tracers", ESP_Search:AddToggle({
    Text = "Lines",
    Callback = bind("ObjectESP.Tracers", "toggle", false, function(_Value: boolean)
        GlobalConfigs.ObjectESP.Tracers = _Value
    end),
}))

SearchESP_Chams = attach("ObjectESP.Chams", ESP_Search:AddToggle({
    Text = "Chams",
    Callback = bind("ObjectESP.Chams", "toggle", false, function(_Value: boolean)
        GlobalConfigs.ObjectESP.Chams = _Value
    end),
}))

SearchESP_MaxDistance = attach("ObjectESP.MaxDistance", ESP_Search:AddSlider({
    Text = "Max Distance",
    Min = 50,
    Max = 5000,
    Default = GlobalConfigs.ObjectESP.MaxDistance,
    Increment = 50,
    Suffix = " studs",
    Callback = bind("ObjectESP.MaxDistance", "slider", GlobalConfigs.ObjectESP.MaxDistance, function(_Distance: number)
        GlobalConfigs.ObjectESP.MaxDistance = _Distance
    end),
}))

ESP_Toggle = attach("ESP.Enabled", ESP_Box:AddToggle({
    Text = "Enable ESP",
    Callback = bind("ESP.Enabled", "toggle", false, function(_Enabled: boolean)
        GlobalConfigs.ESP.Enabled = _Enabled
        if _Enabled and not esp.IsSupported() then
            warn("[ESP] this executor has no Drawing library")
            return
        end
        esp.SetEnabled(_Enabled)
    end),
}))

ESP_Box:AddSeparator("Features")

ESP_BoxToggle = attach("ESP.Box", ESP_Box:AddToggle({
    Text = "Box",
    Default = true,
    Callback = bind("ESP.Box", "toggle", true, function(_Value: boolean)
        GlobalConfigs.ESP.Box = _Value
    end),
}))

ESP_NameToggle = attach("ESP.Name", ESP_Box:AddToggle({
    Text = "Name",
    Default = true,
    Callback = bind("ESP.Name", "toggle", true, function(_Value: boolean)
        GlobalConfigs.ESP.Name = _Value
    end),
}))

ESP_DistanceToggle = attach("ESP.Distance", ESP_Box:AddToggle({
    Text = "Distance",
    Default = true,
    Callback = bind("ESP.Distance", "toggle", true, function(_Value: boolean)
        GlobalConfigs.ESP.Distance = _Value
    end),
}))

ESP_SkeletonToggle = attach("ESP.Skeleton", ESP_Box:AddToggle({
    Text = "Skeleton",
    Callback = bind("ESP.Skeleton", "toggle", false, function(_Value: boolean)
        GlobalConfigs.ESP.Skeleton = _Value
    end),
}))

ESP_HealthBarToggle = attach("ESP.HealthBar", ESP_Box:AddToggle({
    Text = "Health Bar",
    Default = true,
    Callback = bind("ESP.HealthBar", "toggle", true, function(_Value: boolean)
        GlobalConfigs.ESP.HealthBar = _Value
    end),
}))

ESP_TracersToggle = attach("ESP.Tracers", ESP_Box:AddToggle({
    Text = "Lines",
    Callback = bind("ESP.Tracers", "toggle", false, function(_Value: boolean)
        GlobalConfigs.ESP.Tracers = _Value
    end),
}))

ESP_ChamsToggle = attach("ESP.Chams", ESP_Box:AddToggle({
    Text = "Chams",
    Callback = bind("ESP.Chams", "toggle", false, function(_Value: boolean)
        GlobalConfigs.ESP.Chams = _Value
    end),
}))

ESP_MaxDistance = attach("ESP.MaxDistance", ESP_Settings:AddSlider({
    Text = "Max Distance",
    Min = 50,
    Max = 3000,
    Default = GlobalConfigs.ESP.MaxDistance,
    Increment = 50,
    Suffix = " studs",
    Callback = bind("ESP.MaxDistance", "slider", GlobalConfigs.ESP.MaxDistance, function(_Distance: number)
        GlobalConfigs.ESP.MaxDistance = _Distance
    end),
}))

ESP_TracerOrigin = attach("ESP.TracerOrigin", ESP_Settings:AddDropdown({
    Text = "Line Origin",
    Options = { "Bottom", "Center", "Top" },
    Default = GlobalConfigs.ESP.TracerOrigin,
    Callback = bind("ESP.TracerOrigin", "dropdown", GlobalConfigs.ESP.TracerOrigin, function(_Origin: string)
        GlobalConfigs.ESP.TracerOrigin = _Origin
    end),
}))

StatsTracking_Toggle = attach("Stats.Enabled", Stats_Box:AddToggle({
    Text = "Track Stats",
    Callback = bind("Stats.Enabled", "toggle", false, function(_Enabled: boolean)
        GlobalConfigs.Stats.Enabled = _Enabled
        stats.SetTracking(_Enabled)
    end),
}))

StatsItem_Input = attach("Stats.Item", Stats_Box:AddTextbox({
    Text = "Tracked Item",
    Default = GlobalConfigs.Stats.Item,
    Placeholder = "Bloodfruit",
    Callback = bind("Stats.Item", "textbox", GlobalConfigs.Stats.Item, function(_Item: string)
        local cleaned = (tostring(_Item or "")):match("^%s*(.-)%s*$") or ""
        if cleaned == "" then
            return
        end
        GlobalConfigs.Stats.Item = cleaned
        stats.Reset()
    end),
}))

Stats_Box:AddSeparator("Session")

const function stats_label(text: string): any
    return add_control(Stats_Box, { "AddLabel", "AddParagraph" }, { Text = text })
end

local StatsGainedLabel = stats_label("Gained: 0")
local StatsRateLabel = stats_label("Rate: 0/hr")
local StatsTimeLabel = stats_label("Time: 0h 00m 00s")
local StatsInventoryLabel = stats_label("Inventory: 0")

add_control(Stats_Box, { "AddButton" }, {
    Text = "Reset Stats",
    Callback = function()
        stats.Reset()
    end,
})

local stats_running = true
on_unload(function()
    stats_running = false
    stats.SetTracking(false)
    stats.SetWebhookLoop(false)
end)

task.spawn(function()
    while stats_running do
        task.wait(1)
        local data = stats.Snapshot()
        local item = GlobalConfigs.Stats.Item
        call_first(StatsGainedLabel, { "SetText", "Set", "UpdateText" }, item .. " Gained: " .. stats.FormatNumber(data.gained))
        call_first(StatsRateLabel, { "SetText", "Set", "UpdateText" }, "Rate: " .. stats.FormatNumber(data.rate) .. "/hr")
        call_first(StatsTimeLabel, { "SetText", "Set", "UpdateText" }, "Time: " .. stats.FormatTime(data.elapsed))
        call_first(StatsInventoryLabel, { "SetText", "Set", "UpdateText" }, "Inventory: " .. stats.FormatNumber(data.current))
    end
end)

WebhookURL_Input = attach("Stats.Webhook", Webhook_Box:AddTextbox({
    Text = "Webhook URL",
    Default = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = bind("Stats.Webhook", "textbox", "", function(_Url: string)
        GlobalConfigs.Stats.Webhook = (tostring(_Url or "")):match("^%s*(.-)%s*$") or ""
    end, false),
}))

WebhookToggle = attach("Stats.WebhookEnabled", Webhook_Box:AddToggle({
    Text = "Send Reports",
    Callback = bind("Stats.WebhookEnabled", "toggle", false, function(_Enabled: boolean)
        GlobalConfigs.Stats.WebhookEnabled = _Enabled
        stats.SetWebhookLoop(_Enabled)
    end),
}))

WebhookLog_Dropdown = attach("Stats.Log", Webhook_Box:AddMultiDropdown({
    Text = "Log",
    Options = stats.LogOptions,
    Default = GlobalConfigs.Stats.Log,
    Callback = bind("Stats.Log", "multi", GlobalConfigs.Stats.Log, function(_Selected: { string })
        GlobalConfigs.Stats.Log = _Selected
    end),
}))

WebhookInterval = attach("Stats.Interval", Webhook_Box:AddSlider({
    Text = "Interval",
    Min = 1,
    Max = 60,
    Default = GlobalConfigs.Stats.Interval,
    Increment = 1,
    Suffix = " min",
    Callback = bind("Stats.Interval", "slider", GlobalConfigs.Stats.Interval, function(_Minutes: number)
        GlobalConfigs.Stats.Interval = _Minutes
    end),
}))

add_control(Webhook_Box, { "AddButton" }, {
    Text = "Send Test Report",
    Callback = function()
        stats.SendNow()
    end,
})

Watermark_Toggle = attach("HUD.Watermark", HudBox:AddToggle({
    Text = "Watermark",
    Callback = bind("HUD.Watermark", "toggle", false, function(_Enabled: boolean)
        GlobalConfigs.HUD.Watermark = _Enabled
        watermark:SetVisible(_Enabled)
    end),
}))

PrivateMode_Toggle = attach("HUD.Private", HudBox:AddToggle({
    Text = "Private Mode",
    Default = GlobalConfigs.HUD.Private,
    Callback = bind("HUD.Private", "toggle", GlobalConfigs.HUD.Private, function(_Enabled: boolean)
        GlobalConfigs.HUD.Private = _Enabled
        watermark:SetPrivate(_Enabled)
    end),
}))

KeybindList_Toggle = attach("HUD.KeybindList", HudBox:AddToggle({
    Text = "Keybind List",
    Callback = bind("HUD.KeybindList", "toggle", false, function(_Enabled: boolean)
        GlobalConfigs.HUD.KeybindList = _Enabled
        keybinds:SetVisible(_Enabled)
    end),
}))

watermark:SetVisible(false)
keybinds:SetVisible(false)

on_unload(function()
    esp.SetEnabled(false)
    object_esp.SetEnabled(false)
    pcall(function()
        watermark:SetVisible(false)
        keybinds:SetVisible(false)
    end)
    if shared_chams then
        shared_chams:Destroy()
        shared_chams = nil
    end
end)

add_control(Config_Box, { "AddButton" }, {
    Text = "Unload Script",
    Callback = env.GamesenseCleanup,
})

range = HudBox:AddRangeSlider({
    Text = "Damage Range",
    Min = 0,
    Max = 100,
    DefaultMin = 20,
    DefaultMax = 80,
    Increment = 1,
    Callback = function(minimum, maximum)
        print(minimum, maximum)
    end
})

minimum, maximum = range:Get()
range:Set(10, 90)
