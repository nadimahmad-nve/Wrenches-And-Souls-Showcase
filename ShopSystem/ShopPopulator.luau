-- SERVICES & ASSETS -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local buyItemEvent = RemoteEvents:WaitForChild("BuyItemEvent")
local OpenCrateEvent = RemoteEvents:WaitForChild("OpenCrateEvent") 

local ShopAssets = ReplicatedStorage:WaitForChild("ShopAssets")
local RarityColours = require(ShopAssets:WaitForChild("RarityColours"))
local CrateInfo = ReplicatedStorage:WaitForChild("CrateInfo")


-- UI DESTINATIONS -- 
local playerGUI = localPlayer:WaitForChild("PlayerGui")
local shopGUI = playerGUI:WaitForChild("ShopGUI")
local shopFrame = shopGUI:WaitForChild("ShopFrame")

local soulArtefactInfoGUI = playerGUI:WaitForChild("SoulArtefactInfoGUI")
local soulArtefactFrame = soulArtefactInfoGUI:WaitForChild("InfoFrame")

local currentlySelectedItem = nil 
local currentlySelectedItems = {} -- Tracks the selected item for each category independently
local cachedInventory = {}

-- REMOTE EVENTS -- 
local updateInventoryEvent = RemoteEvents:WaitForChild("UpdateInventoryEvent")

-- CONSTANTS -- 
mechanicTextColour = Color3.fromRGB(0, 119, 125)
exterminatorTextColour = Color3.fromRGB(125, 0, 2)

local categoryConfigs = {
	Wrenches = {
		Page = shopFrame:WaitForChild("WrenchPage"), 
		Database = require(ShopAssets:WaitForChild("WrenchAssets"):WaitForChild("WrenchDatabase")),
		Template = ShopAssets:WaitForChild("WrenchAssets"):WaitForChild("WrenchItemTemplate"),
		CratesDatabase = require(CrateInfo:WaitForChild("WrenchCrateData"))
	},
	Weapons = {
		Page = shopFrame:WaitForChild("WeaponPage"), 
		Database = require(ShopAssets:WaitForChild("WeaponAssets"):WaitForChild("WeaponDatabase")),
		Template = ShopAssets:WaitForChild("WeaponAssets"):WaitForChild("WeaponItemTemplate"),
		CratesDatabase = require(CrateInfo:WaitForChild("WeaponCrateData"))
	}, 
	SoulArtefacts = {
		Page = shopFrame:WaitForChild("SoulArtefactPage"),
		Database = require(ShopAssets:WaitForChild("SoulArtefactAssets"):WaitForChild("SoulArtefactDatabase")),
		Template = ShopAssets:WaitForChild("SoulArtefactAssets"):WaitForChild("SoulArtefactItemTemplate")
	}, 
	SoulDust = {
		Page = shopFrame:WaitForChild("SoulDustPage"), 
		Database = require(ShopAssets:WaitForChild("SoulDustAssets"):WaitForChild("SoulDustDatabase")),
		Template = ShopAssets:WaitForChild("SoulDustAssets"):WaitForChild("SoulDustItemTemplate")
	}, 
	Auras = {
		Page = shopFrame:WaitForChild("AuraPage"), 
		Database = require(ShopAssets:WaitForChild("AuraAssets"):WaitForChild("AuraDatabase")),
		Template = ShopAssets:WaitForChild("AuraAssets"):WaitForChild("AuraItemTemplate"),
		CratesDatabase = require(CrateInfo:WaitForChild("AuraCrateData"))
	}, 
	Glows = { 
		Page = shopFrame:WaitForChild("GlowPage"), 
		Database = require(ShopAssets:WaitForChild("GlowAssets"):WaitForChild("GlowDatabase")),
		Template = ShopAssets:WaitForChild("GlowAssets"):WaitForChild("GlowItemTemplate"),
		CratesDatabase = require(CrateInfo:WaitForChild("GlowCrateData"))
	}
}


for categoryName, config in pairs(categoryConfigs) do
	local detailPage = config.Page:WaitForChild("DetailPage")
	local buyButton = detailPage:WaitForChild("BuyButton")

	buyButton.Activated:Connect(function()
		local selectedItem = currentlySelectedItems[categoryName]
		if selectedItem == nil then return end

		local currentCategory = selectedItem.Category
		local currentName = selectedItem.Name 
		print(currentCategory)

		if categoryConfigs[currentCategory].Page.Visible == false then return end 
		
		if not selectedItem.IsCrate and currentCategory == "SoulArtefacts" then 
			print("Sending purchase request to server for: ".. currentName)
			buyItemEvent:FireServer(currentCategory, currentName, selectedItem.Price)
			return
		end 
		
		if selectedItem.IsCrate then
			print("Sending crate open request to server for: ".. currentName)
			OpenCrateEvent:FireServer(currentName, currentCategory)
		else
			print("Prompting Robux purchase for: ".. currentName)

			if selectedItem.ProductID then
				MarketplaceService:PromptProductPurchase(localPlayer, selectedItem.ProductID)
			else
				warn("No ProductID found for this item!")
			end
		end
	end)
