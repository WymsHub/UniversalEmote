
local repo = 'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
local Options = Library.Options
local Toggles = Library.Toggles

-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- i asked ai to name all the parts of the script, thats why u will see many notes, but the code is not ai.
-- its mainly just to help new scripters out.

-- Player / Character
local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer.PlayerGui
local Backpack = localPlayer.Backpack
local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()

-- Camera / Rendering
local Camera = Workspace.CurrentCamera

-- ESP Colors
local COLOR_ARMED   = Color3.fromRGB(255, 0, 0)
local COLOR_UNARMED = Color3.fromRGB(0, 255, 0)
local COLOR_DEAD    = Color3.fromRGB(140, 140, 140)
local FILL_TRANSPARENCY    = 0.6
local OUTLINE_TRANSPARENCY = 0

-- Hitbox
local EXPANSION_FACTOR = 3.0
local EXPAND_R6  = { "Head" }
local EXPAND_R15 = { "Head" }

-- Head Converter
local RENAME_R6  = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local RENAME_R15 = {
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot"
}

-- Attachment defaults
local attachValues = {
    SightAtt       = "Reflex",
    BarrelAtt      = "Suppressor",
    UnderBarrelAtt = "Bipod",
    OtherAtt       = "Laser",
}

-- State flags
local trackedNpcs      = {}
local evidenceLabels   = {}
local trackedPrompts   = {}
local originalSizes    = {}
local renamedParts     = {}
local originalSettings = {}

local expandEnabled      = false
local headConvertEnabled = false
local recoilEnabled      = false
local spreadEnabled      = false
local ammoEnabled        = false
local fullAutoEnabled    = false
local attachEnabled      = false
local autoReloadEnabled  = false
local silentAimEnabled   = false
local wallPenEnabled     = false
local fovEnabled         = false
local fovRadius          = 100
local speedEnabled       = false
local speedValue         = 40
local originalSpeed      = nil

-- Evidence config
local EVIDENCE_NAMES = {
    Cash   = { "CashEvidence", "CashRecoverEvidence" },
    Laptop = { "LaptopEvidence" },
}
local EVIDENCE_COLORS = {
    Cash   = Color3.fromRGB(255, 220, 50),
    Laptop = Color3.fromRGB(80, 180, 255),
}

-----([-----])-----

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = true
Library.NotifySide = "Left"

local Window = Library:CreateWindow({
	Title = 'Tactical: Swat Simulator - Open Source',
	Center = true,
	AutoShow = true,
	Resizable = true,
	ShowCustomCursor = true,
	NotifySide = "Left",
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	CombatTAB     = Window:AddTab('Combat'),
	PlayerTAB     = Window:AddTab('Player'),
	AttachmentTAB = Window:AddTab('Attachments'),
	['UI Settings'] = Window:AddTab('UI Settings'),
}

local SilentAimSection      = Tabs.CombatTAB:AddLeftGroupbox('Silent Aim')
local HitboxExpanderSection = Tabs.CombatTAB:AddLeftGroupbox('Hitbox Expander')
local MiscSection           = Tabs.CombatTAB:AddLeftGroupbox('Misc')
local InteractSection       = Tabs.CombatTAB:AddRightGroupbox('Interaction')
local GunModSection         = Tabs.CombatTAB:AddRightGroupbox('Gun Mods')
local AttachmentSection     = Tabs.AttachmentTAB:AddLeftGroupbox('Gun Attachments')
local AttachmentInfoSection = Tabs.AttachmentTAB:AddRightGroupbox('Attachments Info')
local VisualSection         = Tabs.PlayerTAB:AddLeftGroupbox('Visuals')
local MovementSection       = Tabs.PlayerTAB:AddLeftGroupbox('Movement')

-----([-----])-----
-- ESP
local function applyESP(npc: Instance)
	if not npc:IsA("Model") or npc.Name ~= "NPC" or npc.Parent ~= Workspace then return end
	local humanoid = npc:WaitForChild("Humanoid", 3) :: Humanoid?
	local highlight = npc:FindFirstChild("ESPHighlight") :: Highlight
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "ESPHighlight"
		highlight.FillTransparency = FILL_TRANSPARENCY
		highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
		highlight.Parent = npc
	end
	local isDead = false
	local function updateColor()
		if not (Toggles.NpcEspToggle and Toggles.NpcEspToggle.Value) then
			highlight.Enabled = false
			return
		end
		highlight.Enabled = false
		local hasTool = npc:FindFirstChildOfClass("Tool") ~= nil
		local filters = Options.NpcEspFilter and Options.NpcEspFilter.Value or {}
		local showDead      = filters["Dead"]
		local showEnemies   = filters["Enemies"]
		local showCivilians = filters["Civilians"]
		if isDead then
			if showDead then
				highlight.FillColor = COLOR_DEAD
				highlight.OutlineColor = COLOR_DEAD
				highlight.Enabled = true
			end
		elseif hasTool then
			if showEnemies then
				highlight.FillColor = COLOR_ARMED
				highlight.OutlineColor = COLOR_ARMED
				highlight.Enabled = true
			end
		else
			if showCivilians then
				highlight.FillColor = COLOR_UNARMED
				highlight.OutlineColor = COLOR_UNARMED
				highlight.Enabled = true
			end
		end
	end
	trackedNpcs[npc] = updateColor
	if humanoid then
		if humanoid.Health <= 0 then isDead = true end
		humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then isDead = true end
			updateColor()
		end)
		humanoid.Died:Connect(function()
			isDead = true
			task.defer(updateColor)
		end)
	end
	npc.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then updateColor() end
	end)
	npc.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then updateColor() end
	end)
	npc.Destroying:Connect(function()
		trackedNpcs[npc] = nil
	end)
	updateColor()
