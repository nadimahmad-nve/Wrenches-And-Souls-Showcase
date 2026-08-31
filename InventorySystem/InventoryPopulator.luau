-- SERVICES -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REMOTE EVENTS -- 
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local requestInventoryEvent = RemoteEvents:WaitForChild("RequestInventoryEvent")
local updateInventoryEvent = RemoteEvents:WaitForChild("UpdateInventoryEvent")
local equipItemEvent = RemoteEvents:WaitForChild("EquipItemEvent")
local ShopAssets = ReplicatedStorage:WaitForChild("ShopAssets")
local RarityColours = require(ShopAssets:WaitForChild("RarityColours"))
local updateTitleEvent = ReplicatedStorage:WaitForChild("ClientBindableEvents"):WaitForChild("ClientUpdateTitles")

-- REMOTE FUNCTION -- 
local equipItemResult = ReplicatedStorage:WaitForChild("RemoteFunctions"):WaitForChild("EquipItemResult")

-- UI DESTINATIONS -- 
local inventoryFrame = script.Parent
local player = game.Players.LocalPlayer
local playerGUI = player:WaitForChild("PlayerGui")

local soulArtefactInfoGUI = playerGUI:WaitForChild("SoulArtefactInfoGUI")
local soulArtefactFrame = soulArtefactInfoGUI:WaitForChild("InfoFrame")

-- VARIABLES -- 
local ShopAssets = ReplicatedStorage:WaitForChild("ShopAssets")

local currentlySelectedItem = nil 
local currentlySelectedItems = {}

-- CONSTANTS -- 
mechanicTextColour = Color3.fromRGB(0, 119, 125)
exterminatorTextColour = Color3.fromRGB(125, 0, 2)

-- UI CONFIG -- 
local categoryConfigs = {
	Wrenches = {
		Page = inventoryFrame:WaitForChild("WrenchPage"), 
		Database = require(ShopAssets:WaitForChild("WrenchAssets"):WaitForChild("WrenchDatabase")),
		Template = ShopAssets:WaitForChild("WrenchAssets"):WaitForChild("WrenchItemTemplate"),
		Attribute = "SelectedWrench"
	},
	Weapons = {
		Page = inventoryFrame:WaitForChild("WeaponPage"), 
		Database = require(ShopAssets:WaitForChild("WeaponAssets"):WaitForChild("WeaponDatabase")),
		Template = ShopAssets:WaitForChild("WeaponAssets"):WaitForChild("WeaponItemTemplate"),
		Attribute = "SelectedWeapon"
	}, 
	SoulArtefacts = {
		Page = inventoryFrame:WaitForChild("SoulArtefactPage"),
		Database = require(ShopAssets:WaitForChild("SoulArtefactAssets"):WaitForChild("SoulArtefactDatabase")),
		Template = ShopAssets:WaitForChild("SoulArtefactAssets"):WaitForChild("SoulArtefactItemTemplate")
	}, 
	Auras = {
		Page = inventoryFrame:WaitForChild("AuraPage"), 
		Database = require(ShopAssets:WaitForChild("AuraAssets"):WaitForChild("AuraDatabase")),
		Template = ShopAssets:WaitForChild("AuraAssets"):WaitForChild("AuraItemTemplate"),
		Attribute = "SelectedAura"
	}, 
	Glows = { 
		Page = inventoryFrame:WaitForChild("GlowPage"), 
		Database = require(ShopAssets:WaitForChild("GlowAssets"):WaitForChild("GlowDatabase")),
		Template = ShopAssets:WaitForChild("GlowAssets"):WaitForChild("GlowItemTemplate"),
		Attribute = "SelectedGlow"
	},
	Titles = { 
		TitleSelectPage = inventoryFrame.Parent.Parent:WaitForChild("SettingsGUI"):WaitForChild("SettingsFrame"):WaitForChild("TitleSelectPage"),
		Database = require(ReplicatedStorage:WaitForChild("Titles"):WaitForChild("TitleDatabase")),
		Template = ReplicatedStorage:WaitForChild("Titles"):WaitForChild("TitleTemplate"), 
	}
}

local function refreshDetailPage(category)
	local detailPage = categoryConfigs[category].Page.DetailPage
	
	if category == "SoulArtefacts" then 
		local mechanicClass = player:GetAttribute("MechanicClass")
		local exterminatorClass = player:GetAttribute("ExterminatorClass")
		
		if ("The " .. mechanicClass) == detailPage.ItemName.Text or ("The " .. exterminatorClass) == detailPage.ItemName.Text then
			detailPage.EquippedLabel.Visible = true 
			detailPage.EquipButton.Visible = false 
		else 
			detailPage.EquippedLabel.Visible = false 
			detailPage.EquipButton.Visible = true 
		end 
		
		return 
	end
	
	local configAttribute = categoryConfigs[category].Attribute
	local currentEquipped = player:GetAttribute(configAttribute)
	
	if detailPage.ItemName.Text == currentEquipped then 
		detailPage.EquippedLabel.Visible = true 
		detailPage.EquipButton.Visible = false 
	else 
		detailPage.EquippedLabel.Visible = false 
		detailPage.EquipButton.Visible = true 
	end
