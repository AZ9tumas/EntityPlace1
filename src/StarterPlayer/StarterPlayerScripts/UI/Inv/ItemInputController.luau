local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider") 
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDescM = require(ReplicatedStorage.Modules.ItemDesc)
local ClientInventory = require(script.Parent.SecondaryInv)
local ItemManagerModule = require(script.Parent.ItemManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InvokeInventoryAction : RemoteFunction = Remotes:WaitForChild("InvokeInventoryAction")
local EquipSlotEvent: RemoteFunction = Remotes:WaitForChild("EquipSlot")
local DropItemEvent: RemoteFunction = Remotes:WaitForChild("DropItem")

local player = Players.LocalPlayer

type ItemReference = {
	InvType: string,
	Index: number
}
type Inventory = ClientInventory.Inventory
type ItemData = ClientInventory.ItemData

local ItemInputController = {}
ItemInputController.__index = ItemInputController

function ItemInputController.new(invFrame: Frame)
	local self = setmetatable({}, ItemInputController)

	self._inventory = ClientInventory.new(24):Init()
	self._invFrame = invFrame
	self._dragImage = invFrame.Parent:WaitForChild("Drag") :: ImageLabel
	self._dragImage.ZIndex = 10

	self._templateFrame = invFrame.Parent:WaitForChild("template")
	self._templateFrame.Visible = false
	self._currentlyHoveredRef = nil
	self._hoverUpdateConn = nil

	self._slots = {}
	self._armorSlots = {}
	self._offhandSlots = {}
	self._hotbarSlots = {} -- this is INSIDE the inv
	
	self._toolbarSlots = {} -- stuff that is outside the inv
	
	self._runServiceConnection = nil
	self._draggedItemStack = nil :: ItemData?
	self._draggedItemOldRef = nil
	
	self._itemManager = ItemManagerModule.new()

	self:_initSlots()
	self:_initHoverSystem()
	self:_connectGlobalInput()
	return self
end

function ItemInputController:Initialize()
	if self._isActive then return end
	self._isActive = true

	self._inventory:Init()
	self:_initHoverSystem()
	self:_connectGlobalInput()
	self._inventory:RenderAll()
	
	local serializedData = InvokeInventoryAction:InvokeServer("GetData")['data']
	if not serializedData then
		return
	end
	self._inventory:LoadFromSerialized(serializedData)
end

local function highlightSlot(self, slotIndex)
	local slotui: ImageLabel = self._toolbarSlots[slotIndex]
	if not slotui then return end
	
	local thing: UIStroke = slotui:FindFirstChildWhichIsA("UIStroke") :: UIStroke
	--prev.ImageTransparency = 0.5
	--slotui.Transparency = 0.5
	thing.Color = Color3.fromRGB(79, 79, 79)
end

local function unhiglightSlot(self, slotIndex)
	local slotui: ImageLabel = self._toolbarSlots[slotIndex]
	if not slotui then return end
	
	local thing: UIStroke = slotui:FindFirstChildWhichIsA("UIStroke") :: UIStroke
	--prev.ImageTransparency = 0
	--slotui.Transparency = 0
	thing.Color = Color3.fromRGB(255, 227, 166)
end

-- Dropping Items
function ItemInputController:DropItem()
	local currentItem = self._itemManager._currentActivatedItem
	if not currentItem then return end
	
	local slotIndex = currentItem.slotIndex
	self._itemManager:TerminateItem()
	
	local itemData = self._inventory:GetItemInHotbarSlot(slotIndex)
	if not itemData then return end
	
	local success = DropItemEvent:InvokeServer(slotIndex, 1)
	if success then
		--self._inventory:RemoveItemFromHotbarSlot(slotIndex, 1)
		unhiglightSlot(self, slotIndex)
	else
		player:Kick("Major invalid move. Please rejoin the game.")
	end
end

--[[
Current Tool Equipping System:

There are Bindable events present under the Events Folder under the tool itself
Here, we ask the server to get the tool into the backpack and call these events to equip / activate it.

]]

function ItemInputController:ActiveHotbarSlot(slotIndex: number)
	local currentItem = self._itemManager._currentActivatedItem
	
	if currentItem then
		unhiglightSlot(self, currentItem.slotIndex)
		self._itemManager:TerminateItem()
		return
	end
	
	local itemData = self._inventory:GetItemInHotbarSlot(slotIndex)
	if not itemData then return end
	
	highlightSlot(self, slotIndex)
	self._itemManager:InitializeItem(itemData, slotIndex)
end

function ItemInputController:CleanUp()
	if not self._isActive then return end
	self._isActive = false

	if self._hoverUpdateConn then
		self._hoverUpdateConn:Disconnect()
		self._hoverUpdateConn = nil
	end

	if self._globalInputConn then
		self._globalInputConn:Disconnect()
		self._globalInputConn = nil
	end

	self:_cancelDrag()

	self._templateFrame.Visible = false
end

-------------------------------------------------------------------------------------------------------------------------------

function ItemInputController:_updateTooltip()
	self._templateFrame.Visible = false
	
	if self._draggedItemStack or not self._currentlyHoveredRef then return end

	local itemData = self:_getItem(self._currentlyHoveredRef)
	if not itemData then return end

	local itemConfig = ItemDescM[itemData.ItemId]
	if not itemConfig then return end
	
	local mousePos = UserInputService:GetMouseLocation()
	self._dragImage.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
	
	self._templateFrame:FindFirstChild("Header").Text = itemData.ItemId
	self._templateFrame:FindFirstChild("Desc").Text = itemConfig.Description

	self._templateFrame.Visible = true
end

function ItemInputController:_initHoverSystem()
	local hoverContainer = self._invFrame.Tabs.Items.Frame

	hoverContainer.MouseLeave:Connect(function()
		self._currentlyHoveredRef = nil
		self:_updateTooltip()
	end)

	self._hoverUpdateConn = RunService.RenderStepped:Connect(function()
		if self._templateFrame.Visible then
			local mousePos = UserInputService:GetMouseLocation()
			self._templateFrame.Position = UDim2.fromOffset(mousePos.X + 15, mousePos.Y + 15)
		end
	end)
end

function ItemInputController:_initSlots()
	local slotsContainer = self._invFrame.Tabs.Items.Frame.Menu
	for i = 1, self._inventory.MaxSlots do
		local slotButton = slotsContainer:FindFirstChild("Item" .. i)
		if slotButton and slotButton:IsA("ImageButton") then
			self._slots[i] = slotButton
			local previewButton = slotButton:FindFirstChild("Preview")
			previewButton.MouseEnter:Connect(function()
				self._currentlyHoveredRef = {InvType = "Main", Index = i}
				self:_updateTooltip()
			end)
			previewButton.MouseButton1Down:Connect(function()
				self:_onSlotPressed({InvType = "Main", Index = i}, Enum.UserInputType.MouseButton1)
			end)
			previewButton.MouseButton2Down:Connect(function()
				self:_onSlotPressed({InvType = "Main", Index = i}, Enum.UserInputType.MouseButton2)
			end)
		end
	end

	local armorContainer = self._invFrame.Tabs.Items.Frame.Main.Left
	for i = 1, self._inventory.MaxArmorSlots do
		local slotButton = armorContainer:FindFirstChild("Item" .. i)
		if slotButton and slotButton:IsA("ImageButton") then
			self._armorSlots[i] = slotButton
			local previewButton = slotButton:FindFirstChild("Preview")
			previewButton.MouseEnter:Connect(function()
				self._currentlyHoveredRef = {InvType = "Armor", Index = i}
				self:_updateTooltip()
			end)
			previewButton.MouseButton1Down:Connect(function()
				self:_onSlotPressed({InvType = "Armor", Index = i}, Enum.UserInputType.MouseButton1)
			end)
			previewButton.MouseButton2Down:Connect(function()
				self:_onSlotPressed({InvType = "Armor", Index = i}, Enum.UserInputType.MouseButton2)
			end)
		end
	end

	local offhandContainer = self._invFrame.Tabs.Items.Frame.Main.Right
	for i = 1, 1 do
		local slotButton = offhandContainer:FindFirstChild("Item" .. i)
		if slotButton and slotButton:IsA("ImageButton") then
			self._offhandSlots[i] = slotButton
			local previewButton = slotButton:FindFirstChild("Preview")
			previewButton.MouseEnter:Connect(function()
				self._currentlyHoveredRef = {InvType = "Offhand", Index = i}
				self:_updateTooltip()
			end)
			previewButton.MouseButton1Down:Connect(function()
				self:_onSlotPressed({InvType = "Offhand", Index = i}, Enum.UserInputType.MouseButton1)
			end)
			previewButton.MouseButton2Down:Connect(function()
				self:_onSlotPressed({InvType = "Offhand", Index = i}, Enum.UserInputType.MouseButton2)
			end)
		end
	end
	
	local hotbarContainer = self._invFrame.Tabs.Items.Frame.SeparatedMenu
	for i = 1, 8 do
		local slotButton = hotbarContainer:FindFirstChild("Item" .. i)
		if slotButton and slotButton:IsA("ImageButton") then
			self._hotbarSlots[i] = slotButton
			local previewButton = slotButton:FindFirstChild("Preview")
			previewButton.MouseEnter:Connect(function()
				self._currentlyHoveredRef = {InvType = "Hotbar", Index = i}
				self:_updateTooltip()
			end)
			previewButton.MouseButton1Down:Connect(function()
				self:_onSlotPressed({InvType = "Hotbar", Index = i}, Enum.UserInputType.MouseButton1)
			end)
			previewButton.MouseButton2Down:Connect(function()
				self:_onSlotPressed({InvType = "Hotbar", Index = i}, Enum.UserInputType.MouseButton2)
			end)
		end
	end
	
	local toolbarContainer = self._invFrame.Parent.Parent.Hotbar.Toolbar
	for i = 1, 8 do
		local slotButton = toolbarContainer:FindFirstChild("Item" .. i)
		if slotButton then
			self._toolbarSlots[i] = slotButton
			local previewButton = slotButton:FindFirstChild("Preview")
		end
	end
end

function ItemInputController:_connectGlobalInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Escape and self._draggedItemStack then
			self:_cancelDrag()
		end
	end)
