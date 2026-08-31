local RoleManager = {}

-- SERVICES -- 
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameModules = script.Parent 
local EliminationManager = require(GameModules.EliminationManager)
local StateManager = require(ServerStorage.StateManager)

-- VARIABLES -- 
local scriptConnections = {} 
local GlowsFolder = ReplicatedStorage:WaitForChild("ExterminatorGlows")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents") 
local showStartingUIEvent = RemoteEvents:WaitForChild("ShowStartingUIEvent")
local NotificationEvent = RemoteEvents:WaitForChild("NotificationEvent")
local RemoveRoleEvent = ReplicatedStorage:WaitForChild("ServerBindableEvents"):WaitForChild("RemoveRoleEvent")

-- HELPER FUNCTIONS -- 
local function applyExterminatorGlow(player, character)
	local selectedGlowName = player:GetAttribute("SelectedGlow") or "RedGlow"
	local lightTemplate = GlowsFolder:FindFirstChild(selectedGlowName)

	if lightTemplate and lightTemplate:IsA("PointLight") then 
		local rootPart = character:WaitForChild("HumanoidRootPart")
		local activeLight = lightTemplate:Clone() 
		activeLight.Name = "ExterminatorGlow"
		activeLight.Parent = rootPart
	else
		warn("Glow not found")
	end
end

local function removeExterminatorGlow(player, character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then 
		local glow = rootPart:FindFirstChild("ExterminatorGlow")
		if glow then glow:Destroy() end
	end
end

local function attachSoulArtefactModel(player, character)
	local class = player:GetAttribute("Class")
	local soulArtefactModel = ReplicatedStorage:WaitForChild("ClassesConfig"):WaitForChild(class):WaitForChild("SoulArtefactModel"):Clone()
	character.Humanoid:AddAccessory(soulArtefactModel)
end

local function removeSoulArtefactModel(player, character)
	local equippedArtefact = character:FindFirstChild("SoulArtefactModel")
	if equippedArtefact and equippedArtefact:IsA("Accessory") then
		equippedArtefact:Destroy()
	end
end

-- NEW ABSTRACTION: Unified Tool Equipping
local function equipToolToCharacter(character, storageFolder, toolName, cloneName)
	local toolTemplate = storageFolder:WaitForChild(toolName)
	local clone = toolTemplate:Clone()
	clone.Name = cloneName
	clone.Parent = character 

	local rightHand = character:WaitForChild("RightHand")
	local handGrip = rightHand:WaitForChild("RightGripAttachment")
	local handle = clone:WaitForChild("Handle")
	local weaponGrip = handle:WaitForChild("GripAttachment")

	local rigidConstraint = Instance.new("RigidConstraint")
	rigidConstraint.Attachment0 = handGrip 
	rigidConstraint.Attachment1 = weaponGrip 
	rigidConstraint.Parent = clone
end

local function setupExterminator(player) 
	player:SetAttribute("Role", "Exterminator")

	local equippedClass = player:GetAttribute("ExterminatorClass")
	player:SetAttribute("Class", equippedClass)
	player:SetAttribute("PlayersEliminated", 0)

	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		-- FIX: Prevent infinite yield memory leak if player leaves
		if not player:IsDescendantOf(Players) then return end 

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = 18

		local chosenWeapon = player:GetAttribute("SelectedWeapon")
		equipToolToCharacter(character, ServerStorage.Weapons, chosenWeapon, "EquippedWeapon")

		applyExterminatorGlow(player, character)
		attachSoulArtefactModel(player, character)
	end)

	return player 
end

local function setupMechanic(player)
	player:SetAttribute("Role", "Mechanic")
	player:SetAttribute("Health", 100)

	local equippedClass = player:GetAttribute("MechanicClass")
	player:SetAttribute("Class", equippedClass)
	player:SetAttribute("ObjectsFixed", 0)
	player:SetAttribute("TimesRescued", 0)

	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		-- FIX: Prevent infinite yield memory leak if player leaves
		if not player:IsDescendantOf(Players) then return end 

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = 16

		local chosenWrench = player:GetAttribute("SelectedWrench")
		equipToolToCharacter(character, ServerStorage.Wrenches, chosenWrench, "EquippedWrench")

		attachSoulArtefactModel(player, character)
	end)
end

local function getAliveMechanics()
	local playersInGame = Players:GetPlayers()
	local mechanicCount = 0 

	for _, player in playersInGame do  
		if player:GetAttribute("Role") == "Mechanic" and player:GetAttribute("RoundStatus") == "Alive" then 
			mechanicCount += 1
		end 
	end 
	return mechanicCount 
end