end

-- This populates the shop with the available items to buy, but doesn't deal with the crates
local function populateShop() 
	-- Loop through every category in our config
	for categoryName, config in pairs(categoryConfigs) do
		if categoryName == "SoulDust" or categoryName == "SoulArtefacts" then continue end 
		
		local itemContainer = config.Page:WaitForChild("ItemContainer")
		local detailPage = config.Page:WaitForChild("DetailPage")
		local database = config.Database
		local template = config.Template

		-- Loop through every item inside that specific database
		for itemName, itemData in pairs(database) do 
			local newCard = template:Clone()

			newCard.Name = itemName
			newCard.ItemName.Text = itemName 
			newCard.ImageLabel.Image = itemData.ImageID or ""
			
			if itemData.Order then 
				newCard.LayoutOrder = itemData.Order 
			end


			newCard.Activated:Connect(function()
				currentlySelectedItems[categoryName] = {
					Category = categoryName, 
					Name = itemName, 
					Rarity = itemData.Rarity, 
					Price = itemData.Price,
					ProductID = itemData.ProductID,
					ImageID = itemData.ImageID,
					MorEx = itemData.MorEx,
					IsCrate = false
				}
				
				detailPage.ItemName.Visible = true 
				detailPage.ImageLabel.Visible = true  
				detailPage.BuyButton.Visible = true 
				detailPage.Price.Visible = true 
				
				detailPage.ItemName.Text = itemName 
				detailPage.Price.Text = "Price: " .. itemData.Price .. "R$"
				detailPage.Price.Position = UDim2.new(0.046, 0, 0.645, 0)
				detailPage.ImageLabel.Image = itemData.ImageID or ""

				local rarityLabel = detailPage:FindFirstChild("Rarity")
				
				-- Reposition Buy Button 
				local buyButton = detailPage:FindFirstChild("BuyButton")
				buyButton.Position = UDim2.new(0.115, 0, 0.805, 0)
				
				-- Disable RatesLabel 
				local ratesLabel = detailPage:FindFirstChild("RatesLabel")
				if ratesLabel then ratesLabel.Visible = false end
				
				if rarityLabel and itemData.Rarity then
					rarityLabel.RichText = true 

					local colour = RarityColours[itemData.Rarity]
					local hex = colour:ToHex()

					rarityLabel.Text = 'Rarity: <font color="#' .. hex .. '">' .. itemData.Rarity .. '</font>'

					rarityLabel.Visible = true
				elseif rarityLabel then 
					rarityLabel.Visible = false 
				end
				
				detailPage.Visible = true 
			end)

			newCard.Parent = itemContainer
			newCard.Visible = true
		end
	end
end


