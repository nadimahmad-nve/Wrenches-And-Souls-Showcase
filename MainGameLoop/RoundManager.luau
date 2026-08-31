local RoundManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExpCurrencyManager = require(script.Parent.ExpCurrencyManager)
local EliminationManager = require(script.Parent.EliminationManager)
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local globalStatus = game:GetService("ReplicatedStorage"):WaitForChild("GlobalStatus")
local triggerRoundCooldowns = ServerStorage:WaitForChild("BindableEvents"):WaitForChild("TriggerRoundCooldowns")
local NotificationEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("NotificationEvent")

function convertTime(time) 
	local minutes = math.floor(time / 60)
	local seconds = time % 60
	return string.format("%02d:%02d", minutes, seconds) 
end

function RoundManager.StartRoundLoop(exterminator)
	local ROUND_TIME = 12 * 60 
	local timeLeft = ROUND_TIME 
	local winner = nil 
	local cinematicPlayed = false 
	
	
	while timeLeft > 0 and winner == nil do 
		if exterminator == nil then 
			winner = "Mechanics"
			break 
		end 
		
		local players = Players:GetPlayers() 
		task.wait(1)
		timeLeft -= 1 
		if globalStatus then 
			local convertedTime = convertTime(timeLeft) 
			globalStatus.Value = "TIME REMAINING: "..tostring(convertedTime) 
		end
		
		if exterminator.Parent == nil then 
			exterminator = nil 
			winner = "Mechanics"
			break 
		end 
		
		local aliveMechanics = 0 
		local escapedMechanics = 0
		
		for _, player in ipairs(players) do 
			if player:GetAttribute("Role") == "Mechanic" then 
				local status = player:GetAttribute("RoundStatus")
				
				if status == "Alive" then 
					aliveMechanics += 1 
				elseif status == "Escaped" then 
					escapedMechanics += 1 
				end
			end
		end
		
		if aliveMechanics == 0 then 
			print("No mechanics left.")

			local cinematicPlaying = false

			for _, player in ipairs(players) do
				if player:GetAttribute("RoundStatus") == "Downed" and player:GetAttribute("RoundStatus") ~= "Dead" then
					EliminationManager.EliminatePlayer(player, exterminator)

					cinematicPlaying = true
					cinematicPlayed = true 
				end
			end

			-- If the cinematic triggered, halt the round manager
			if cinematicPlaying then
				task.wait(4) 
			end

			if escapedMechanics > 0 then 
				winner = "Mechanics"
			else 
				winner = "Exterminator"
			end

			break 
		end
	end
	
	if not cinematicPlayed then 
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("Role") == "Mechanic" then 
				player:SetAttribute("RoundStatus", "Survived")
			end
		end
		
		task.wait(4)
	end
	
	globalStatus.Value = "Game Over!"
	
	if winner == nil then 
		winner = "Exterminator" 
	end

	local leftoverPlayers = {} 
	
	-- Time ran out 
	-- Gather everyone who didn't escape
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Role") == "Mechanic" then
			local status = player:GetAttribute("RoundStatus")

			-- Only collect players who haven't been processed yet
			if status == "Survived" or status == "Downed" then 
				table.insert(leftoverPlayers, player)
			end
		end
	end

	return {WinningTeam = winner, Survivors = leftoverPlayers, Exterminator = exterminator}
end


function RoundManager.TriggerCooldowns(players) 
	triggerRoundCooldowns:Fire(players)
end

return RoundManager 