end

local function refreshAllESP()
	for npc, updateFunc in pairs(trackedNpcs) do
		if npc and npc.Parent then
			updateFunc()
		else
			trackedNpcs[npc] = nil
		end
	end
end

local function getDistance(pos: Vector3): number
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then return math.floor((root.Position - pos).Magnitude) end
	return 0
end

local function removeEvidenceLabel(part: BasePart)
	local entry = evidenceLabels[part]
	if entry then
		if entry.label and entry.label.Parent then entry.label:Destroy() end
		evidenceLabels[part] = nil
	end
end

local function createEvidenceLabel(part: BasePart, labelText: string, color: Color3)
	if evidenceLabels[part] then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EvidenceESP"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, 120, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Adornee = part
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.TextSize = 12
	label.Text = labelText .. "\n0m"
	label.Parent = billboard
	evidenceLabels[part] = { billboard = billboard, label = label, baseText = labelText }
	part.Destroying:Connect(function() removeEvidenceLabel(part) end)
end

local function refreshEvidenceESP()
	local filters = Options.EvidenceEspFilter and Options.EvidenceEspFilter.Value or {}
	local showCash   = filters["Cash"]
	local showLaptop = filters["Laptop"]
	for _, child in Workspace:GetChildren() do
		local isCash   = table.find(EVIDENCE_NAMES.Cash, child.Name) ~= nil
		local isLaptop = table.find(EVIDENCE_NAMES.Laptop, child.Name) ~= nil
		if (isCash or isLaptop) and child:IsA("BasePart") then
			local wantShow = (isCash and showCash) or (isLaptop and showLaptop)
			local key      = isCash and "Cash" or "Laptop"
			if wantShow then
				if not evidenceLabels[child] then
					createEvidenceLabel(child, key, EVIDENCE_COLORS[key])
				end
			else
				removeEvidenceLabel(child)
			end
		end
	end
	for part, _ in pairs(evidenceLabels) do
		if not part or not part.Parent then removeEvidenceLabel(part) end
	end
end

RunService.RenderStepped:Connect(function()
	for part, entry in pairs(evidenceLabels) do
		if part and part.Parent and entry.label then
			entry.label.Text = entry.baseText .. "\n" .. getDistance(part.Position) .. "m"
		end
	end
end)

