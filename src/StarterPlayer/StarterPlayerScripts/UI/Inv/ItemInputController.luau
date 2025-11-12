local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider") 
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDescM = require(ReplicatedStorage.Modules.ItemDesc)
local ClientInventory = require(script.Parent.SecondaryInv)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InvokeInventoryAction : RemoteFunction = Remotes:WaitForChild("InvokeInventoryAction")
local EquipSlotEvent: RemoteFunction = Remotes:WaitForChild("EquipSlot")
local DropItemEvent: RemoteFunction = Remotes:WaitForChild("DropItem")

local player = Players.LocalPlayer

type Inventory = ClientInventory.Inventory
type ItemData = ClientInventory.ItemData

local ItemManager = {}
ItemManager.__index = ItemManager

function ItemManager.new(invFrame: Frame)
	local self = setmetatable({}, ItemManager)

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
	
	self._currentActivatedSlot = {} -- {Item = ..., slotIndex = {}, Tool = ...}

	self:_initSlots()
	self:_initHoverSystem()
	self:_connectGlobalInput()
	return self
end

function ItemManager:Initialize()
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

local function unequip(self, slotIndex)
	local itemData = self._currentActivatedSlot.Item
	local asset = self._currentActivatedSlot.Tool

	local events = asset:FindFirstChild("Events")
	if not events then self._currentActivatedSlot = {} return end

	local unequip = events:FindFirstChild("Unequip") :: BindableEvent
	if not unequip then self._currentActivatedSlot = {} return end

	unequip:Fire()
	task.wait()

	EquipSlotEvent:InvokeServer(false, slotIndex)
end

-- Dropping Items
function ItemManager:DropItem()
	if self._currentActivatedSlot.Item then
		unequip(self, self._currentActivatedSlot.slotIndex)
	end

	local slotIndex = self._currentActivatedSlot.slotIndex
	if not slotIndex then return end
	
	local itemData = self._inventory:GetItemInHotbarSlot(slotIndex)
	if not itemData then return end
	
	local success = DropItemEvent:InvokeServer(slotIndex)
	if success then
		self._inventory:ClearItemFromHotbarSlot(slotIndex)
		print(self, slotIndex)
		unhiglightSlot(self, slotIndex)
		self._currentActivatedSlot = {}
	end
end

--[[
Current Tool Equipping System:

There are Bindable events present under the Events Folder under the tool itself
Here, we ask the server to get the tool into the backpack and call these events to equip / activate it.

]]

function ItemManager:ActiveHotbarSlot(slotIndex: number)
	if self._currentActivatedSlot.slotIndex then
		-- unhighlight that slot
		unhiglightSlot(self, self._currentActivatedSlot.slotIndex)
		if self._currentActivatedSlot.Item then
			-- deactivate
			unequip(self, self._currentActivatedSlot.slotIndex)
		end
		
		self._currentActivatedSlot = {}; return;
	end
	
	-- Equip
	local itemData = self._inventory:GetItemInHotbarSlot(slotIndex)
	if not itemData then return end

	self._currentActivatedSlot = {slotIndex = slotIndex}
	
	-- if we find an item we have to highlight it
	highlightSlot(self, slotIndex)
	
	local success, canActivate = EquipSlotEvent:InvokeServer(true, slotIndex)
	if not success or not canActivate then return end
	
	local asset = player.Backpack:FindFirstChild(itemData.ItemId)
	self._currentActivatedSlot = {Item = itemData, slotIndex = slotIndex, Tool = asset}
	
	task.wait()
	
	ContentProvider:PreloadAsync(asset:GetDescendants(), function(a, b)
		print(a, b)
	end)
	
	local events = asset:FindFirstChild("Events")
	if not events then return end -- died?
	
	local equip = events:FindFirstChild("Equip") :: BindableEvent
	if not equip then return end
	
	equip:Fire()
end

function ItemManager:ActivateCurrentTool()
	if not self._currentActivatedSlot.Item then return end

	local tool: Tool = self._currentActivatedSlot.Tool
	local events = tool:FindFirstChild("Events")
	if not events then return end

	local activateBR: BindableEvent = events:FindFirstChild("ToolActivate")
	activateBR:Fire()
end

