local StateManager = {}

-- Dictionary to track active states per character
local activeStates = {}

-- CONSTANTS 
local SPRINT_SPEED = 21
local MECHANIC_BASE_SPEED = 16
local EXTERMINATOR_BASE_SPEED = 17
local SLOW_SPEED = 8
local DOWNED_SPEED = 2
local STUN_SPEED = 0
local PENALTY_SPEED = 8
local CROUCH_SPEED = 8

-- Core logic: Determines what the character's properties should be right now
local function evaluateState(character)
	local states = activeStates[character]
	if not states then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local player = game.Players:GetPlayerFromCharacter(character)
	if not humanoid or not player then return end

	-- THE STRICT WATERFALL
	if states.Dead > 0 then 
		humanoid.WalkSpeed = 0
		player:SetAttribute("MovementState", "Dead")
	
	elseif states.Downed > 0 then 
		humanoid.WalkSpeed = DOWNED_SPEED
		player:SetAttribute("MovementState", "Downed")

	elseif states.Stun > 0 then
		humanoid.WalkSpeed = STUN_SPEED
		player:SetAttribute("MovementState", "Stunned")
		
	elseif states.JumpPenalty > 0 then
		humanoid.WalkSpeed = PENALTY_SPEED
		player:SetAttribute("MovementState", "JumpPenalty")	
		
	elseif states.MedicHeal > 0 then
		humanoid.WalkSpeed = 0
		player:SetAttribute("MovementState", "MedicHeal")
		
	elseif states.ChaseUlt > 0 then
		humanoid.WalkSpeed = 25
		player:SetAttribute("MovementState", "ChaseUlt")

	elseif states.Slow > 0 then
		humanoid.WalkSpeed = SLOW_SPEED
		player:SetAttribute("MovementState", "Slowed")
		
	elseif states.AllSightUlt > 0 then
		local stacks = player:GetAttribute("AllSightStacks") or 0
		local base = 17 
		humanoid.WalkSpeed = base + (base * (0.25 * stacks))
		player:SetAttribute("MovementState", "AllSightUlt")	
		
	elseif states.Crouch > 0 then
		humanoid.WalkSpeed = CROUCH_SPEED
		player:SetAttribute("MovementState", "Crouching")

	elseif states.Sprint > 0 then
		humanoid.WalkSpeed = SPRINT_SPEED
		player:SetAttribute("MovementState", "Sprinting")
		
	else
		local role = player:GetAttribute("Role")

		if role == "Exterminator" then
			humanoid.WalkSpeed = EXTERMINATOR_BASE_SPEED
		else
			humanoid.WalkSpeed = MECHANIC_BASE_SPEED
		end

		player:SetAttribute("MovementState", "Normal")
	end
	
end

-- Public function to apply a state
function StateManager.AddState(character, stateName, duration)
	-- Initialise the character with all possible states if they are new
	if not activeStates[character] then
		activeStates[character] = {Dead = 0, Downed = 0, Stun = 0, Slow = 0, Sprint = 0, JumpPenalty = 0, Crouch = 0, AllSightUlt = 0, ChaseUlt = 0, MedicHeal = 0}
	end

	-- Add the state and immediately recalculate
	activeStates[character][stateName] += 1
	evaluateState(character)

	-- Automatically remove the state after the duration expires
	task.delay(duration, function()
		if activeStates[character] then
			activeStates[character][stateName] -= 1
			evaluateState(character)
		end
	end)
end

-- Public function to manually remove a state
function StateManager.RemoveState(character, stateName)
	if activeStates[character] and activeStates[character][stateName] then
		if activeStates[character][stateName] > 0 then
			activeStates[character][stateName] -= 1
			evaluateState(character)
		end
	end
end

function StateManager.ForceEvaluate(character)
	if activeStates[character] then
		evaluateState(character)
	end
end

-- Cleanup function 
function StateManager.ClearCharacter(character)
	activeStates[character] = nil

	-- Safely reset the physical model if it still exists
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpHeight = 5
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end

	-- Reset the attribute so the LocalScripts update
	local player = game.Players:GetPlayerFromCharacter(character)
	if player then
		player:SetAttribute("MovementState", "Normal")
	end
end

return StateManager