VisualSection:AddToggle('NpcEspToggle', {
	Text = 'Enable ESP',
	Default = false,
	Callback = function() refreshAllESP() end
})
VisualSection:AddDropdown('NpcEspFilter', {
	Values = { 'Enemies', 'Civilians', 'Dead' },
	Default = 1,
	Multi = true,
	Text = 'NPC ESP Filter',
	Callback = function() refreshAllESP() end
})
VisualSection:AddDropdown('EvidenceEspFilter', {
	Values = { 'Cash', 'Laptop' },
	Default = {},
	Multi = true,
	Text = 'Evidence ESP Filter',
	Callback = function() refreshEvidenceESP() end
})

Toggles.NpcEspToggle:OnChanged(refreshAllESP)
Options.NpcEspFilter:OnChanged(refreshAllESP)
Options.EvidenceEspFilter:OnChanged(refreshEvidenceESP)

for _, child in Workspace:GetChildren() do task.spawn(applyESP, child) end
Workspace.ChildAdded:Connect(function(child)
	applyESP(child)
	local isCash   = table.find(EVIDENCE_NAMES.Cash, child.Name) ~= nil
	local isLaptop = table.find(EVIDENCE_NAMES.Laptop, child.Name) ~= nil
	if (isCash or isLaptop) and child:IsA("BasePart") then refreshEvidenceESP() end
end)
Workspace.ChildRemoved:Connect(function(child)
	if evidenceLabels[child] then removeEvidenceLabel(child) end
end)

-----([-----])-----
-- Instant Prompts
local function trackPrompt(prompt: ProximityPrompt)
	if trackedPrompts[prompt] then return end
	trackedPrompts[prompt] = prompt.HoldDuration
	if Toggles.InstantPromptsToggle and Toggles.InstantPromptsToggle.Value then
		prompt.HoldDuration = 0
	end
	prompt.AncestryChanged:Connect(function()
		if not prompt.Parent then trackedPrompts[prompt] = nil end
	end)
end

local function applyInstantToAll(instant: boolean)
	for prompt, original in pairs(trackedPrompts) do
		if prompt and prompt.Parent then
			prompt.HoldDuration = instant and 0 or original
		end
	end
end

for _, desc in ipairs(Workspace:GetDescendants()) do
	if desc:IsA("ProximityPrompt") then trackPrompt(desc) end
end
Workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("ProximityPrompt") then trackPrompt(desc) end
end)

InteractSection:AddToggle('InstantPromptsToggle', {
	Text = 'Instant Interact',
	Default = false,
	Callback = function(value) applyInstantToAll(value) end
})
Toggles.InstantPromptsToggle:OnChanged(function()
	applyInstantToAll(Toggles.InstantPromptsToggle.Value)
end)

-----([-----])-----
-- Hitbox Expander
local function restoreNPC(npc)
	if not npc or not npc:IsA("Model") then return end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local parts = humanoid.RigType == Enum.HumanoidRigType.R6 and EXPAND_R6 or EXPAND_R15
	for _, partName in ipairs(parts) do
		local part = npc:FindFirstChild(partName)
		if part and part:IsA("BasePart") and originalSizes[part] then
			part.Size = originalSizes[part]
		end
	end
end

local function expandNPC(npc)
	if not npc or not npc:IsA("Model") then return end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local parts = humanoid.RigType == Enum.HumanoidRigType.R6 and EXPAND_R6 or EXPAND_R15
	for _, partName in ipairs(parts) do
		local part = npc:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			if not originalSizes[part] then originalSizes[part] = part.Size end
			part.Size = originalSizes[part] * EXPANSION_FACTOR
		end
	end
end

local function applyExpandToAll()
	for _, npc in ipairs(CollectionService:GetTagged("NPC")) do
		if expandEnabled then expandNPC(npc) else restoreNPC(npc) end
	end
end

HitboxExpanderSection:AddToggle('NPCExpander', {
	Text = 'Enable Hitbox Expander',
	Default = false,
	Callback = function(value)
		expandEnabled = value
		applyExpandToAll()
	end
})
HitboxExpanderSection:AddSlider('NPCExpandFactor', {
	Text = 'Hitbox Size',
	Default = 3,
	Min = 1,
	Max = 30,
	Rounding = 1,
	Callback = function(value)
		EXPANSION_FACTOR = value
		if expandEnabled then applyExpandToAll() end
	end
})

CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(npc)
	if expandEnabled then expandNPC(npc) end
