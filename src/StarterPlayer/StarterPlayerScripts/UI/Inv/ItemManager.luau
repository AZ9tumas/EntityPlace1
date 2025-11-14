--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local itemDesc = require(Modules:WaitForChild("ItemDesc"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipSlotEvent: RemoteFunction = Remotes:WaitForChild("EquipSlot")

local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local PlaceablesFolder = AssetsFolder:WaitForChild("Placeables")

local ItemManager = {}
ItemManager.__index = ItemManager

export type ItemManager = {
	_currentActivatedItem: {
		Item: {ItemId: string, Quantity: number},
		ItemMeta: {[string]: any},
		slotIndex: number?,
		Tool: Tool?
	}?,
	_runServiceConnection: RBXScriptConnection?,
}

export type PlacementHologram = {
	Model: Model,
}

function ItemManager.new(): ItemManager
	local self = setmetatable({}, ItemManager)
	self._currentActivatedItem = nil
	self._runServiceConnection = nil
	self._placementHologram = nil
	
	return self
end

function ItemManager:InitializeItem(itemData, slotIndex: number)
	local info = itemDesc[itemData.ItemId]
	if not info then return false end
	self._currentActivatedItem = {Item = itemData, slotIndex = slotIndex, Tool = nil, ItemMeta = info}

	local success, canActivate = EquipSlotEvent:InvokeServer(true, slotIndex)
	if not success then return false end
	
	if canActivate then return self:EquipItem() end
	if info.placeable then return self:InitializeItemPlacement() end

	return true
end

function ItemManager:TerminateItem()
	if not self._currentActivatedItem then return false end
	
	if self._currentActivatedItem.Tool then
		self:UnequipItem(self._currentActivatedItem.slotIndex :: number)
	elseif  self._currentActivatedItem.ItemMeta.placeable then
		self:TerminateItemPlacement()
	end

	self._currentActivatedItem = nil
	return true
end

function ItemManager:ActivateCurrentItem(): boolean
	-- handled directly by ClientInit.client.luau
	if not self._currentActivatedItem then return false end
	if self._currentActivatedItem.Tool then return self:ActivateTool() end
	if self._currentActivatedItem.ItemMeta.placeable then
		return self:PlaceItem()
	end
	
	return true
end

function ItemManager:DeactivateCurrentItem(): boolean
	-- handled directly by ClientInit.client.luau
	if not self._currentActivatedItem then return false end
	if self._currentActivatedItem.Tool then return self:DeactivateTool() end
	
	return true
end

------------------------------------------------------------------------

function ItemManager:EquipItem(): boolean
	if not self._currentActivatedItem then return false end

	local itemData = self._currentActivatedItem.Item

	local asset = player.Backpack:FindFirstChild(itemData.ItemId)
	if not asset then return false end

	self._currentActivatedItem.Tool = asset
	task.wait()
	ContentProvider:PreloadAsync(asset:GetDescendants())
	
	local events = asset:FindFirstChild("Events")
	if not events then return false end
	
	local equip = events:FindFirstChild("Equip") :: BindableEvent
	if not equip then return false end
	
	equip:Fire()
	return true
end

function ItemManager:UnequipItem(slotIndex: number): boolean
	if not self._currentActivatedItem then return false end
	
	local asset = self._currentActivatedItem.Tool
	if not asset then return false end
	
	local events = asset:FindFirstChild("Events")
	if not events then 
		self._currentActivatedItem = nil
		return false
	end
	
	local unequip: BindableEvent = events:FindFirstChild("Unequip")
	if not unequip then 
		self._currentActivatedItem = nil
		return false
	end
	
	unequip:Fire()
	task.wait()
	
	EquipSlotEvent:InvokeServer(false, slotIndex)
	self._currentActivatedItem = nil
	
	return true
end

function ItemManager:ActivateTool(): boolean
	local tool = self._currentActivatedItem.Tool
	local events = tool:FindFirstChild("Events")
	if not events then return false end
	
	local activateBR: BindableEvent = events:FindFirstChild("ToolActivate")
	if not activateBR then return false end
	
	activateBR:Fire()
end

function ItemManager:DeactivateTool(): boolean
	local tool = self._currentActivatedItem.Tool
	local events = tool:FindFirstChild("Events")
	if not events then return false end
	
	local deactivateBR: BindableEvent = events:FindFirstChild("ToolDeactivate")
	if not deactivateBR then return false end
	
	deactivateBR:Fire()
end

------------------------------------------------------------------------

local function snapToGrid(position: Vector3, gridVector: Vector3): Vector3
	local x = math.floor(position.X / gridVector.X + 1) * gridVector.X
	local y = position.Y --  math.floor(position.Y / gridVector.Y + 1) * gridVector.Y
	local z = math.floor(position.Z / gridVector.Z + 1) * gridVector.Z
	return Vector3.new(x, y, z)
end

function ItemManager:InitializeItemPlacement()
	local itemData = self._currentActivatedItem.Item
	local asset = PlaceablesFolder:FindFirstChild(itemData.ItemId)
	if not asset then return false end

	asset = asset:Clone()
	asset.Parent = workspace
	self._placementHologram = {} :: PlacementHologram
	self._placementHologram.Model = asset

	-- transparency
	for _, v in pairs(asset:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Transparency = 0.5
			v.CanCollide = false
			v.Anchored = true
		end
	end

	mouse.TargetFilter = asset

	self._runServiceConnection = RunService.RenderStepped:Connect(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { asset, player.Character }

		local res = workspace:Raycast(mouse.Origin.Position, mouse.UnitRay.Direction * 25, params)
		if res then
			-- update placement preview here
			local snappedPos = snapToGrid(res.Position, asset.PrimaryPart.Size)
			snappedPos += Vector3.new(0, asset.PrimaryPart.Size.Y / 2, 0)
			asset.PrimaryPart.CFrame = CFrame.new(snappedPos)
		end
	end)
	print("trying to place", itemData)
end

function ItemManager:TerminateItemPlacement()
	print("terminating placement")
	self._runServiceConnection:Disconnect()
	self._runServiceConnection = nil

	self._placementHologram.Model:Destroy()
	self._placementHologram = nil
end

function ItemManager:PlaceItem()
	local itemData = self._currentActivatedItem.Item
	print("placing item", itemData)

	
end

return ItemManager