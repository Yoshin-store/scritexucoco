-- Loading the stable LinoriaLib from the official repository
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()

-- Initializing the Window
local Window = Library:CreateWindow({
    Title = 'Vanguard',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- Creating structured Tabs
local Tabs = {
    Main = Window:AddTab('Visual ESP Hub'),
    Settings = Window:AddTab('Settings')
}

-- Organizing the layout into clean Left and Right GroupBoxes
local FilterBox = Tabs.Main:AddLeftGroupbox('Search Parameters')
local ActionBox = Tabs.Main:AddRightGroupbox('Execution Engine')
local CleanupBox = Tabs.Settings:AddLeftGroupbox('Controls & Management')

-- Target Environment Paths
local Workspace = game:GetService("Workspace")
local thingsCrystals = Workspace:WaitForChild("Things"):WaitForChild("Crystals")
local droppedCrystals = Workspace:FindFirstChild("Dropped Crystals") or Workspace:FindFirstChild("DroppedCrystals")
local localPlayer = game:GetService("Players").LocalPlayer

-- Filter State Management (Plain Integers, Max bumped to 10,000kg / 10 Tons)
local filterTier = nil
local filterValue = nil
local filterLuck = nil
local minWeightSelected = 0
local maxWeightSelected = 10000 
local scriptRunning = true

-- Visual Object Memory Trackers
local activeHighlights = {}
local activeBillboards = {}

-- Safely clear visual objects from workspace
local function clearVisuals()
    for _, hl in ipairs(activeHighlights) do if hl and hl.Parent then hl:Destroy() end end
    for _, bb in ipairs(activeBillboards) do if bb and bb.Parent then bb:Destroy() end end
    activeHighlights = {}
    activeBillboards = {}
end

-- Formats large values into clean metric displays
local function formatNumber(num)
    if not num then return "0" end
    if num >= 1e9 then return string.format("%.1fB", num / 1e9) end
    if num >= 1e6 then return string.format("%.1fM", num / 1e6) end
    if num >= 1e3 then return string.format("%.1fK", num / 1e3) end
    return tostring(num)
end

-- Safely scans and combines standard and dropped world folders
local function getAllCrystals()
    local list = {}
    if thingsCrystals then
        for _, c in ipairs(thingsCrystals:GetChildren()) do table.insert(list, c) end
    end
    droppedCrystals = Workspace:FindFirstChild("Dropped Crystals") or Workspace:FindFirstChild("DroppedCrystals")
    if droppedCrystals then
        for _, c in ipairs(droppedCrystals:GetChildren()) do table.insert(list, c) end
    end
    return list
end

-- Attaches outline highlights and 3D info panels
local function attachVisualsToCrystal(crystal, highlightColor)
    local targetPart = crystal:IsA("BasePart") and crystal or crystal:FindFirstChildWhichIsA("BasePart")
    if not targetPart then return end

    -- Wallhack Silhouette Outline Glow
    local highlight = Instance.new("Highlight")
    highlight.FillColor = highlightColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.4
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = crystal
    table.insert(activeHighlights, highlight)

    -- Clean Modernized 3D Info Billboard UI
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 115)
    billboard.AlwaysOnTop = true  
    billboard.StudsOffset = Vector3.new(0, 4.5, 0) 
    billboard.Adornee = targetPart
    billboard.Parent = targetPart
    table.insert(activeBillboards, billboard)

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = highlightColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = mainFrame
    mainFrame.Parent = billboard

    local cName = crystal:GetAttribute("CrystalName") or crystal.Name
    local tier = crystal:GetAttribute("Tier") or 0
    local value = crystal:GetAttribute("Value") or 0
    local weight = crystal:GetAttribute("WeightKg") or 0
    
    local rawLuck = crystal:GetAttribute("Luck") or crystal:GetAttribute("LuckBonus") or 0
    local displayLuck = rawLuck
    if rawLuck > 0 and rawLuck <= 1 then
        displayLuck = rawLuck * 100 
    end
    
    local isDropped = (droppedCrystals and crystal.Parent == droppedCrystals)
    local sourceTag = isDropped and " [DROPPED]" or ""

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.Parent = mainFrame

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(0, 180, 0, 22)
    headerLabel.BackgroundTransparency = 1
    headerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 12
    headerLabel.RichText = true
    headerLabel.Text = string.format("%s<font color='#9b59b6'>%s</font> <font color='#FFA500'>[T%d]</font>", cName, sourceTag, tier)
    headerLabel.LayoutOrder = 1
    headerLabel.Parent = mainFrame

    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(0, 180, 0, 55)
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
    statsLabel.Font = Enum.Font.GothamSemibold
    statsLabel.TextSize = 11
    statsLabel.TextXAlignment = Enum.TextXAlignment.Left
    statsLabel.RichText = true
    statsLabel.LayoutOrder = 2
    statsLabel.Parent = mainFrame

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(0, 180, 0, 15)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextSize = 10
    distanceLabel.LayoutOrder = 3
    distanceLabel.Parent = mainFrame

    -- Dynamic position updates running via background thread
    task.spawn(function()
        while scriptRunning and billboard and billboard.Parent and localPlayer.Character do
            local char = localPlayer.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local distanceStr = "Distance: -- studs"
            
            if root then
                local distance = (targetPart.Position - root.Position).Magnitude
                distanceStr = string.format("📍 Distance: %d studs", distance)
            end

            statsLabel.Text = string.format(
                "💰 <b>Value:</b> <font color='#00FF00'>%s</font>\n" ..
                "⚖️ <b>Weight:</b> <font color='#3498db'>%.2f kg</font>\n" ..
                "🍀 <b>Luck Bonus:</b> <font color='#1abc9c'>+%.0f%%</font>",
                formatNumber(value), weight, displayLuck
            )
            
            distanceLabel.Text = distanceStr
            task.wait(0.4)
        end
    end)
end

-- Master Filtration Execution Engine
local function runFilters(isBestOnly)
    clearVisuals()
    
    local bestCrystal = nil
    local maxTier, maxValue, maxLuck, maxWeight = -1, -1, -1, -1
    local matchCount = 0

    local currentCrystals = getAllCrystals()
    if #currentCrystals == 0 then
        Library:Notify("No active crystals found to filter right now.", 3)
        return
    end

    for _, crystal in ipairs(currentCrystals) do
        local crystalTier = crystal:GetAttribute("Tier") or 0
        local crystalValue = crystal:GetAttribute("Value") or 0
        local crystalWeight = crystal:GetAttribute("WeightKg") or 0

        local rawLuck = crystal:GetAttribute("Luck") or crystal:GetAttribute("LuckBonus") or 0
        local crystalLuck = rawLuck
        if rawLuck > 0 and rawLuck <= 1 then
            crystalLuck = rawLuck * 100
        end

        if isBestOnly then
            if crystalTier > maxTier then
                maxTier, maxValue, maxLuck, maxWeight, bestCrystal = crystalTier, crystalValue, crystalLuck, crystalWeight, crystal
            elseif crystalTier == maxTier and crystalValue > maxValue then
                maxValue, maxLuck, maxWeight, bestCrystal = crystalValue, crystalLuck, crystalWeight, crystal
            elseif crystalTier == maxTier and crystalValue == maxValue and crystalLuck > maxLuck then
                maxLuck, maxWeight, bestCrystal = crystalLuck, crystalWeight, crystal
            elseif crystalTier == maxTier and crystalValue == maxValue and crystalLuck == maxLuck and crystalWeight > maxWeight then
                maxWeight, bestCrystal = crystalWeight, crystal
            end
        else
            -- Direct Integer Weight Range Check Logic
            local passesTier = (not filterTier) or (crystalTier == filterTier)
            local passesValue = (not filterValue) or (crystalValue >= filterValue)
            local passesLuck = (not filterLuck) or (crystalLuck >= filterLuck)
            local passesWeight = (crystalWeight >= minWeightSelected) and (crystalWeight <= maxWeightSelected)

            if passesTier and passesValue and passesLuck and passesWeight then
                local r = crystal:GetAttribute("TierColorR") or 0
                local g = crystal:GetAttribute("TierColorG") or 255
                local b = crystal:GetAttribute("TierColorB") or 255
                attachVisualsToCrystal(crystal, Color3.fromRGB(r, g, b))
                matchCount = matchCount + 1
            end
        end
    end

    if isBestOnly and bestCrystal then
        attachVisualsToCrystal(bestCrystal, Color3.fromRGB(255, 30, 30))
        local isDropped = (droppedCrystals and bestCrystal.Parent == droppedCrystals)
        local cLoc = isDropped and "Dropped Folder" or "Spawn Folder"
        Library:Notify("Target Acquired inside: " .. cLoc, 4)
    elseif not isBestOnly then
        Library:Notify("Scan Complete: Tagged " .. tostring(matchCount) .. " crystals globally.", 4)
    end
end

-- ==========================================
-- Interface Building (Linoria Framework)
-- ==========================================

FilterBox:AddInput('TierInput', {
    Default = '',
    Numeric = true,
    Finished = false,
    Text = 'Filter by Tier Match (1-6)',
    Placeholder = 'Empty = All',
    Callback = function(Value) filterTier = tonumber(Value) end
})

FilterBox:AddInput('ValueInput', {
    Default = '',
    Numeric = true,
    Finished = false,
    Text = 'Filter by Minimum Value',
    Placeholder = 'Ex: 100000',
    Callback = function(Value) filterValue = tonumber(Value) end
})

FilterBox:AddInput('LuckInput', {
    Default = '',
    Numeric = true,
    Finished = false,
    Text = 'Filter by Minimum Luck (%)',
    Placeholder = 'Ex: 50',
    Callback = function(Value) filterLuck = tonumber(Value) end
})

-- Sliders bumped up to 10,000 Kg limits
FilterBox:AddSlider('MinW', {
    Text = 'Weight Range: FROM',
    Default = 0,
    Min = 0,
    Max = 10000,
    Rounding = 0,
    Compact = false,
    Suffix = ' Kg',
    Callback = function(Value) minWeightSelected = Value end
})

FilterBox:AddSlider('MaxW', {
    Text = 'Weight Range: TO',
    Default = 10000,
    Min = 0,
    Max = 10000,
    Rounding = 0,
    Compact = false,
    Suffix = ' Kg',
    Callback = function(Value) maxWeightSelected = Value end
})

ActionBox:AddButton('Target Absolute Best Crystal', function() runFilters(true) end)
ActionBox:AddButton('Execute Custom Query Filters', function() runFilters(false) end)

CleanupBox:AddButton('Wipe Existing ESP Visuals', function()
    clearVisuals()
    Library:Notify('All visual assets completely dropped.', 2)
end)

CleanupBox:AddButton('🔴 Completely Unload Script', function()
    scriptRunning = false 
    clearVisuals()       
    Library:Unload() 
end)

-- Initialize watermark in the top corner
Library:SetWatermark('Vanguard')
