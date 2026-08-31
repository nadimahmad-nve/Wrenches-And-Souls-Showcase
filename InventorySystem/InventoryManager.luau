-- SERVICES -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

-- REQUIRE DATAMANAGER --
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

-- REMOTE AND BINDABLE EVENTS --
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local BindableEvents = ReplicatedStorage:WaitForChild("ServerBindableEvents") 

local buyItemEvent = RemoteEvents:WaitForChild("BuyItemEvent")
local updateInventoryEvent = RemoteEvents:WaitForChild("UpdateInventoryEvent")
local openCrateEvent = RemoteEvents:WaitForChild("OpenCrateEvent")
local equipItemEvent = RemoteEvents:WaitForChild("EquipItemEvent")

local addToInventoryEvent = BindableEvents:WaitForChild("AddToInventoryEvent")

local requestInventoryEvent = RemoteEvents:WaitForChild("RequestInventoryEvent")

-- REMOTE FUNCTION -- 

local equipItemResultEvent = ReplicatedStorage:WaitForChild("RemoteFunctions"):WaitForChild("EquipItemResult")

-- BINDABLE FUNCTION -- 
local checkPlayerOwnership = ServerStorage:WaitForChild("BindableFunctions"):WaitForChild("CheckPlayerOwnership")

-- VARIABLES -- 

local attributeCategories = {
	Wrenches = "SelectedWrench", 
	Weapons = "SelectedWeapon", 
	Auras = "SelectedAura", 
	Glows = "SelectedGlow",
	Titles = "EquippedTitle"
}

requestInventoryEvent.OnServerEvent:Connect(function(player)
	-- The client is fully loaded and ready. Safely grab the profile.
	local profile = DataManager:WaitForProfile(player)

	if profile then
		-- Send the inventory back
		updateInventoryEvent:FireClient(player, profile.Data.Inventory)
	end
end)


buyItemEvent.OnServerEvent:Connect(function(player, category, itemName, itemPrice)
	local profile = DataManager:GetProfile(player)
	if not profile then return end 
	
	if category == "SoulArtefacts" then 
		if table.find(profile.Data.Inventory["SoulArtefacts"], itemName) then 
			warn(player.Name .. " already owns this Soul Artefact.")
			return 
		end
	end

	local currentCurrency = player:GetAttribute("Currency") or 0 

	if currentCurrency >= itemPrice then 
		-- Deduct the cost
		player:SetAttribute("Currency", currentCurrency - itemPrice)

		if profile.Data.Inventory[category] then 
			-- Add the item directly into their saved profile data
			table.insert(profile.Data.Inventory[category], itemName)

			print(player.Name .. " successfully bought " .. itemName .. " (" .. category .. ")!")

			-- Update the client's UI
			updateInventoryEvent:FireClient(player, profile.Data.Inventory)
		else 
			warn("Category " .. category .. " not found in player inventory.")
		end

	else 
		warn(player.Name .. " tried to buy " .. itemName .. " but doesn't have enough Currency.")
	end
end)

equipItemResultEvent.OnServerInvoke = function(player, category, itemName, extraData)
	local profile = DataManager:GetProfile(player)
	if not profile or not profile.Data.Inventory[category] then return end 

	-- Anti-Exploit: Verify they actually own the item in their saved data before equipping
	if not table.find(profile.Data.Inventory[category], itemName) then
		warn(player.Name .. " tried to equip " .. itemName .. " but does not own it! (Exploit attempt?)")
		return false 
	end

	local selectedCategory = attributeCategories[category]

	if category ~= "SoulArtefacts" then 
		player:SetAttribute(selectedCategory, itemName)
		print(player.Name .. " equipped " .. itemName .. " (" .. category .. ")!")
	else 
		-- CHECK FOR SOUL ARTEFACT -- 
		if extraData == "Mechanic" then 
			player:SetAttribute("MechanicClass", itemName)
		else 
			player:SetAttribute("ExterminatorClass", itemName)
		end
	end
	
	return true 
end


local function checkIfOwned(profile, category, itemName)
	if table.find(profile.Data.Inventory[category], itemName) then 
		return true 
	end
	return false 
end


checkPlayerOwnership.OnInvoke = function(player, category, itemName)
	local profile = DataManager:WaitForProfile(player)
	if not profile then return false end 
	
	return checkIfOwned(profile, category, itemName)
end

addToInventoryEvent.Event:Connect(function(player, category, itemName)
	local profile = DataManager:WaitForProfile(player)
	if not profile then return end 
	
	local owned = checkIfOwned(profile, category, itemName)
	
	if category == "Titles" and owned  then
		warn(player.Name .. " already owns this title.")
		return 
	end

	if profile.Data.Inventory[category] then 
		table.insert(profile.Data.Inventory[category], itemName)
		updateInventoryEvent:FireClient(player, profile.Data.Inventory)
	else 
		warn("Category " .. category .. " not found in player inventory.")
	end 
end)