end

function ItemInputController:_getItem(ref)
	if ref.InvType == "Main" then
		return self._inventory:GetItemInSlot(ref.Index)
	elseif ref.InvType == "Armor" then
		return self._inventory:GetArmorInSlot(ref.Index)
	elseif ref.InvType == "Offhand" then
		return self._inventory:GetOffhandInSlot()
	elseif ref.InvType == "Hotbar" then
		return self._inventory:GetItemInHotbarSlot(ref.Index)
	end
end

function ItemInputController:_addItem(ref, itemId, quantity)
	if ref.InvType == "Main" then
		self._inventory:AddItemToSlot(ref.Index, itemId, quantity)
	elseif ref.InvType == "Armor" then
		self._inventory:AddArmorToSlot(ref.Index, itemId, quantity)
	elseif ref.InvType == "Offhand" then
		self._inventory:AddOffhandToSlot(itemId, quantity)
	elseif ref.InvType == "Hotbar" then
		self._inventory:AddItemToHotbarSlot(ref.Index, itemId, quantity)
	end
end

function ItemInputController:_clearSlot(ref)
	if ref.InvType == "Main" then
		self._inventory:ClearSlot(ref.Index)
	elseif ref.InvType == "Armor" then
		self._inventory:ClearArmorSlot(ref.Index)
	elseif ref.InvType == "Offhand" then
		self._inventory:ClearOffhandSlot()
	elseif ref.InvType == "Hotbar" then
		self._inventory:ClearItemFromHotbarSlot(ref.Index)
	end