local function populateSoulArtefacts()
	local soulArtefactData = categoryConfigs["SoulArtefacts"]
	local page = soulArtefactData.Page 
	local database = soulArtefactData.Database
	local template = soulArtefactData.Template
	
	local itemContainer = page:WaitForChild("ItemContainer")
	local detailPage = page:WaitForChild("DetailPage")
	
	local categoryName = "SoulArtefacts"
	
	for itemName, itemData in pairs(database) do 
		local newCard = template:Clone()
		newCard.Name = itemName
		newCard.ItemName.Text = itemName 
		newCard.ImageLabel.Image = itemData.ImageID or ""
		
		newCard:SetAttribute("Owned", false)
		
		newCard.ItemName.Text = "The " .. itemName 
		
		local infoButton = newCard:FindFirstChild("InfoButton")
		if not infoButton then continue end

		infoButton.Activated:Connect(function()
			shopFrame.Visible = false 
			soulArtefactFrame.Visible = true

			for _, child in pairs(soulArtefactFrame:GetChildren()) do
				if child:IsA("Frame") then
					child.Visible = false
				end
			end

			local selectedPage = soulArtefactFrame:FindFirstChild(itemName.."Page")
			if not selectedPage then return end 

			selectedPage.Visible = true 
			selectedPage:SetAttribute("From", "Shop")
		end)
		
		if itemData.Order then 
			newCard.LayoutOrder = itemData.Order 
		end
		
		newCard.Activated:Connect(function()
			currentlySelectedItems[categoryName] = {
				Category = categoryName, 
				Name = itemName, 
				Rarity = itemData.Rarity, 
				Price = itemData.Price,
				ProductID = itemData.ProductID,
				ImageID = itemData.ImageID,
				MorEx = itemData.MorEx,
				IsCrate = false
			}

			detailPage.ItemName.Visible = true 
			detailPage.ImageLabel.Visible = true  
			detailPage.BuyButton.Visible = true 
			detailPage.Price.Visible = true 

			detailPage.ItemName.Text = itemName 
			detailPage.Price.Text = "Price: " .. itemData.Price .. " SD"
			detailPage.Price.Position = UDim2.new(0.046, 0, 0.645, 0)
			detailPage.ImageLabel.Image = itemData.ImageID or ""

			-- Reposition Buy Button 
			local buyButton = detailPage:FindFirstChild("BuyButton")
			buyButton.Position = UDim2.new(0.115, 0, 0.805, 0)

			-- Disable RatesLabel 
			local ratesLabel = detailPage:FindFirstChild("RatesLabel")
			if ratesLabel then ratesLabel.Visible = false end


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
			
			if newCard:GetAttribute("Owned") then 
				detailPage.BuyButton.Visible = false 
				detailPage.BuyButton.Active = false 
				
				detailPage.OwnedLabel.Visible = true 
			else 
				detailPage.BuyButton.Visible = true 
				detailPage.BuyButton.Active = true 
				
				detailPage.OwnedLabel.Visible = false 
			end

			detailPage.Visible = true 
		end)
		
		newCard.Parent = itemContainer
		newCard.Visible = true
	end 
end

updateInventoryEvent.OnClientEvent:Connect(function(inventoryData)
	cachedInventory = inventoryData
	print("Received update")
	
	-- UPDATING SOUL ARTEFACTS
	local soulArtefactData = inventoryData["SoulArtefacts"]
	local soulArtefactConfig = categoryConfigs["SoulArtefacts"]
	local itemContainer = soulArtefactConfig.Page:WaitForChild("ItemContainer")
	
	for _, child in pairs(itemContainer:GetChildren()) do
		if child:IsA("ImageButton") and table.find(soulArtefactData, child.Name) then 
			child:SetAttribute("Owned", true)
		end
	end
end)


-- We handled the items, now let us populate the crates
local function populateShopCrates()
	for categoryName, config in pairs(categoryConfigs) do
		if not config.CratesDatabase then continue end 

		local crateContainer = config.Page:WaitForChild("CrateContainer")
		local itemContainer = config.Page:WaitForChild("ItemContainer") -- We need this to filter the items
		local detailPage = config.Page:WaitForChild("DetailPage")

		local crateDatabase = config.CratesDatabase
		local template = config.Template	

		for crateName, crateData in pairs(crateDatabase) do
			local newCard = template:Clone() 
			newCard.Name = crateName 
			newCard.ItemName.Text = crateName 
			newCard.ImageLabel.Image = crateData.ImageID or ""

			if crateData.Order then 
				newCard.LayoutOrder = crateData.Order 
			end

			newCard.Activated:Connect(function()
				currentlySelectedItems[categoryName] = {
					Category = categoryName, 
					Name = crateName, 
					Price = crateData.Price,
					IsCrate = true 
				}
				
				detailPage.ItemName.Visible = true 
				detailPage.ImageLabel.Visible = true 
				detailPage.BuyButton.Visible = true 
				detailPage.Price.Visible = true 

				detailPage.ItemName.Text = crateName 
				detailPage.Price.Text = "Price: " .. tostring(crateData.Price) .. " SD"
				detailPage.Price.Position = UDim2.new(0.046, 0, 0.745, 0)
				detailPage.ImageLabel.Image = crateData.ImageID or ""
				
				local ratesLabel = detailPage:FindFirstChild("RatesLabel")
				local dropRates = crateData.Rates 
				
				-- Managing Text 
				ratesLabel.RichText = true 

				ratesLabel.Text = 
					'<font color="#FFFFFF">Common:</font> ' .. dropRates["Common"] .. '%\n' ..
					'<font color="#00FFF7">Rare:</font> ' .. dropRates["Rare"] .. '%\n' ..
					'<font color="#A200FF">Epic:</font> ' .. dropRates["Epic"] .. '%\n' ..
					'<font color="#FFEA00">Legendary:</font> ' .. dropRates["Legendary"] .. '%'

				ratesLabel.Visible = true
				
				local rarityLabel = detailPage:FindFirstChild("Rarity")
				if rarityLabel then rarityLabel.Visible = false end -- Crates don't have rarities
				
				-- Reposition Buy Button -- 
				local buyButton = detailPage:FindFirstChild("BuyButton")
				buyButton.Position = UDim2.new(0.115, 0, 0.85, 0)

				-- This loops through the direct-buy items and hides ones not in the crate
				for _, itemCard in ipairs(itemContainer:GetChildren()) do
					if itemCard:IsA("GuiObject") then -- Ignores UILayouts
						local itemInCrate = false

						-- Check if the item exists in this crate's loot table
						if crateData.Items then
							for _, crateDrop in ipairs(crateData.Items) do
								if crateDrop.Name == itemCard.Name then
									itemInCrate = true
									break
								end
							end
						end

						itemCard.Visible = itemInCrate
					end
				end
				detailPage.Visible = true 
			end)

			newCard.Parent = crateContainer
			newCard.Visible = true
		end
	end 
