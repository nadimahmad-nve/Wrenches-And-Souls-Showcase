-- SERVICES -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- MODULES -- 
local CrateInfo = ReplicatedStorage:WaitForChild("CrateInfo")

-- REMOTE AND BINDABLE EVENTS -- 
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents") 
local BindableEvents = ReplicatedStorage:WaitForChild("ServerBindableEvents") 

local OpenCrateEvent = RemoteEvents:WaitForChild("OpenCrateEvent")
local addToInventoryEvent = BindableEvents:WaitForChild("AddToInventoryEvent")

-- BINDABLE FUNCTION -- 
local checkPlayerOwnership = ServerStorage:WaitForChild("BindableFunctions"):WaitForChild("CheckPlayerOwnership")

local CrateDatabase = {
	Wrenches = require(CrateInfo:WaitForChild("WrenchCrateData")),
	Weapons = require(CrateInfo:WaitForChild("WeaponCrateData")),
	Auras = require(CrateInfo:WaitForChild("AuraCrateData")),
	Glows = require(CrateInfo:WaitForChild("GlowCrateData"))
}

-- FUNCTIONS -- 
local function rollCrate(crateName, category)
	local crateData = CrateDatabase[category][crateName]
	if not crateData then return nil end

	-- Calculate the total weight
	local totalWeight = 0
	for _, item in ipairs(crateData.Items) do
		totalWeight += item.Weight
	end

	-- Pick a random number between 1 and the total weight
	local winningNumber = math.random(1, totalWeight)

	-- Find the winning item
	local currentWeight = 0
	for _, item in ipairs(crateData.Items) do
		currentWeight += item.Weight

		-- If our current accumulated weight passes the winning number, this is the winner
		if winningNumber <= currentWeight then
			return item
		end
	end
end


OpenCrateEvent.OnServerEvent:Connect(function(player, crateName, category)
	local crateData = CrateDatabase[category][crateName]
	if not crateData then return end
	
	local category = crateData.Category 
	local playerCurrency = player:GetAttribute("Currency") or 0

	if playerCurrency >= crateData.Price then
		player:SetAttribute("Currency", playerCurrency - crateData.Price)

		local winningItem = rollCrate(crateName, category)
		print(player.Name .. " unboxed a " .. winningItem.Name .. "!")
		
		-- Does player own this? (For UI purposes) 
		local owned = checkPlayerOwnership:Invoke(player, category, winningItem.Name) 
		
		-- Save to inventory 
		addToInventoryEvent:Fire(player, category, winningItem.Name)

		OpenCrateEvent:FireClient(player, winningItem, category, owned)
	else
		warn(player.Name .. " tried to open a crate without enough currency!")
	end
end)