local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local MapController = require(script.MapController) -- Loading maps/players

-- Remotes
local updateTimer = ReplicatedStorage.Remotes.updateTimer
local updateWinner = ReplicatedStorage.Remotes.updateWinner

local RoundController = {}

local States = {
	Waiting = 'Waiting', -- Not enough players
	Intermission = 'Intermission',
	Playing = 'Playing',
	Results = 'Results'
}

-- Config
local MIN_PLAYERS = 1
local INTERMISSION_DURATION = 15
local ROUND_DURATION = 15
local RESULTS_DURATION = 10

-- Base states
local currentState = States.Waiting
local timeRemaining = 0
local countdownGeneration = 0
local started = false
local roundParticipants: {[Player]: boolean} = {}

-- Changes the current state.
local function setState(newState: string)
	if currentState == newState then
		return
	end

	currentState = newState
	print('Round controller state: ', currentState)
end

-- Countdown - uses generation tokens to prevent multiple/overlapping countdowns
local function countdown(duration: number)
	countdownGeneration+= 1
	local thisGeneration = countdownGeneration
	local deadline = time() + duration

	while time() < deadline do

		-- This cancels the countdown. This will be true when a new countdown got started
		if thisGeneration ~= countdownGeneration then 
			return false
		end

		timeRemaining = math.max(0,math.ceil(deadline - time())) -- No negatives + always whole number

		print(timeRemaining)
		updateTimer:FireAllClients(timeRemaining)
		task.wait(0.1)
	end

	if thisGeneration ~= countdownGeneration then
		return false
	end

	timeRemaining = 0
	return true
end

-- Helper for evaluatePlayerCount()
-- excludedPlayer: prevent a player who just left from accidentally being counted
local function isEnoughPlayers(excludedPlayer: Player?)
	local count = 0

	for _, player in Players:GetPlayers() do
		if player ~= excludedPlayer then
			count+= 1

		end
	end

	return count >= MIN_PLAYERS
end

-- Cancels the ongoing countdown (not enough players)
local function cancelCountdown()
	countdownGeneration+= 1
	timeRemaining = 0
end

-- Takes a snapshot of all the players that are just about to play a round
local function registerPartipants()
	table.clear(roundParticipants)

	for _, player in Players:GetPlayers() do
		roundParticipants[player] = true
	end
end

-- Selects a random winner from the round participants.
local function selectRandomWinner(roundParticipants)

	local participants = {}

	for player in roundParticipants do
		table.insert(participants, player)
	end

	return participants[math.random(1,#participants)]
end




-- Rturns the number of round participants
local function getParticipantCount()
	local count = 0

	for _ in roundParticipants do
		count += 1
	end

	return count
end

-- To deal with stupid luau scope
local playRound
local evaluatePlayerCount

-- Starts intermission state and countdown
local function startIntermission()
	if currentState ~= States.Waiting then
		return
	end

	setState(States.Intermission)

	task.spawn(function()
		local completed = countdown(INTERMISSION_DURATION)

		if completed and isEnoughPlayers() then
			setState(States.Playing)
			playRound()
		elseif completed then
			setState(States.Waiting)
		end
	end)
end

-- Decides whether to change state depending on current player count
-- Excluded player: prevents a player who just left from being counted
-- in the next player count.
evaluatePlayerCount = function(excludedPlayer: Player?)
	if currentState == States.Waiting then
		if isEnoughPlayers(excludedPlayer) then
			startIntermission()
		else
			print('Not enough players')
		end

	elseif currentState == States.Intermission then
		if not isEnoughPlayers(excludedPlayer) then
			cancelCountdown()
			setState(States.Waiting)
		end
	end
end

-- Called at the end of a round countdown or when the player count is too low.
-- EarlyWinner: the winner when the round ends early due to low player count.
-- Updates results ui, refreshes workspace and ends timer. Waits for the set
-- results duration before restarting the loop
local function endRound(participants, earlyWinner: Player?)
	
	if currentState ~= States.Playing then
		return
	end
	
	setState(States.Results)
	
	cancelCountdown()
	MapController.deleteMap()

	if earlyWinner then
		updateTimer:FireAllClients(0)
		print(earlyWinner.Name .. 'has won the round!')
		updateWinner:FireAllClients(earlyWinner.Name)
	else
		local winner = selectRandomWinner(participants)
		print(winner.Name .. ' has won the round!')
		updateWinner:FireAllClients(winner.Name)
	end
	--

	task.wait(RESULTS_DURATION) -- Results display time
	updateWinner:FireAllClients() -- The empty call hides the visibility of the label
	setState(States.Waiting)
	evaluatePlayerCount() -- Continue round loop
end


-- Handing a round being played
playRound = function()
	registerPartipants()
	local loaded = MapController.loadMap()
	local teleported = false
	local finished = false
	local participants = {}
	for player in roundParticipants do
		table.insert(participants, player)
	end

	if loaded then
		teleported = MapController.bringPlayers(participants)
	end

	if teleported then
		finished = countdown(ROUND_DURATION)
	end
	
	

	if finished then
		endRound(roundParticipants)
	end

end



-- Returns the round controller's current state.
function RoundController.getState()
	return currentState
end

-- Returns the current time remaining on the countdown.
function RoundController.getTimeRemaining()
	return timeRemaining
end

-- Starts the round controller instance
function RoundController.Start()
	if started then
		return
	end

	started = true

	Players.PlayerAdded:Connect(function(player)
		evaluatePlayerCount()
	end)

	Players.PlayerRemoving:Connect(function(player)
		if currentState == States.Playing then
			roundParticipants[player] = nil

			if getParticipantCount() == 1 then
				local earlyWinner = next(roundParticipants)
				endRound(roundParticipants, earlyWinner)
			end
		end

		evaluatePlayerCount(player)
	end)

	-- For players connected before controller started
	evaluatePlayerCount()
end


return RoundController