end)
RunService.RenderStepped:Connect(function()
	if expandEnabled then applyExpandToAll() end
end)

-----([-----])-----
-- Head Converter
local function convertToHead(npc)
	if not npc or not npc:IsA("Model") then return end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local parts = humanoid.RigType == Enum.HumanoidRigType.R6 and RENAME_R6 or RENAME_R15
	for _, partName in ipairs(parts) do
		local part = npc:FindFirstChild(partName)
		if part and part:IsA("BasePart") and part.Name ~= "Head" then
			if not renamedParts[part] then renamedParts[part] = part.Name end
			part.Name = "Head"
		end
	end
end

local function restoreHeadNames(npc)
	if not npc or not npc:IsA("Model") then return end
	for _, child in ipairs(npc:GetChildren()) do
		if child:IsA("BasePart") and renamedParts[child] then
			child.Name = renamedParts[child]
			renamedParts[child] = nil
		end
	end
end

local function convertAllNPCs()
	for _, npc in ipairs(CollectionService:GetTagged("NPC")) do convertToHead(npc) end
end

local function restoreAllNPCs()
	for _, npc in ipairs(CollectionService:GetTagged("NPC")) do restoreHeadNames(npc) end
	renamedParts = {}
end

MiscSection:AddToggle('HeadConverter', {
	Text = 'Always Head Shot',
	Tooltip = 'this will break npc animations',
	Default = false,
	Callback = function(value)
		headConvertEnabled = value
		if value then convertAllNPCs() else restoreAllNPCs() end
	end
})

CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(npc)
	if headConvertEnabled then convertToHead(npc) end
end)
RunService.RenderStepped:Connect(function()
	if headConvertEnabled then convertAllNPCs() end
end)

-----([-----])-----
-- Shout Buttons
InteractSection:AddButton({
	Text = 'Shout at All Civilians',
	DoubleClick = false,
	Func = function()
		local ShoutEvent = ReplicatedStorage.Network.ShoutNPC
		task.spawn(function()
			for _, npc in ipairs(Workspace:GetChildren()) do
				if npc:IsA("Model") and npc.Name == "NPC" and not npc:FindFirstChildOfClass("Tool") then
					ShoutEvent:FireServer(npc)
					task.wait(1.1)
				end
			end
		end)
	end,
})
InteractSection:AddButton({
	Text = 'Shout at All Enemies',
	DoubleClick = false,
	Func = function()
		local ShoutEvent = ReplicatedStorage.Network.ShoutNPC
		task.spawn(function()
			for _, npc in ipairs(Workspace:GetChildren()) do
				if npc:IsA("Model") and npc.Name == "NPC" and npc:FindFirstChildOfClass("Tool") then
					ShoutEvent:FireServer(npc)
					task.wait(1.1)
				end
			end
		end)
	end,
})

-----([-----])-----
-- Gun Mods (ACS)
local function cacheOriginalGun(tool)
	if not (tool:IsA("Tool") and tool:FindFirstChild("ACS_Settings")) then return end
	if originalSettings[tool] then return end
	local settings = require(tool.ACS_Settings)
	originalSettings[tool] = {
		camRecoil               = settings.camRecoil,
		gunRecoil               = settings.gunRecoil,
		MinSpread               = settings.MinSpread,
		MaxSpread               = settings.MaxSpread,
		AimInaccuracyStepAmount = settings.AimInaccuracyStepAmount,
		AimInaccuracyDecrease   = settings.AimInaccuracyDecrease,
		WalkMult                = settings.WalkMult,
		MinRecoilPower          = settings.MinRecoilPower,
		MaxRecoilPower          = settings.MaxRecoilPower,
		RecoilPowerStepAmount   = settings.RecoilPowerStepAmount,
		Ammo                    = settings.Ammo,
		AmmoInGun               = settings.AmmoInGun,
		StoredAmmo              = settings.StoredAmmo,
		MaxStoredAmmo           = settings.MaxStoredAmmo,
		CanCheckMag             = settings.CanCheckMag,
		SlideLock               = settings.SlideLock,
		ShootType               = settings.ShootType,
		SightAtt                = settings.SightAtt,
		BarrelAtt               = settings.BarrelAtt,
		UnderBarrelAtt          = settings.UnderBarrelAtt,
		OtherAtt                = settings.OtherAtt,
	}
