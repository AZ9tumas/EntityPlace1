local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipSlot = Remotes:WaitForChild("EquipSlot")
local DropItem = Remotes:WaitForChild("DropItem")

local ServerModules = script.Parent.Parent.ServerModules
local RemotesHandler = require(ServerModules.RemotesHandler)

EquipSlot.OnServerInvoke = function(plr: Player, equipStats: boolean, ...)
	if equipStats == true then
		return RemotesHandler.EquipHotbarSlotForPlayer(plr, ...)
	else
		return RemotesHandler.UnequipHotbarSlotForPlayer(plr, ...)
	end
end

DropItem.OnServerInvoke = function(plr: Player, slotIndex: number, quantity: number?)
	return RemotesHandler.DropItem(plr, slotIndex, quantity or 1)
end