end

for categoryName, config in pairs(categoryConfigs) do
	if categoryName == "Titles" then continue end

	local detailPage = config.Page:WaitForChild("DetailPage")
	local equipButton = detailPage:WaitForChild("EquipButton")

	equipButton.Activated:Connect(function()
		-- Fetch the selected item specific to THIS category's page
		local selectedItem = currentlySelectedItems[categoryName]
		if selectedItem == nil then return end 

		local currentCategory = selectedItem.Category 

		if categoryConfigs[currentCategory].Page.Visible == false then return end 
		print("Requesting to equip: " .. selectedItem.Name)		

		if currentCategory == "SoulArtefacts" then 
			--equipItemEvent:FireServer(selectedItem.Category, selectedItem.Name, selectedItem.MorEx)
			
			local equippedResult = equipItemResult:InvokeServer(selectedItem.Category, selectedItem.Name, selectedItem.MorEx)
			refreshDetailPage(currentCategory)
			return 
		end

		--equipItemEvent:FireServer(selectedItem.Category, selectedItem.Name)
		
		local equippedResult = equipItemResult:InvokeServer(selectedItem.Category, selectedItem.Name)
		refreshDetailPage(currentCategory)
	end)
end

-- HELPER FUNCTION -- 
local function setupTitles(ownedTitles)
	local titleSelectPage = categoryConfigs["Titles"].TitleSelectPage
	local template = categoryConfigs["Titles"].Template
	local database = categoryConfigs["Titles"].Database
	local itemContainer = titleSelectPage:WaitForChild("ItemContainer")
	
	local player = game.Players.LocalPlayer
	
	for _, oldItem in pairs(itemContainer:GetChildren()) do 
		if oldItem:IsA("Frame") then 
			oldItem:Destroy()
		end 
	end
	
	for _, titleName in pairs(ownedTitles) do
		local titleData = database[titleName]
		if not titleData then continue end 
		
		local newItem = template:Clone()
		newItem.Name = titleName 
		newItem.TitleName.Text = titleName 
		newItem.TitleName.TextColor3 = titleData.Colour or Color3.fromRGB(255, 255, 255)
		
		newItem.LayoutOrder = titleData.Order or 0  
		
		local toggleButton = newItem:WaitForChild("Toggle") 
		
		toggleButton.Activated:Connect(function()
			local currentTitle = player:GetAttribute("EquippedTitle") 
			if currentTitle == titleName then return end 
			
			local equippedResult = equipItemResult:InvokeServer("Titles", titleName)
			--equipItemEvent:FireServer("Titles", titleName)
		end)
		
		newItem.Visible = true 
		newItem.Parent = itemContainer 
	end
	
	updateTitleEvent:Fire()
end

-- INVENTORY RENDERER -- 

