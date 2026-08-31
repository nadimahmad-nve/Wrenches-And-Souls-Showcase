-- SERVICES -- 
local GameModules = script.Parent 
local ServerStorage = game:GetService("ServerStorage") 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- MODULES -- 
local RoundManager = require(GameModules.RoundManager)
local RoleManager = require(GameModules.RoleManager)
local MapManager = require(GameModules.MapManager)
local ObjectiveManager = require(GameModules.ObjectiveManager)
local ExpCurrencyManager = require(GameModules.ExpCurrencyManager)

local CutsceneModule = require(ReplicatedStorage.ModuleScripts.CutsceneHandler)

-- VARIABLES -- 
local globalStatus = game:GetService("ReplicatedStorage"):WaitForChild("GlobalStatus")

-- REMOTE EVENTS -- 
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local TransitionEvent = RemoteEvents:WaitForChild("TransitionEvent")
local CutsceneEvent = RemoteEvents:WaitForChild("PlayCutsceneEvent")

-- MAIN -- 
while true do 
	print("STATUS: Intermission")
	globalStatus.Value = "Intermission"

	MapManager.SetupMapVoting() 
	ReplicatedStorage:SetAttribute("RoundState", "Intermission") 
		
	local MIN_PLAYERS = 2 
	
	-- Waiting for Players
	repeat
		globalStatus.Value = "Waiting for players..."
		task.wait(2)
	until #game.Players:GetPlayers() >= MIN_PLAYERS

	print("STATUS: Intermission Starting")

	local countdown = 40
	local enoughPlayers = true 

	-- Countdown
	while countdown > 0 do 
		if #game.Players:GetPlayers() < MIN_PLAYERS then
			enoughPlayers = false
			break 
		end

		globalStatus.Value = "INTERMISSION: " .. countdown
		countdown -= 1 
		task.wait(1)
	end

	if not enoughPlayers then
		print("STATUS: Intermission Cancelled")
		globalStatus.Value = "Players left! Cancelling round..."
		task.wait(3)

		MapManager.ClearMapVoting() 

		continue 
	end
	
	print("STATUS: Intermission Ending")
	globalStatus.Value = "Intermission Ending"

	task.wait(4)
	
	print("STATUS: Loading map")
	local chosenMap = MapManager.GetMap() 
	local map = MapManager.LoadMap(chosenMap)
	
	print("STATUS: Playing Cutscene")
	globalStatus.Value = "Introducing map..." 
	ReplicatedStorage:SetAttribute("RoundState", "Starting") 
	TransitionEvent:FireAllClients()
	task.wait(0.6)
	CutsceneEvent:FireAllClients(chosenMap)
	
	local cutsceneConnection = Players.PlayerAdded:Connect(function(player)
		local character = player.Character or player.CharacterAdded:Wait()
		if not player:IsDescendantOf(Players) then return end -- Safely abort if they left!

		print("Cutscene playing for late player " .. player.Name)
		
		TransitionEvent:FireClient(player)
		task.wait(0.6)
		CutsceneEvent:FireClient(player, chosenMap)
	end)
	
	task.wait(CutsceneModule[map.Name].Cooldown)
	
	cutsceneConnection:Disconnect()
	
	print("STATUS: Loading roles")
	local players = game.Players:GetPlayers()
	local exterminator = RoleManager.AssignRoles(players)
	
	print("STATUS: Teleporting...")
	MapManager.TeleportPlayers(players, map.SpawnLocations)
	RoleManager.ShowStartingUI(players) 
	
	print("STATUS: Game starting")
	globalStatus.Value = "Game starting"
	
	MapManager.ClearMapVoting()
	ObjectiveManager.Initialise(map.FixParts, map.ExitDoors, map.ActiveGenerators)
	RoundManager.TriggerCooldowns(players)
	
	-- SAFETY 
	local success, errorMessage = pcall(function()
		local roundResults = RoundManager.StartRoundLoop(exterminator)

		MapManager.CleanupPlayers(roundResults.Survivors, roundResults.Exterminator)
		local statsTable = ExpCurrencyManager.ProcessRemainingPlayers(roundResults.Survivors, roundResults.Exterminator)

		ExpCurrencyManager.DisplayStats(statsTable)

		print("STATUS: Game Over! Winning Team:" .. roundResults.WinningTeam)
	end)

	-- If game crashed..
	if not success then
		warn("CRITICAL SERVER ERROR DURING ROUND: " .. errorMessage)
		globalStatus.Value = "Server Error! Restarting lobby..."
	end

	-- Run cleanup (IMPORTANT)
	MapManager.CleanupMap()
	RoleManager.RemoveRoles(game.Players:GetPlayers())

	if not success then
		globalStatus.Value = "Game Over!"
	end

	task.wait(5)
end