function ItemManager:DeactivateCurrentTool()
	if not self._currentActivatedSlot.Item then return end

	local tool: Tool = self._currentActivatedSlot.Tool
	local events = tool:FindFirstChild("Events")
	if not events then return end

	local deactivateBR: BindableEvent = events:FindFirstChild("ToolDeactivate")
	deactivateBR:Fire()
end

function ItemManager:CleanUp()
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
	self._currentActivatedSlot = {}
end

-------------------------------------------------------------------------------------------------------------------------------

function ItemManager:_updateTooltip()
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

function ItemManager:_initHoverSystem()
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

function ItemManager:_initSlots()
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

function ItemManager:_connectGlobalInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Escape and self._draggedItemStack then
			self:_cancelDrag()
		end
	end)
end

function ItemManager:_getItem(ref)
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

function ItemManager:_addItem(ref, itemId, quantity)
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

function ItemManager:_clearSlot(ref)
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

function ItemManager:_removeFromSlot(ref, qty)
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

function ItemManager:_onSlotPressed(ref: {[string]: number | string}, inputType: Enum.UserInputType)
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

		if inputType == Enum.UserInputType.MouseButton1 then
			
			if not itemInSlot then
				self:_addItem(ref, self._draggedItemStack.ItemId, self._draggedItemStack.Quantity)
				self:_stopDragVisuals()
				
			elseif itemInSlot.ItemId == self._draggedItemStack.ItemId and (ItemDescM[itemInSlot.ItemId].Stacking) then
				self:_addItem(ref, self._draggedItemStack.ItemId, self._draggedItemStack.Quantity)
				self:_stopDragVisuals()
				
			else
				local itemToSwap = {ItemId = itemInSlot.ItemId, Quantity = itemInSlot.Quantity}
				self:_clearSlot(ref)
				self:_addItem(ref, self._draggedItemStack.ItemId, self._draggedItemStack.Quantity)
				self._draggedItemStack = itemToSwap
				self:_updateDragVisuals()
			end

		elseif inputType == Enum.UserInputType.MouseButton2 then
			if not itemInSlot then
				self:_addItem(ref, self._draggedItemStack.ItemId, 1)
				self._draggedItemStack.Quantity -= 1
			elseif itemInSlot.ItemId == self._draggedItemStack.ItemId then
				self:_addItem(ref, self._draggedItemStack.ItemId, 1)
				self._draggedItemStack.Quantity -= 1
			else
				local itemToSwap = {ItemId = itemInSlot.ItemId, Quantity = itemInSlot.Quantity}
				self:_clearSlot(ref)
				self:_addItem(ref, self._draggedItemStack.ItemId, self._draggedItemStack.Quantity)
				self._draggedItemStack = itemToSwap
				self:_updateDragVisuals()
				return
			end

			self:_updateDragVisuals()
			if self._draggedItemStack and self._draggedItemStack.Quantity <= 0 then
				self:_stopDragVisuals()
			end
		end
	end
end

function ItemManager:_cancelDrag()
	if not self._draggedItemStack or not self._draggedItemOldRef then return end
	self:_addItem(self._draggedItemOldRef, self._draggedItemStack.ItemId, self._draggedItemStack.Quantity)
	self:_stopDragVisuals()
end

function ItemManager:_updateDragVisuals()
	if not self._draggedItemStack then return end
	local itemConfig = ItemDescM[self._draggedItemStack.ItemId]
	if itemConfig then
		self._dragImage.Image = "rbxassetid://" .. itemConfig.Icon
		self._dragImage.StackedAmt.Text = self._draggedItemStack.Quantity
	end
end

function ItemManager:_startDragVisuals()
	if not self._draggedItemStack then return end
	self:_updateDragVisuals()
	self._dragImage.Visible = true

	self._runServiceConnection = RunService.RenderStepped:Connect(function()
		local mousePos = UserInputService:GetMouseLocation()
		self._dragImage.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
	end)
end

function ItemManager:_stopDragVisuals()
	self._draggedItemStack = nil
	self._draggedItemOldRef = nil
	self._dragImage.Visible = false

	if self._runServiceConnection then
		self._runServiceConnection:Disconnect()
		self._runServiceConnection = nil
	end
end

return ItemManager