end

local function applyRecoil(tool)
	if not (tool:IsA("Tool") and tool:FindFirstChild("ACS_Settings")) then return end
	cacheOriginalGun(tool)
	local settings = require(tool.ACS_Settings)
	if recoilEnabled then
		settings.camRecoil = { camRecoilUp={0,0}, camRecoilTilt={0,0}, camRecoilLeft={0,0}, camRecoilRight={0,0} }
		settings.gunRecoil = { gunRecoilUp={0,0}, gunRecoilTilt={0,0}, gunRecoilLeft={0,0}, gunRecoilRight={0,0} }
		settings.MinRecoilPower        = 0
		settings.MaxRecoilPower        = 0
		settings.RecoilPowerStepAmount = 0
	else
		local o = originalSettings[tool]
		if not o then return end
		settings.camRecoil             = o.camRecoil
		settings.gunRecoil             = o.gunRecoil
		settings.MinRecoilPower        = o.MinRecoilPower
		settings.MaxRecoilPower        = o.MaxRecoilPower
		settings.RecoilPowerStepAmount = o.RecoilPowerStepAmount
	end
end

local function applySpread(tool)
	if not (tool:IsA("Tool") and tool:FindFirstChild("ACS_Settings")) then return end
	cacheOriginalGun(tool)
	local settings = require(tool.ACS_Settings)
	if spreadEnabled then
		settings.MinSpread               = 0
		settings.MaxSpread               = 0
		settings.AimInaccuracyStepAmount = 0
		settings.AimInaccuracyDecrease   = 0
		settings.WalkMult                = 0
	else
		local o = originalSettings[tool]
		if not o then return end
		settings.MinSpread               = o.MinSpread
		settings.MaxSpread               = o.MaxSpread
		settings.AimInaccuracyStepAmount = o.AimInaccuracyStepAmount
		settings.AimInaccuracyDecrease   = o.AimInaccuracyDecrease
		settings.WalkMult                = o.WalkMult
	end
end

local function applyAmmo(tool)
	if not (tool:IsA("Tool") and tool:FindFirstChild("ACS_Settings")) then return end
	cacheOriginalGun(tool)
	local settings = require(tool.ACS_Settings)
	if ammoEnabled then
		settings.Ammo          = 99999
		settings.AmmoInGun     = 99999
		settings.StoredAmmo    = 99999
		settings.MaxStoredAmmo = 99999
		settings.CanCheckMag   = false
		settings.SlideLock     = false
	else
		local o = originalSettings[tool]
		if not o then return end
		settings.Ammo          = o.Ammo
		settings.AmmoInGun     = o.AmmoInGun
		settings.StoredAmmo    = o.StoredAmmo
		settings.MaxStoredAmmo = o.MaxStoredAmmo
		settings.CanCheckMag   = o.CanCheckMag
		settings.SlideLock     = o.SlideLock
	end
end

local function applyFullAuto(tool)
	if not (tool:IsA("Tool") and tool:FindFirstChild("ACS_Settings")) then return end
	cacheOriginalGun(tool)
	local settings = require(tool.ACS_Settings)
	settings.ShootType = fullAutoEnabled and 3 or (originalSettings[tool] and originalSettings[tool].ShootType or settings.ShootType)
end

local function applyAttachments(tool)
	if not (tool:IsA("Tool") and tool:FindFirstChild("ACS_Settings")) then return end
	cacheOriginalGun(tool)
	local settings = require(tool.ACS_Settings)
	if attachEnabled then
		settings.SightAtt       = attachValues.SightAtt
		settings.BarrelAtt      = attachValues.BarrelAtt
		settings.UnderBarrelAtt = attachValues.UnderBarrelAtt
		settings.OtherAtt       = attachValues.OtherAtt
	else
		local o = originalSettings[tool]
		if not o then return end
		settings.SightAtt       = o.SightAtt
		settings.BarrelAtt      = o.BarrelAtt
		settings.UnderBarrelAtt = o.UnderBarrelAtt
		settings.OtherAtt       = o.OtherAtt
	end
end