end

function ItemInputController:_removeFromSlot(ref, qty)
	if ref.InvType == "Main" then
		self._inventory:RemoveItemFromSlot(ref.Index, qty)
	elseif ref.InvType == "Armor" then
		self._inventory:RemoveArmorFromSlot(ref.Index, qty)
	elseif ref.InvType == "Offhand" then
		self._inventory:RemoveOffhandFromSlot(qty)
	elseif ref.InvType == "Hotbar" then
		self._inventory:RemoveItemFromHotbarSlot(ref.Index, qty)
	end
end

function ItemInputController:_onSlotPressed(ref: {[string]: number | string}, inputType: Enum.UserInputType)
	local itemInSlot = self:_getItem(ref)
	self._currentlyHoveredRef = nil
	self:_updateTooltip()

	if not self._draggedItemStack then
		if not itemInSlot then return end

		self._draggedItemOldRef = ref

		if inputType == Enum.UserInputType.MouseButton1 then
			self._draggedItemStack = {ItemId = itemInSlot.ItemId, Quantity = itemInSlot.Quantity}
			self:_clearSlot(ref)
			self:_startDragVisuals()

		elseif inputType == Enum.UserInputType.MouseButton2 then
			local quantityToPickUp = math.ceil(itemInSlot.Quantity / 2)
			self._draggedItemStack = {
				ItemId = itemInSlot.ItemId,
				Quantity = quantityToPickUp,
			}
			self:_removeFromSlot(ref, quantityToPickUp)
			self:_startDragVisuals()
		end
	else
		local status = InvokeInventoryAction:InvokeServer(
			"RequestMoveItem",
			self._draggedItemOldRef,
			ref,
			(inputType == Enum.UserInputType.MouseButton2) and 1 or self._draggedItemStack.Quantity
		)

		if not status.success then
			self:CleanUp()
			self:Initialize()
			
			return warn("Invalid move.")
		end

		-- here onwards, local inv is updated but not ui

		if inputType == Enum.UserInputType.MouseButton1 then
			if itemInSlot and itemInSlot.ItemId ~= self._draggedItemStack.ItemId then
				self._draggedItemStack = {ItemId = itemInSlot.ItemId, Quantity = itemInSlot.Quantity}
			else
				self._draggedItemStack = nil
			end
		elseif inputType == Enum.UserInputType.MouseButton2 then
			self._draggedItemStack.Quantity -= 1
		end

		self:_updateDragVisuals()
		self._inventory:_updateAllSlots()
		if not self._draggedItemStack or self._draggedItemStack.Quantity <= 0 then
			self:_stopDragVisuals()
		else
			-- something is still there, update the old slot
			local funcName = "RemoveItemFrom" .. self._draggedItemOldRef.InvType .. "Slot"
			if self._draggedItemOldRef.InvType == "Main" then funcName = "RemoveItemFromSlot" end

			self._inventory[funcName](self._inventory, self._draggedItemOldRef.Index, self._draggedItemStack.Quantity)
		end
	end
end

function ItemInputController:_cancelDrag()
	if not self._draggedItemStack or not self._draggedItemOldRef then return end
	self:_addItem(self._draggedItemOldRef, self._draggedItemStack.ItemId, self._draggedItemStack.Quantity)
	self:_stopDragVisuals()
end

function ItemInputController:_updateDragVisuals()
	if not self._draggedItemStack then return end
	local itemConfig = ItemDescM[self._draggedItemStack.ItemId]
	if itemConfig then
		self._dragImage.Image = "rbxassetid://" .. itemConfig.Icon
		self._dragImage.StackedAmt.Text = self._draggedItemStack.Quantity
	end
end

function ItemInputController:_startDragVisuals()
	if not self._draggedItemStack then return end
	self:_updateDragVisuals()
	self._dragImage.Visible = true

	self._runServiceConnection = RunService.RenderStepped:Connect(function()
		local mousePos = UserInputService:GetMouseLocation()
		self._dragImage.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
	end)
end

function ItemInputController:_stopDragVisuals()
	self._draggedItemStack = nil
	self._draggedItemOldRef = nil
	self._dragImage.Visible = false

	if self._runServiceConnection then
		self._runServiceConnection:Disconnect()
		self._runServiceConnection = nil
	end
end

return ItemInputController