end


local function populateSoulDust()
	local soulDustData = categoryConfigs["SoulDust"]
	local soulDustPage = soulDustData.Page 
	local soulDustDatabase = soulDustData.Database
	local soulDustTemplate = soulDustData.Template
	local detailPage = soulDustPage:WaitForChild("DetailPage") 
	local itemContainer = soulDustPage:WaitForChild("ItemContainer")
	local categoryName = "SoulDust"
	
	for itemName, itemData in pairs(soulDustDatabase) do  
		local newCard = soulDustTemplate:Clone()
		newCard.Name = itemName 
		newCard.ItemName.Text = itemName 
		newCard.ImageLabel.Image = itemData.ImageID or "" 
		
		if itemData.Bonus then 
			newCard.Bonus.Text = "+ " .. itemData.Bonus .. "!"
			newCard.Bonus.Visible = true 
		else 
			newCard.Bonus.Visible = false 
		end
		
		if itemData.Order then 
			newCard.LayoutOrder = itemData.Order  
		end 
		
		newCard.Activated:Connect(function()
			currentlySelectedItems[categoryName] = { 
				Category = categoryName, 
				Name = itemName,
				Price = itemData.Price, 
				ProductID = itemData.ProductID, 
				ImageID = itemData.ImageID, 
				IsCrate = false 
			}
			
			detailPage.ItemName.Visible = true 
			detailPage.ImageLabel.Visible = true 
			detailPage.Amount.Visible = true 
			detailPage.BuyButton.Visible = true 
			detailPage.Price.Visible = true 
			
			detailPage.ItemName.Text = itemName 
			detailPage.ImageLabel.Image = itemData.ImageID or "" 
			
			local hex = Color3.fromRGB(255, 238, 0):ToHex() 
			detailPage.Amount.RichText = true 
			if itemData.Bonus then 
				detailPage.Amount.Text = itemData.Amount .. " Soul Dust \n<font color=\"#" .. hex .. "\">(+" .. itemData.Bonus .. " Bonus)</font>"
			else 
				detailPage.Amount.Text = itemData.Amount .. " Soul Dust"
			end 
			
			
			detailPage.Price.Text = itemData.Price .. "R$"  
		end)
		
		newCard.Parent = itemContainer
		newCard.Visible = true
	end 
end


local function initialiseDetailPages()
	for category, config in pairs(categoryConfigs) do 
		local detailPage = config.Page:WaitForChild("DetailPage")
		
		detailPage.ItemName.Text = "No item selected"
		detailPage.BuyButton.Visible = false 
		detailPage.ImageLabel.Visible = false 
		detailPage.Price.Visible = false 
		
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


local function initialiseCurrencyTrackers()
	for category, config in pairs(categoryConfigs) do 
		local page = config.Page  
		local currencyLabel = page:WaitForChild("CurrencyLabel") 
		
		local player = game.Players.LocalPlayer  
		
		local currentBalance = player:GetAttribute("Currency") or 0 
		currencyLabel.Text = currentBalance .. " SD"
		
		player:GetAttributeChangedSignal("Currency"):Connect(function()
			local curr = player:GetAttribute("Currency") or 0 
			currencyLabel.Text = curr .. " SD"
		end)
	end
end


-- MAIN -- 
populateShop()
populateShopCrates()
populateSoulDust()
initialiseDetailPages()
initialiseCurrencyTrackers()
populateSoulArtefacts()