local function applyAll(tool)
	applyRecoil(tool)
	applySpread(tool)
	applyAmmo(tool)
	applyFullAuto(tool)
	applyAttachments(tool)
end

local function applyAllToChar(character)
	for _, tool in pairs(character:GetChildren()) do applyAll(tool) end
	local bp = localPlayer:FindFirstChild("Backpack")
	if bp then
		for _, tool in pairs(bp:GetChildren()) do applyAll(tool) end
	end
end

char.ChildAdded:Connect(applyAll)
localPlayer.ChildAdded:Connect(function(child)
	if child.Name == "Backpack" then
		child.ChildAdded:Connect(applyAll)
		for _, tool in pairs(child:GetChildren()) do applyAll(tool) end
	end
end)
localPlayer.CharacterAdded:Connect(function(newChar)
	char = newChar
	applyAllToChar(newChar)
	newChar.ChildAdded:Connect(applyAll)
end)
applyAllToChar(char)

GunModSection:AddToggle('NoRecoil', {
	Text = 'No Recoil',
	Default = false,
	Callback = function(value) recoilEnabled = value; applyAllToChar(char) end
})
GunModSection:AddToggle('NoSpread', {
	Text = 'No Spread',
	Default = false,
	Callback = function(value) spreadEnabled = value; applyAllToChar(char) end
})
GunModSection:AddToggle('InfiniteAmmo', {
	Text = 'Infinite Ammo',
	Default = false,
	Callback = function(value) ammoEnabled = value; applyAllToChar(char) end
})
GunModSection:AddToggle('FullAuto', {
	Text = 'Full Auto',
	Default = false,
	Callback = function(value) fullAutoEnabled = value; applyAllToChar(char) end
})

-----([-----])-----
-- Attachments UI
AttachmentSection:AddToggle('AttachmentsEnabled', {
	Text = 'Apply Attachments',
	Default = false,
	Callback = function(value) attachEnabled = value; applyAllToChar(char) end
})
AttachmentSection:AddDropdown('SightAtt', {
	Text = 'Sight',
	Values = { 'Acog', 'Aimpoint', 'EOTech', 'PM II', 'Reflex', 'TA33 Acog' },
	Default = 'Reflex',
	Multi = false,
	Callback = function(value)
		attachValues.SightAtt = value
		if attachEnabled then applyAllToChar(char) end
	end
})
AttachmentSection:AddDropdown('BarrelAtt', {
	Text = 'Barrel',
	Values = { 'Compensator', 'Flash Hider', 'Muzzle Brake', 'Suppressor' },
	Default = 'Suppressor',
	Multi = false,
	Callback = function(value)
		attachValues.BarrelAtt = value
		if attachEnabled then applyAllToChar(char) end
	end
})
AttachmentSection:AddDropdown('UnderBarrelAtt', {
	Text = 'Under Barrel',
	Values = { 'Angled Grip', 'Bipod', 'Vertical Grip' },
	Default = 'Bipod',
	Multi = false,
	Callback = function(value)
		attachValues.UnderBarrelAtt = value
		if attachEnabled then applyAllToChar(char) end
	end
})
AttachmentSection:AddDropdown('OtherAtt', {
	Text = 'Other',
	Values = { 'AN PEQ', 'Flashlight', 'Laser' },
	Default = 'Laser',
	Multi = false,
	Callback = function(value)
		attachValues.OtherAtt = value
		if attachEnabled then applyAllToChar(char) end
	end
})
AttachmentInfoSection:AddLabel('Sight:\nAcog = 4x zoom\nAimpoint = Red dot\nEOTech = Holographic\nPM II = High zoom\nReflex = Reflex sight\nTA33 Acog = 3x zoom\nBase = Iron sights (default)\n\nBarrel:\nCompensator = Less vertical recoil\nFlash Hider = Hides muzzle flash\nMuzzle Brake = Less recoil\nSuppressor = Silent, less damage\nBase = No attachment\n\nUnder Barrel:\nAngled Grip = Less horizontal recoil\nBipod = No recoil when deployed\nVertical Grip = Less vertical recoil\nBase = No attachment\n\nOther:\nAN PEQ = Laser + flashlight\nFlashlight = White light only\nLaser = Laser only\nBase = No attachment', true)

