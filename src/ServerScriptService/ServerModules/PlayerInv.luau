local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local itemInfo = require(Modules:WaitForChild("ItemDesc"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InvokeInventoryAction: RemoteFunction = Remotes:WaitForChild("InvokeInventoryAction")

export type ItemData = {
	ItemId: string,
	Quantity: number,
}

export type ItemReference = {
	InvType: string,
	Index: number
}

type Inventory = {[number]: ItemData?}
type PlayerInventory = {[string]: Inventory}
local inventories: { [number]: PlayerInventory } = {}

local PlayerInventories = {}

--[[
SerializedData = {
	["Armor"] = {
		[1] = {ItemId: string, Quantity: number},
		[2] = {ItemId: string, Quantity: number},
		[3] = {ItemId: string, Quantity: number},
		[4] = {ItemId: string, Quantity: number},
	},
	
	["Main"] = { 
		[1] = {ItemId: string, Quantity: number},
		[2] = {ItemId: string, Quantity: number},
		...
		[24] = {ItemId: string, Quantity: number}
	},
	
	["Offhand"] = {[1] = {ItemId: string, Quantity: number}},
	
	["Hotbar"] = {[1] = {ItemId: string, Quantity: number}, ..., [8] = {}}
}
]]

function PlayerInventories.loadInventory(player: Player, inventoryData: PlayerInventory, reloadinv: boolean?)
	if inventories[player.UserId] and not reloadinv then return end

	-- Deep copy 
	local copy = {}
	for invType, invTable in pairs(inventoryData) do
		copy[invType] = {}
		for i, v in pairs(invTable) do
			if v and v.ItemId and v.Quantity and v.Quantity > 0 then
				copy[invType][tonumber(i)] = {ItemId = tostring(v.ItemId), Quantity = tonumber(v.Quantity)}
			end
		end
	end

	inventories[player.UserId] = copy
	return inventories[player.UserId]
end

function PlayerInventories.destroyInventory(player: Player)
	inventories[player.UserId] = nil
end

function PlayerInventories.MoveItem(player: Player, fromRef: ItemReference, toRef: ItemReference, quantity: number?): boolean
	if (toRef.Index == fromRef.Index and toRef.InvType == fromRef.InvType) then
		return InvokeInventoryAction:InvokeClient(player, "LoadFromSerialized", inventories[player.UserId], false)
	end
	
	local playerInv = inventories[player.UserId]
	if not playerInv then warn("No player inv.") return false end

	local fromInv = playerInv[fromRef.InvType]
	local toInv = playerInv[toRef.InvType]
	if not fromInv or not toInv then warn("No to/from inv") return false end

	local itemFrom = fromInv[fromRef.Index]
	if not itemFrom or not itemFrom.ItemId then warn("No itemFrom") return false end
	
	if itemInfo[itemFrom.ItemId].Type ~= "Armor" and toRef.InvType == "Armor" then
		return false
	end

	quantity = quantity or itemFrom.Quantity
	if quantity <= 0 or quantity > itemFrom.Quantity then warn("Invalid Quantity") return false end

	local itemTo = toInv[toRef.Index]
	local remainingQuantity = itemFrom.Quantity - quantity

	if not itemTo or not itemTo.ItemId then -- Moving to an empty slot
		toInv[toRef.Index] = { ItemId = itemFrom.ItemId, Quantity = quantity }
		if remainingQuantity <= 0 then
			playerInv[fromRef.InvType][fromRef.Index] = {}
		else
			itemFrom.Quantity = remainingQuantity
		end
	elseif itemTo.ItemId == itemFrom.ItemId then -- Stacking onto the same item type
		if itemInfo[itemTo.ItemId].Stacking == false then warn("Cannot stack that") return false end
		
		itemTo.Quantity += quantity
		if remainingQuantity <= 0 then
			playerInv[fromRef.InvType][fromRef.Index] = {}
		else
			itemFrom.Quantity = remainingQuantity
		end
	else
		if remainingQuantity ~= 0 then return false end
		fromInv[fromRef.Index], toInv[toRef.Index] = toInv[toRef.Index], fromInv[fromRef.Index]
	end

	return InvokeInventoryAction:InvokeClient(player, "LoadFromSerialized", inventories[player.UserId], false)
end

-- we probably wont need this...
function PlayerInventories.AddItem(player: Player, itemId: string, quantity: number, ref: ItemReference): boolean
	local playerInv = inventories[player.UserId]
	if not playerInv or quantity <= 0 then return false end

	local targetInv = playerInv[ref.InvType]
	if not targetInv then return false end

	local targetSlot = targetInv[ref.Index]
	if targetSlot and targetSlot.ItemId and targetSlot.ItemId ~= itemId then return false end

	if targetSlot and targetSlot.ItemId == itemId then
		targetSlot.Quantity += quantity
	else
		targetInv[ref.Index] = { ItemId = itemId, Quantity = quantity }
	end
	
	if ref.InvType == "Offhand" then
		InvokeInventoryAction:InvokeClient(player, "AddOffhandToSlot", itemId, quantity)
		return true
	end
	
	local funcCall = ref.InvType == "Armor" and "AddArmorToSlot" or "AddItemToSlot"
	InvokeInventoryAction:InvokeClient(player, funcCall, ref.Index, itemId, quantity)
	
	return true
end

function PlayerInventories.RemoveItemFromSlot(player: Player, ref: ItemReference, quantity: number): boolean
	local playerInv = inventories[player.UserId]
	if not playerInv then return false end

	local targetInv = playerInv[ref.InvType]
	if not targetInv then return false end

	local targetSlot = targetInv[ref.Index]
	if not targetSlot or not targetSlot.ItemId then return false end

	if quantity <= 0 or quantity > targetSlot.Quantity then return false end

	targetSlot.Quantity -= quantity
	if targetSlot.Quantity <= 0 then
		targetInv[ref.Index] = {}
	end
	
	return true
end

function PlayerInventories.RemoveInstancesOfItem(player: Player, itemId: string, quantity: number)
	print("Removing instances not yet implemented.")
end

function PlayerInventories.GetSerializedData(player: Player): PlayerInventory?
	local playerInv = inventories[player.UserId]
	if not playerInv then warn("No player inv was saved yet.") return nil end
	
	local copy = {}

	local maxSlots = {
		Armor = 4,
		Main = 24,
		Offhand = 1,
		Hotbar = 8
	}

	for invType, invTable in pairs(playerInv) do
		local maxIndex = maxSlots[invType] or 0

		copy[invType] = {}

		for i = 1, maxIndex do
			local itemData = invTable[i]
			if itemData and itemData.ItemId and itemData.Quantity and itemData.Quantity > 0 then
				copy[invType][i] = {
					ItemId = itemData.ItemId,
					Quantity = itemData.Quantity
				}
			else
				copy[invType][i] = {}
			end
		end
	end
	
	return copy
end

return PlayerInventories

