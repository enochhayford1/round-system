local CollectionService = game:GetService('CollectionService')
local maps = CollectionService:GetTagged('map')
local MapController = {}


-- Provides a random map index for use in loadMap from the maps array
local function chooseMap()
	return math.random(1,#maps)
end

-- Loads a map into the workspace.
function MapController.loadMap()
	local map = maps[chooseMap()] -- random index, random map
	map.Parent = game.Workspace.current
	map.Name = 'currentMap'
	return true
end

-- Deletes a map from the workspace
function MapController.deleteMap()
	local map = game.Workspace.current:FindFirstChild('currentMap')
	map.Parent = nil
end

-- Teleports players to a loaded map
function MapController.bringPlayers(players)
	local map = game.Workspace.current:FindFirstChild('currentMap')
	for _, player: Player in players do
		player.Character.HumanoidRootPart.CFrame = CFrame.new(map.to.Position + Vector3.new(0,5,0))
	end
	return true
end

return MapController