-----([-----])-----
-- Auto Reload
local StatusUI = PlayerGui:WaitForChild("StatusUI")
local GunHUD   = StatusUI:WaitForChild("GunHUD")
local SAText   = GunHUD:WaitForChild("SAText")
local acsConfig = require(ReplicatedStorage.ACS_Engine.GameRules.Config)

local function getEquippedGun()
	for _, tool in pairs(char:GetChildren()) do
		if tool:IsA("Tool") then return tool end
	end
	return nil
end

local function reequipGun()
	local gun = getEquippedGun()
	if gun then
		gun.Parent = Backpack
		task.wait(0.05)
		gun.Parent = char
	end
end

local function onTextChanged()
	if not autoReloadEnabled then return end
	local text = SAText.Text
	local current, max = text:match("^(%d+)/(%d+)$")
	if current and max then
		current = tonumber(current)
		max     = tonumber(max)
		if current == 0 or current == 1 then
			acsConfig.AmmoInGun = max
			reequipGun()
		end
	end
end

GunModSection:AddToggle('AutoReloadToggle', {
	Text = 'Fast Reload',
	Tooltip = 'fast reloads at 0 ammo',
	Default = false,
	Callback = function(Value) autoReloadEnabled = Value end
})
onTextChanged()
SAText:GetPropertyChangedSignal("Text"):Connect(onTextChanged)