updateInventoryEvent.OnClientEvent:Connect(function(newInventoryData)
	print("Received master inventory update from server.")
	
	for categoryName, ownedItemsArray in pairs(newInventoryData) do
		if categoryName == "Titles" then 
			setupTitles(ownedItemsArray)
			continue
		end
		
		local config = categoryConfigs[categoryName]
		if not config then continue end 
		
		local itemContainer = config.Page:WaitForChild("ItemContainer")
		local detailPage = config.Page:WaitForChild("DetailPage")
		local equipButton = detailPage:WaitForChild("EquipButton")
		local database = config.Database 
		local template = config.Template 
		local configAttribute = config.Attribute 
		
		for _, oldItem in pairs(itemContainer:GetChildren()) do 
			if oldItem.Name == "ItemTemplate" then continue end 
			if oldItem:IsA("GuiObject") then 
				oldItem:Destroy()
			end
		end
		
		local itemCounts = {}
		for _, itemName in ipairs(ownedItemsArray) do
			itemCounts[itemName] = (itemCounts[itemName] or 0) + 1 
		end
		
		local alreadySeenItems = {}
		
		for _, itemName in ipairs(ownedItemsArray) do 
			if alreadySeenItems[itemName] then continue end 
			alreadySeenItems[itemName] = true 
			
			local itemData = database[itemName]
			if not itemData then continue end 
			
			local newCard = template:Clone()
			newCard.Name = itemName 
			newCard.ItemName.Text = itemName 
			newCard.ImageLabel.Image = itemData.ImageID or ""
			
			-- STACKING LOGIC -- 
			local quantityLabel = newCard:FindFirstChild("QuantityLabel")
			local count = itemCounts[itemName]
			
			if quantityLabel then 
				if count > 1 then 
					quantityLabel.Text = "x" .. tostring(count)
					quantityLabel.Visible = true 
				else 
					quantityLabel.Visible = false 
				end
			end
			
			if itemData.Order then 
				newCard.LayoutOrder = itemData.Order 
			end
			
			if itemData.MorEx then 
				newCard.ItemName.Text =  "The " .. itemName 

				local infoButton = newCard:FindFirstChild("InfoButton")
				if not infoButton then continue end

				infoButton.Activated:Connect(function()
					inventoryFrame.Visible = false
					soulArtefactFrame.Visible = true
					
					for _, child in pairs(soulArtefactFrame:GetChildren()) do
						if child:IsA("Frame") then
							child.Visible = false
						end
					end
					
					local selectedPage = soulArtefactFrame:FindFirstChild(itemName.."Page")
					if not selectedPage then return end 

					selectedPage.Visible = true 
					selectedPage:SetAttribute("From", "Inventory")
				end)
			end
			
			newCard.Activated:Connect(function()
				currentlySelectedItems[categoryName] = {
					Category = categoryName, 
					Name = itemName, 
					Rarity = itemData.Rarity,
					ImageID = itemData.ImageID,
					MorEx = itemData.MorEx 
				}
				
				detailPage.EquipButton.Visible = true 
				detailPage.ImageLabel.Visible = true 
				
				detailPage.ItemName.Text = itemName 
				detailPage.ImageLabel.Image = itemData.ImageID or ""
				
				local rarityLabel = detailPage:FindFirstChild("Rarity")
				
				if rarityLabel and itemData.Rarity then
					rarityLabel.RichText = true 

					local colour = RarityColours[itemData.Rarity]
					local hex = colour:ToHex()

					rarityLabel.Text = 'Rarity: <font color="#' .. hex .. '">' .. itemData.Rarity .. '</font>'

					rarityLabel.Visible = true
				elseif rarityLabel then 
					rarityLabel.Visible = false 
				end
				
				if itemData.MorEx then 
					local classTypeText = detailPage.ClassType 
					classTypeText.Visible = true 
					
					classTypeText.Text = itemData.MorEx
					classTypeText.Position = UDim2.new(0.049, 0,0.54, 0)
					
					if itemData.MorEx == "Exterminator" then 
						classTypeText.UIStroke.Color = exterminatorTextColour
						
						local newPadding = UDim.new(0.1, 0)
						classTypeText.UIPadding.PaddingBottom = newPadding
						classTypeText.UIPadding.PaddingTop = newPadding
						classTypeText.UIPadding.PaddingLeft = newPadding
						classTypeText.UIPadding.PaddingRight = newPadding
					else 
						detailPage.ClassType.UIStroke.Color = mechanicTextColour
						local newPadding = UDim.new(0.2, 0)
						classTypeText.UIPadding.PaddingBottom = newPadding
						classTypeText.UIPadding.PaddingTop = newPadding
						classTypeText.UIPadding.PaddingLeft = newPadding
						classTypeText.UIPadding.PaddingRight = newPadding
					end

					detailPage.ItemName.Text = "The " .. itemName
				end
				
				-- EQUIPPED? --
				if not itemData.MorEx then 
					local currentEquipped = player:GetAttribute(configAttribute)
					if currentEquipped == itemName then 
						detailPage.EquippedLabel.Visible = true 
						detailPage.EquipButton.Visible = false 
					else 
						detailPage.EquippedLabel.Visible = false 
						detailPage.EquipButton.Visible = true 
					end
				else 
					local exterminatorClass = player:GetAttribute("ExterminatorClass")
					local mechanicClass = player:GetAttribute("MechanicClass")
					
					if itemName == exterminatorClass or itemName == mechanicClass then 
						detailPage.EquippedLabel.Visible = true 
						detailPage.EquipButton.Visible = false 
					else 
						detailPage.EquippedLabel.Visible = false 
						detailPage.EquipButton.Visible = true 
					end 
				end
				
				detailPage.Visible = true 
			end)
			
			newCard.Parent = itemContainer 
			newCard.Visible = true 
		end
	end
end)

local function initialiseDetailPages()
	for category, config in pairs(categoryConfigs) do 
		if category == "Titles" then continue end
		local detailPage = config.Page:WaitForChild("DetailPage")

		detailPage.ItemName.Text = "No item selected"
		detailPage.EquipButton.Visible = false 
		detailPage.EquippedLabel.Visible = false 
		detailPage.ImageLabel.Visible = false 

		local rarity = detailPage:FindFirstChild("Rarity")
		if rarity then 
			rarity.Visible = false 
		end

		local amount = detailPage:FindFirstChild("Amount")
		if amount then 
			amount.Visible = false 
		end 

		local ratesLabel = detailPage:FindFirstChild("RatesLabel")
		if ratesLabel then 
			ratesLabel.Visible = false 
		end

		local classType = detailPage:FindFirstChild("ClassType")
		if classType then 
			classType.Visible = false  
		end
	end
end


-- MAIN -- 
initialiseDetailPages()
requestInventoryEvent:FireServer()