-- MODULE FUNCTIONS -- 
function RoleManager.AssignRoles(players)
	if #players == 0 then 
		warn("No players to assign roles to!")
		return nil 
	end

	if #players == 1 then 
		for _, p in players do 
			p:SetAttribute("RoundStatus", "Alive")
			setupMechanic(p)
		end
		warn("Not enough players to start")
		return nil 
	end

	-- Role Assigning Logic
	local totalWeight = 0
	local mechanicCount = 0
	local playerWeights = {}

	for _, player in ipairs(players) do
		local weight = 0
		local timesExterminator = player:GetAttribute("TimesExterminator") or 0
		local wasLast = player:GetAttribute("WasExterminatorLastRound")

		if wasLast then
			weight = 0 
		elseif timesExterminator == 0 then
			weight = 100 
		else
			weight = 15 
		end

		local shopModifier = player:GetAttribute("ExterminatorModifier") or 1
		weight = weight * shopModifier

		totalWeight += weight
		table.insert(playerWeights, {player = player, weight = weight})
	end

	local exterminatorPlayer = nil
	if totalWeight > 0 then
		local winningTicket = math.random() * totalWeight
		local currentCount = 0

		for _, data in ipairs(playerWeights) do
			currentCount += data.weight
			if winningTicket <= currentCount then
				exterminatorPlayer = data.player
				break
			end
		end
	else
		exterminatorPlayer = players[math.random(#players)]
	end

	for _, player in ipairs(players) do
		if not player or not player:IsDescendantOf(Players) then continue end 

		player:SetAttribute("RoundStatus", "Alive")

		if player ~= exterminatorPlayer then
			player:SetAttribute("WasExterminatorLastRound", false)
		end

		local connection = player:GetAttributeChangedSignal("Health"):Connect(function()
			if player:GetAttribute("Health") == nil then return end

			local currentHealth = player:GetAttribute("Health") or 100

			if currentHealth <= 0 and player:GetAttribute("RoundStatus") ~= "Dead" then
				local aliveMechanics = getAliveMechanics()

				if aliveMechanics > 0 then 
					EliminationManager.EliminatePlayer(player, exterminatorPlayer)
				end
			end
		end)

		table.insert(scriptConnections, connection)

		if player == exterminatorPlayer then
			player:SetAttribute("WasExterminatorLastRound", true)
			player:SetAttribute("TimesExterminator", (player:GetAttribute("TimesExterminator") or 0) + 1)
			player:SetAttribute("ExterminatorModifier", 1)

			setupExterminator(player)
		else
			setupMechanic(player)
			mechanicCount += 1
		end
	end

	ReplicatedStorage:SetAttribute("NumberMechanics", mechanicCount)
	return exterminatorPlayer 
end

function RoleManager.RemoveRole(player)
	player:SetAttribute("Role", "None")
	player:SetAttribute("Class", nil)
	player:SetAttribute("ObjectsFixed", nil)
	player:SetAttribute("PlayersEliminated", nil)
	player:SetAttribute("RoundStatus", nil)
	player:SetAttribute("Health", nil)
	player:SetAttribute("TimesRescued", nil)

	local backpack = player:FindFirstChild("Backpack")
	if backpack then backpack:ClearAllChildren() end

	local character = player.Character
	if character then 
		StateManager.ClearCharacter(character)

		local weapon = character:FindFirstChild("EquippedWeapon")
		if weapon then weapon:Destroy() end 

		local wrench = character:FindFirstChild("EquippedWrench")
		if wrench then wrench:Destroy() end

		removeExterminatorGlow(player, character)
		removeSoulArtefactModel(player, character)
	end 
end


function RoleManager.RemoveRoles(players)
	for _, connection in ipairs(scriptConnections) do
		connection:Disconnect()
	end
	table.clear(scriptConnections)

	for _, player in ipairs(players) do
		RoleManager.RemoveRole(player)
	end
end

function RoleManager.ShowStartingUI(players) 
	for _, player in ipairs(players) do
		showStartingUIEvent:FireClient(player) 
	end
end

-- BINDABLE EVENT CONNECTION
RemoveRoleEvent.Event:Connect(function(player)
	RoleManager.RemoveRole(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local role = player:GetAttribute("Role") 
	local status = player:GetAttribute("RoundStatus")  

	if role == "Mechanic" and (status == "Alive" or status == "Downed") then 
		local numMechanics = ReplicatedStorage:GetAttribute("NumberMechanics") or 0
		ReplicatedStorage:SetAttribute("NumberMechanics", numMechanics - 1)

		if status == "Downed" then
			local activeExterminator = nil
			for _, p in ipairs(Players:GetPlayers()) do
				if p:GetAttribute("Role") == "Exterminator" then
					activeExterminator = p
					break
				end
			end

			if activeExterminator then
				local currentElims = activeExterminator:GetAttribute("PlayersEliminated") or 0
				activeExterminator:SetAttribute("PlayersEliminated", currentElims + 1)
				print("Awarded " .. activeExterminator.Name .. " an elimination due to a disconnecting player.")
			end
		end
	end
end)

return RoleManager