-----([-----])-----
-- Silent Aim
-- some variables are duplicated here from the top of the script because i had issues testing the silent aim but it fully works now.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer
local silentAimEnabled = false
local wallPenEnabled = false
local fovEnabled = false
local fovRadius = 100
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 1
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Filled = false
fovCircle.NumSides = 64
game:GetService("RunService").RenderStepped:Connect(function()
    if fovEnabled and silentAimEnabled then
        local mousePos = UserInputService.GetMouseLocation(UserInputService)
        fovCircle.Position = mousePos
        fovCircle.Radius = fovRadius
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
end)
local function isValidEnemy(npc)
    local humanoid = npc.FindFirstChildOfClass(npc, "Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    if npc.FindFirstChildOfClass(npc, "Tool") then
        return true
    end
    return false
end
local function getClosestEnemyToCursor()
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    local mousePos = UserInputService.GetMouseLocation(UserInputService)
    local closestPart = nil
    local shortestDistance = math.huge
    for _, tag in ipairs({"NPC", "Ped"}) do
        local tagged = CollectionService.GetTagged(CollectionService, tag)
        for _, npc in ipairs(tagged) do
            if isValidEnemy(npc) then
                local targetPart = npc.FindFirstChild(npc, "Head") or npc.FindFirstChild(npc, "HumanoidRootPart")
                if targetPart then
                    local screenPos, onScreen = camera.WorldToViewportPoint(camera, targetPart.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if fovEnabled and distance > fovRadius then
                            continue
                        end
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestPart = targetPart
                        end
                    end
                end
            end
        end
    end
    return closestPart
end
SilentAimSection:AddToggle('SilentAimToggle', {
    Text = 'Enable Silent Aim',
    Default = false,
    Callback = function(Value)
        silentAimEnabled = Value
    end
})
SilentAimSection:AddToggle('WallPenToggle', {
    Text = 'Wallbang',
    Tooltip = 'Only works if Silent Aim is on',
    Default = false,
    Callback = function(Value)
        wallPenEnabled = Value
    end
})
SilentAimSection:AddToggle('FovToggle', {
    Text = 'Enable Fov',
    Default = false,
    Callback = function(Value)
        fovEnabled = Value
    end
})
SilentAimSection:AddSlider('FovSlider', {
    Text = 'FOV Size',
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        fovRadius = Value
    end
})
local oldNamecall
local isHookProcessing = false
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if isHookProcessing then
        return oldNamecall(self, ...)
    end
    local method = getnamecallmethod()
    if method == "Raycast" and silentAimEnabled then
        isHookProcessing = true
        local success, targetPart = pcall(getClosestEnemyToCursor)
        if success and targetPart then
            local args = {...}
            local origin = args[1]
            if typeof(origin) == "Vector3" and typeof(args[2]) == "Vector3" then
                args[2] = (targetPart.Position - origin).Unit * args[2].Magnitude
                if wallPenEnabled then
                    local params = args[3]
                    if params then
                        local existingFilter = params.FilterDescendantsInstances
                        local wallsToIgnore = {}
                        local checkOrigin = origin
                        local checkDir = targetPart.Position - origin
                        local tempParams = RaycastParams.new()
                        tempParams.FilterType = Enum.RaycastFilterType.Exclude
                        tempParams.FilterDescendantsInstances = existingFilter
                        for _ = 1, 10 do
                            local result = workspace.Raycast(workspace, checkOrigin, checkDir, tempParams)
                            if not result then break end
                            local inst = result.Instance
                            if inst and not inst.IsDescendantOf(inst, targetPart.Parent) then
                                table.insert(wallsToIgnore, inst)
                                local newFilter = {}
                                for _, v in ipairs(tempParams.FilterDescendantsInstances) do
                                    table.insert(newFilter, v)
                                end
                                table.insert(newFilter, inst)
                                tempParams.FilterDescendantsInstances = newFilter
                                checkOrigin = result.Position
                                checkDir = targetPart.Position - checkOrigin
                            else
                                break
                            end
                        end
                        if #wallsToIgnore > 0 then
                            local newFilter = {}
                            for _, v in ipairs(existingFilter) do
                                table.insert(newFilter, v)
                            end
                            for _, v in ipairs(wallsToIgnore) do
                                table.insert(newFilter, v)
                            end
                            local newParams = RaycastParams.new()
                            newParams.FilterType = params.FilterType
                            newParams.FilterDescendantsInstances = newFilter
                            newParams.IgnoreWater = params.IgnoreWater
                            args[3] = newParams
                        end
                    end
                end
                isHookProcessing = false
                return oldNamecall(self, unpack(args))
            end
        end
        isHookProcessing = false
    end
    return oldNamecall(self, ...)
end)
-----([-----])-----
-- Speed
local function getHumanoid()
	local character = localPlayer.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
	local humanoid = getHumanoid()
	if humanoid then
		originalSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = speedValue
	end
end

local function restoreSpeed()
	local humanoid = getHumanoid()
	if humanoid and originalSpeed then
		humanoid.WalkSpeed = originalSpeed
		originalSpeed = nil
	end
end

localPlayer.CharacterAdded:Connect(function(character)
	if speedEnabled then
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			originalSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = speedValue
		end
	end
end)

MovementSection:AddLabel('Walkspeed')
MovementSection:AddToggle('SpeedToggle', {
	Text = 'Speed Changer',
	Default = false,
	Callback = function(Value)
		speedEnabled = Value
		if speedEnabled then applySpeed() else restoreSpeed() end
	end
})
MovementSection:AddSlider('SpeedSlider', {
	Text = 'Speed',
	Default = 40,
	Min = 20,
	Max = 70,
	Rounding = 0,
	Compact = false,
	Callback = function(Value)
		speedValue = Value
		if speedEnabled then
			local humanoid = getHumanoid()
			if humanoid then humanoid.WalkSpeed = speedValue end
		end
	end
})

-----([-----])-----
-- Jump
local disableControlsScript = char:WaitForChild("DisableControls")
local v1 = char:WaitForChild("Humanoid")

MovementSection:AddLabel('Jump')
MovementSection:AddToggle('JumpToggle', {
	Text = 'Enable Jump',
	Default = false,
	Callback = function(Value)
		if Value then
			disableControlsScript.Disabled = true
			v1.JumpPower  = 50
			v1.JumpHeight = 7.2
		else
			disableControlsScript.Disabled = false
			v1.JumpPower  = 0
			v1.JumpHeight = 0
		end
	end
})

-----([-----])-----
-- UI Settings
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddToggle("KeybindMenuOpen", { Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(value) Library.KeybindFrame.Visible = value end })
MenuGroup:AddToggle("ShowCustomCursor", { Text = "Custom Cursor", Default = true, Callback = function(Value) Library.ShowCustomCursor = Value end })
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function() Library:Unload() end)

Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/specific-game')
SaveManager:SetSubFolder('specific-place')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()
