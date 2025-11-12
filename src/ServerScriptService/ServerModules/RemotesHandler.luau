local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerBindables = script.Parent.Parent.ServerBindables

-- modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemDesc = require(Modules:WaitForChild("ItemDesc"))

-- Bindables and Folders
local ItemAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Items")
local GetSerializedData: BindableFunction = ServerBindables:WaitForChild("GetSerializedData")
local SetSerializedData: BindableFunction = ServerBindables:WaitForChild("SetSerializedData")

local invokeAction: RemoteFunction = Remotes:WaitForChild("InvokeInventoryAction")

function module.DropItem(player: Player, slotIndex: number): boolean
	local serializedData = GetSerializedData:Invoke(player)
	if not serializedData then return false end
	
	local hotBarinfo = serializedData["Hotbar"]
	local slotInfo = hotBarinfo[slotIndex]
	if not slotInfo.ItemId then return false end
	
	local itemInfo = ItemDesc[slotInfo.ItemId]
	if not itemInfo then return false end

	-- all items can be dropped by default
	print("Dropping item.", slotInfo.ItemId, "x", slotInfo.Quantity)

	-- remove from inventory
	hotBarinfo[slotIndex] = {}
	SetSerializedData:Invoke(player, serializedData)

	local success = invokeAction:InvokeClient(player, "LoadFromSerialized", serializedData)
	print("success:", success)
	
	return true
end

function module.EquipHotbarSlotForPlayer(player: Player, slotIndex: number): (boolean, boolean?)
	-- returns success, canActivate
	
	local serializedData = GetSerializedData:Invoke(player)
	if not serializedData then return false, nil end
	
	local hotBarinfo = serializedData["Hotbar"][slotIndex]
	if not hotBarinfo.ItemId then return true, false end
	
	-- is it possible to activate this??
	local asset = ItemAssets:FindFirstChild(hotBarinfo.ItemId)
	if not asset then return true, false end
	
	if player.Backpack:FindFirstChild(asset.Name) then return true, true end
	asset:Clone().Parent = player.Backpack
	
	return true, true
end

function module.UnequipHotbarSlotForPlayer(player: Player, slotIndex: number)
	local serializedData = GetSerializedData:Invoke(player)
	if not serializedData then return end

	local hotBarinfo = serializedData["Hotbar"]
	local slotInfo = hotBarinfo[slotIndex]
	
	local asset =  player.Backpack:FindFirstChild(slotInfo.ItemId)
	if asset then
		asset:Destroy()
	end
	
	return true
end

return module
