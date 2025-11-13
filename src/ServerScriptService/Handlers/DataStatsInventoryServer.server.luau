
--[[

Here is some info you might wanna know later
Firstly, this system was made as a "whole" where the inventory + data saving was handled by ONE script.
That script is the one you're seeing right now.

That was done to keep this entire framework separate from stuff like remote event handlers.
And the communication is being done using server bindables.

That might sound a little unprofessional, and I do not remember WHY this was done in the first place.
But it is what it is. Everything works and its completely fine.

Use bindables to fetch data (saving and getting).

If you are looking for data saving or any remote events that handle inventory, you're at the right place ;)
Else you might wanna look for (or create maybe?) a "remote event handler" script that might be somewhere else
in the serverScriptStorage.

(Also, we treat "Hotbars" and "Item equipping through slots" as a different functionality, so yeah.)

]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- Modules
local Modules = ServerScriptService:WaitForChild("ServerModules")
local ProfileStore = require(Modules:WaitForChild("ProfileStore"))
local PlayerInventories = require(Modules:WaitForChild("PlayerInv"))

-- Bindables & Remotes
local ServerBindables = ServerScriptService:WaitForChild("ServerBindables")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Modules
local ItemDesc = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemDesc"))

local GetSerializedData: BindableFunction = ServerBindables:WaitForChild("GetSerializedData")
local SetSerializedData: BindableFunction = ServerBindables:WaitForChild("SetSerializedData")
local SaveData: BindableFunction = ServerBindables:WaitForChild("SaveData")
local GetData: BindableFunction = ServerBindables:WaitForChild("GetData")

local invokeAction: RemoteFunction = Remotes:WaitForChild("InvokeInventoryAction")

local PROFILE_TEMPLATE = {
	Points = 0,
	Coins = 100,
	Inventory = {
		Main = {},
		Armor = {},
		Offhand = {},
		Hotbar = {}
	}
}

-- Setup ProfileStore
local GameProfileStore = ProfileStore.New(
	"PlayerData_V1",
	PROFILE_TEMPLATE
)

local PlayerProfiles = {}

local function onPlayerAdded(player: Player)
	local profile: ProfileStore.Profile = GameProfileStore:StartSessionAsync("Player_" .. player.UserId)

	if not profile then
		player:Kick("Your data could not be loaded. Please rejoin.\nErrorCode: 000")
		return
	end
	
	profile:Reconcile() -- Update data received based on the latest template
	
	if profile.SessionLoadCount == 1 then
		-- brand new player!!
		print("Welcome to this game", player.Name)
		-- gift a badge here ig
		
		local c = 1
		for itemName, v in pairs(ItemDesc) do
			profile.Data.Inventory.Main[c] = {
				ItemId = itemName,
				Quantity = 10
			}
			c += 1
			
			if v.Stacking then
				profile.Data.Inventory.Main[c - 1] = {
					ItemId = itemName,
					Quantity = 2
				}
			else
				profile.Data.Inventory.Main[c] = {
					ItemId = itemName,
					Quantity = 1
				}
				c += 1
			end
		end
	end
	
	if player:IsDescendantOf(Players) then
		-- Player is still in the game, so store the profile and load their inventory
		PlayerProfiles[player.UserId] = profile
		print("Immediate load: ", profile.Data.Inventory)
		local finalinv = PlayerInventories.loadInventory(player, profile.Data.Inventory)
		-- load other stats
		
		local success = invokeAction:InvokeClient(player, "LoadFromSerialized", PlayerInventories.GetSerializedData(player))
		if not success then
			-- uh oh
			profile:EndSession()
			PlayerProfiles[player.UserId] = nil
			player:Kick("Something went wrong. Please rejoin.")
			return
		end
		
		local leaderstats = Instance.new("Folder", player)
		leaderstats.Name = "leaderstats"
		local CointsVal = Instance.new("IntValue", leaderstats)
		CointsVal.Value = profile.Data.Coins
		CointsVal.Name = "Coins"
	else
		-- Player left while the profile was loading, release session lock.
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = PlayerProfiles[player.UserId]
	if profile then
		profile.Data.Inventory = PlayerInventories.GetSerializedData(player)
		profile:Save()
		profile:EndSession()
		print(player.Name .. "'s session has ended and data is saving.", profile.Data.Inventory)
		
		PlayerProfiles[player.UserId] = nil
		PlayerInventories.destroyInventory(player)
	end
end

invokeAction.OnServerInvoke = function(player: Player, action: string, ...)
	if not PlayerProfiles[player.UserId] then return { success = false, reason = "Profile not loaded." } end

	if action == "RequestMoveItem" then
		local success = PlayerInventories.MoveItem(player, ...)
		PlayerProfiles[player.UserId].Data.Inventory = PlayerInventories.GetSerializedData(player)
		return {success = success}
	end
	
	-- Allowing a singular client to get access to its data only.
	if action == "GetData" then
		local data = PlayerInventories.GetSerializedData(player)
		return {data = data}
	end

	return { success = false, reason = "Unauthorized action." }
end

-- Passing info around using bindables on the server
GetSerializedData.OnInvoke = function(player: Player)
	if not PlayerProfiles[player.UserId] then return nil end
	return PlayerInventories.GetSerializedData(player)
end

SetSerializedData.OnInvoke = function(player: Player, serializedData: any)
	if not PlayerProfiles[player.UserId] then return false end
	return PlayerInventories.loadInventory(player, serializedData, true)
end

-- Gets the data that was saved
GetData.OnInvoke = function(player: Player)
	local profile = PlayerProfiles[player.UserId]
	if profile then
		-- Return a DEEP COPY
		return table.clone(profile.Data)
	end
	return nil
end

-- Saves the data
SaveData.OnInvoke = function(player: Player)
	local profile = PlayerProfiles[player.UserId]
	if profile and profile:IsActive() then
		profile.Data.Inventory = PlayerInventories.GetSerializedData(player)
		
		-- other stuff
		
		profile:Save()
		return true
	end
	return false
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end