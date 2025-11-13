local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerBindables = script.Parent.Parent.ServerBindables
local Assets = ReplicatedStorage:WaitForChild("Assets")
local PlaceHolders = Assets:WaitForChild("PlaceHolders")

-- modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local ItemDesc = require(Modules:WaitForChild("ItemDesc"))

export type ItemReference = {
	InvType: string,
	Index: number
}

-- Bindables and Folders
local ItemAssets = Assets:WaitForChild("Items")
local GetSerializedData: BindableFunction = ServerBindables:WaitForChild("GetSerializedData")
local SetSerializedData: BindableFunction = ServerBindables:WaitForChild("SetSerializedData")
local invokeAction: RemoteFunction = Remotes:WaitForChild("InvokeInventoryAction")

local DropPlaceHolder: BasePart = PlaceHolders:WaitForChild("DropPlaceholder")

function module.AddItemToAvailableSlot(player: Player, itemId: string, quantity: number)
	local serializedData = GetSerializedData:Invoke(player)
	if not serializedData then return nil end

	local itemMeta = ItemDesc[itemId]
	if not itemMeta then return nil end

	local inventoriesToSearch = {"Hotbar", "Main"}
	local maxSlots = { Main = 24, Hotbar = 8 }

	-- First, find a slot to stack with
	if itemMeta.Stacking then
		for _, invType in ipairs(inventoriesToSearch) do
			local inv = serializedData[invType]
			if inv then
				for i = 1, maxSlots[invType] do
					local slot = inv[i]
					if slot and slot.ItemId == itemId and slot.Quantity < (itemMeta.MaxStack or 64) then
						serializedData[invType][i].Quantity += quantity
						SetSerializedData:Invoke(player, serializedData)
						return serializedData
					end
				end
			end
		end
	end

	-- If no stackable slot, find an empty slot
	for _, invType in ipairs(inventoriesToSearch) do
		local inv = serializedData[invType]
		if inv then
			for i = 1, maxSlots[invType] do
				local slot = inv[i]
				if not slot or not slot.ItemId then
					serializedData[invType][i] = { ItemId = itemId, Quantity = quantity }
					SetSerializedData:Invoke(player, serializedData)
					return serializedData
				end
			end
		end
	end

	return serializedData
end

function module.DropItem(player: Player, slotIndex: number, quantity: number): boolean
	local serializedData = GetSerializedData:Invoke(player)
	if not serializedData then return false end
	
	local hotBarinfo = serializedData["Hotbar"]
	local slotInfo = hotBarinfo[slotIndex]
	if not slotInfo.ItemId then return false end
	
	local itemInfo = ItemDesc[slotInfo.ItemId]
	if not itemInfo then return false end

	if quantity <= 0 or quantity > slotInfo.Quantity then
		return false
	end
	
	hotBarinfo[slotIndex].Quantity -= quantity
	if hotBarinfo[slotIndex].Quantity <= 0 then
		hotBarinfo[slotIndex] = {}
	end
	SetSerializedData:Invoke(player, serializedData)

	local success = invokeAction:InvokeClient(player, "LoadFromSerialized", serializedData)

	-- drop item in front of the player
	local itemPart = DropPlaceHolder:Clone()
	local proxPrompt: ProximityPrompt = itemPart.ProximityPrompt
	proxPrompt.ActionText = slotInfo.ItemId
	local itemUi: ImageButton = itemPart.BillboardGui.Frame.Item1.Preview
	itemUi.Image = "rbxassetid://" .. itemInfo.Icon
	itemUi.Parent.StackedAmt.Text = "x" .. tostring(quantity)
	itemPart.Position = player.Character.HumanoidRootPart.Position + (player.Character.HumanoidRootPart.CFrame.LookVector.Unit * 5)
	itemPart.Parent = workspace

	proxPrompt.Triggered:Connect(function(triggeringPlayer: Player)
		serializedData = module.AddItemToAvailableSlot(triggeringPlayer, slotInfo.ItemId, quantity)
		local success = invokeAction:InvokeClient(player, "LoadFromSerialized", serializedData)
		
		if success then itemPart:Destroy() end
	end)
	
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
