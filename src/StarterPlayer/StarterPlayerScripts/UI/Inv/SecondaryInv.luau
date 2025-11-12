local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ItemDesc = require(ReplicatedStorage.Modules.ItemDesc)

local ClientInventory = {}
ClientInventory.__index = ClientInventory

export type ItemData = {
	ItemId: string,
	Quantity: number,
}

export type Inventory = {
	Slots: { [number]: ItemData? },
	MaxSlots: number,
	_UISlotsCache: { [number]: {} },
	_isInitialized: boolean,

	ArmorSlots: { [number]: ItemData? },
	MaxArmorSlots: number,
	_ArmorUISlotsCache: { [number]: {} },
	_isArmorInitialized: boolean,

	OffhandSlot: ItemData?,
	_OffhandUISlotCache: {}?,
	_isOffhandInitialized: boolean,

	HotbarSlots: { [number]: ItemData? },
	MaxHotbarSlots: number,
	_HotbarUISlotsCache: { [number]: {} },
	_isHotbarInitialized: boolean,
}

function ClientInventory.new(maxSlots: number): Inventory
	local self = setmetatable({
		Slots = {},
		MaxSlots = maxSlots,
		_UISlotsCache = {},
		_isInitialized = false,

		ArmorSlots = {},
		MaxArmorSlots = 4,
		_ArmorUISlotsCache = {},
		_isArmorInitialized = false,

		OffhandSlot = nil,
		_OffhandUISlotCache = nil,
		_isOffhandInitialized = false,

		HotbarSlots = {},
		MaxHotbarSlots = 8,
		_HotbarUISlotsCache = {},
		_isHotbarInitialized = false,
		
		ToolbarSlots = {},
		_ToolbarUISlotsCache = {},
		_isToolbarInitialized = false,
	}, ClientInventory)
	return self
end

function ClientInventory:_updateSlotVisuals(slotUI, slotData: ItemData?)
	if not slotUI then return end

	if (not slotData) or (slotData.Quantity == nil) or (slotData.Quantity < 1) then
		slotUI.Item.Value = ""
		slotUI.Quantity.Value = 0
		slotUI.Preview.Image = ""
		slotUI.Button.ImageColor3 = Color3.fromRGB(255, 225, 165)
		if slotUI.StackedAmt then
			slotUI.StackedAmt.Visible = false
		end
		return
	end

	local itemConfig = ItemDesc[slotData.ItemId]
	if not itemConfig then
		error("NO itemConfig found", 3)
		return
	end

	slotUI.Item.Value = slotData.ItemId
	slotUI.Quantity.Value = slotData.Quantity
	slotUI.Preview.Image = "rbxassetid://" .. itemConfig.Icon
	slotUI.Preview.Visible = true

	if slotUI.StackedAmt then
		slotUI.StackedAmt.Text = tostring(slotData.Quantity)
		slotUI.StackedAmt.Visible = true
	end

	local rarity = itemConfig.Rarity and string.lower(itemConfig.Rarity) or "common"
	
	if rarity == "common" then
		slotUI.Button.ImageColor3 = Color3.fromRGB(0, 0, 255)
	elseif rarity == "rare" then
		slotUI.Button.ImageColor3 = Color3.fromRGB(255, 0, 0)
	elseif rarity == "legendary" then
		slotUI.Button.ImageColor3 = Color3.fromRGB(255, 255, 0)
	else
		slotUI.Button.ImageColor3 = Color3.fromRGB(255, 225, 165)
	end
end

function ClientInventory:_updateAllSlots()
	for i = 1, self.MaxSlots do
		self:_updateUISlot(i)
	end
	for i = 1, self.MaxArmorSlots do
		self:_updateArmorUISlot(i)
	end
	for i = 1, self.MaxHotbarSlots do
		self:_updateHotbarUISlot(i)
	end
	
	self:_updateOffhandUISlot()
end

function ClientInventory:_updateUISlot(slotIndex: number)
	if not self._isInitialized then return end
	self:_updateSlotVisuals(self._UISlotsCache[slotIndex], self.Slots[slotIndex])
end

function ClientInventory:_clearUISlot(slotIndex: number)
	if not self._isInitialized then return end
	self:_updateSlotVisuals(self._UISlotsCache[slotIndex], nil)
end

function ClientInventory:_updateArmorUISlot(slotIndex: number)
	if not self._isArmorInitialized then return end
	self:_updateSlotVisuals(self._ArmorUISlotsCache[slotIndex], self.ArmorSlots[slotIndex])
end

function ClientInventory:_clearArmorUISlot(slotIndex: number)
	if not self._isArmorInitialized then return end
	self:_updateSlotVisuals(self._ArmorUISlotsCache[slotIndex], nil)
end

function ClientInventory:_updateOffhandUISlot()
	if not self._isOffhandInitialized then return end
	self:_updateSlotVisuals(self._OffhandUISlotCache, self.OffhandSlot)

	if self._isToolbarInitialized and self._ToolbarOffhandUISlotCache then
		self:_updateSlotVisuals(self._ToolbarOffhandUISlotCache, self.OffhandSlot)
	end
end

function ClientInventory:_clearOffhandUISlot()
	if not self._isOffhandInitialized then return end
	self:_updateSlotVisuals(self._OffhandUISlotCache, nil)

	if self._isToolbarInitialized and self._ToolbarOffhandUISlotCache then
		self:_updateSlotVisuals(self._ToolbarOffhandUISlotCache, nil)
	end
end

function ClientInventory:_updateHotbarUISlot(slotIndex: number)
	if not self._isHotbarInitialized then return end

	self:_updateSlotVisuals(self._HotbarUISlotsCache[slotIndex], self.HotbarSlots[slotIndex])

	if self._isToolbarInitialized then
		self:_updateSlotVisuals(self._ToolbarUISlotsCache[slotIndex], self.HotbarSlots[slotIndex])
	end
end

function ClientInventory:_clearHotbarUISlot(slotIndex: number)
	if not self._isHotbarInitialized then return end

	self:_updateSlotVisuals(self._HotbarUISlotsCache[slotIndex], nil)

	if self._isToolbarInitialized then
		self:_updateSlotVisuals(self._ToolbarUISlotsCache[slotIndex], nil)
	end
end

function ClientInventory:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local inventoryFrame = playerGui:WaitForChild("Inventory"):WaitForChild("InventoryFrame")

	if self._isInitialized and self._isArmorInitialized and self._isOffhandInitialized and self._isHotbarInitialized and self._isToolbarInitialized then
		return self
	end

	if not self._isInitialized then
		local slotsContainer = inventoryFrame.Tabs.Items.Frame.Menu
		for i = 1, self.MaxSlots do
			local slotButton = slotsContainer:FindFirstChild("Item" .. i)
			if slotButton and slotButton:IsA("ImageButton") then
				self._UISlotsCache[i] = {
					Button = slotButton,
					Preview = slotButton:WaitForChild("Preview", 5),
					Item = slotButton:WaitForChild("Item", 5),
					Quantity = slotButton:WaitForChild("Quantity", 5),
					StackedAmt = slotButton:FindFirstChild("StackedAmt"),
				}
				if self._UISlotsCache[i].StackedAmt then
					self._UISlotsCache[i].StackedAmt.Visible = false
					self._UISlotsCache[i].StackedAmt.ZIndex = 2
				end
			end
		end
		self._isInitialized = true
	end

	if not self._isArmorInitialized then
		local armorSlotsContainer = inventoryFrame.Tabs.Items.Frame.Main.Left
		for i = 1, self.MaxArmorSlots do
			local slotButton = armorSlotsContainer:FindFirstChild("Item" .. i)
			if slotButton and slotButton:IsA("ImageButton") then
				self._ArmorUISlotsCache[i] = {
					Button = slotButton,
					Preview = slotButton:WaitForChild("Preview", 5),
					Item = slotButton:WaitForChild("Item", 5),
					Quantity = slotButton:WaitForChild("Quantity", 5),
					StackedAmt = slotButton:FindFirstChild("StackedAmt"),
				}
				if self._ArmorUISlotsCache[i].StackedAmt then
					self._ArmorUISlotsCache[i].StackedAmt.Visible = false
					self._ArmorUISlotsCache[i].StackedAmt.ZIndex = 2
				end
			end
		end
		self._isArmorInitialized = true
	end

	if not self._isOffhandInitialized then
		local offhandSlot = inventoryFrame.Tabs.Items.Frame.Main.Right:FindFirstChild("Item1")
		if offhandSlot and offhandSlot:IsA("ImageButton") then
			self._OffhandUISlotCache = {
				Button = offhandSlot,
				Preview = offhandSlot:WaitForChild("Preview", 5),
				Item = offhandSlot:WaitForChild("Item", 5),
				Quantity = offhandSlot:WaitForChild("Quantity", 5),
				StackedAmt = offhandSlot:FindFirstChild("StackedAmt"),
			}
			if self._OffhandUISlotCache.StackedAmt then
				self._OffhandUISlotCache.StackedAmt.Visible = false
				self._OffhandUISlotCache.StackedAmt.ZIndex = 2
			end
		end
		self._isOffhandInitialized = true
	end

	if not self._isHotbarInitialized then
		local hotbarContainer = inventoryFrame.Tabs.Items.Frame.SeparatedMenu
		for i = 1, self.MaxHotbarSlots do
			local slotButton = hotbarContainer:FindFirstChild("Item" .. i)
			if slotButton and slotButton:IsA("ImageButton") then
				self._HotbarUISlotsCache[i] = {
					Button = slotButton,
					Preview = slotButton:WaitForChild("Preview", 5),
					Item = slotButton:WaitForChild("Item", 5),
					Quantity = slotButton:WaitForChild("Quantity", 5),
					StackedAmt = slotButton:FindFirstChild("StackedAmt"),
				}
				if self._HotbarUISlotsCache[i].StackedAmt then
					self._HotbarUISlotsCache[i].StackedAmt.Visible = false
					self._HotbarUISlotsCache[i].StackedAmt.ZIndex = 2
				end
			end
		end
		self._isHotbarInitialized = true
	end

	if not self._isToolbarInitialized then
		local toolbarContainer = playerGui:WaitForChild("Hotbar"):WaitForChild("Toolbar")
		
		for i = 1, self.MaxHotbarSlots do
			local slotButton = toolbarContainer:FindFirstChild("Item" .. i)
			if slotButton and slotButton:IsA("ImageLabel") then
				self._ToolbarUISlotsCache[i] = {
					Button = slotButton,
					Preview = slotButton:WaitForChild("Preview", 5),
					Item = slotButton:WaitForChild("Item", 5),
					Quantity = slotButton:WaitForChild("Quantity", 5),
					StackedAmt = slotButton:FindFirstChild("StackedAmt"),
				}
				if self._ToolbarUISlotsCache[i].StackedAmt then
					self._ToolbarUISlotsCache[i].StackedAmt.Visible = false
					self._ToolbarUISlotsCache[i].StackedAmt.ZIndex = 2
				end
			end
		end
		self._isToolbarInitialized = true
	end
	
	local toolbarContainer = playerGui:WaitForChild("Hotbar"):WaitForChild("Toolbar")
	local toolbarOffhand = toolbarContainer:FindFirstChild("Offhand")
	if toolbarOffhand and toolbarOffhand:IsA("ImageLabel") then
		self._ToolbarOffhandUISlotCache = {
			Button = toolbarOffhand,
			Preview = toolbarOffhand:WaitForChild("Preview", 5),
			Item = toolbarOffhand:WaitForChild("Item", 5),
			Quantity = toolbarOffhand:WaitForChild("Quantity", 5),
			StackedAmt = toolbarOffhand:FindFirstChild("StackedAmt"),
		}
		if self._ToolbarOffhandUISlotCache.StackedAmt then
			self._ToolbarOffhandUISlotCache.StackedAmt.Visible = false
			self._ToolbarOffhandUISlotCache.StackedAmt.ZIndex = 2
		end
	end

	self._isToolbarInitialized = true

	return self
end

function ClientInventory:LoadFromSerialized(serializedData)
	if not (self._isInitialized and self._isArmorInitialized and self._isOffhandInitialized and self._isHotbarInitialized) then return false end
	
	self.Slots = {}
	self.ArmorSlots = {}
	self.HotbarSlots = {}
	self.OffhandSlot = {}

	for i, stuff in serializedData["Main"] do
		if not stuff or not stuff.ItemId then continue end
		self.Slots[tonumber(i)] = stuff
	end

	for i, stuff in serializedData["Armor"] do
		if not stuff or not stuff.ItemId then continue end
		self.ArmorSlots[tonumber(i)] = stuff
	end

	for i, stuff in serializedData["Hotbar"] do
		if not stuff or not stuff.ItemId then continue end
		self.HotbarSlots[tonumber(i)] = stuff
	end

	self.OffhandSlot = serializedData["Offhand"][1]
	self:_updateAllSlots()

	return true
end

function ClientInventory:GetItemInSlot(slotIndex: number): ItemData?
	if slotIndex > 0 and slotIndex <= self.MaxSlots then
		return self.Slots[slotIndex]
	end
	return nil
end

function ClientInventory:GetArmorInSlot(slotIndex: number): ItemData?
	if slotIndex > 0 and slotIndex <= self.MaxArmorSlots then
		return self.ArmorSlots[slotIndex]
	end
	return nil
end

function ClientInventory:GetOffhandInSlot(): ItemData?
	return self.OffhandSlot
end

function ClientInventory:GetItemInHotbarSlot(slotIndex: number): ItemData?
	if slotIndex > 0 and slotIndex <= self.MaxSlots then
		return self.HotbarSlots[slotIndex]
	end
	return nil
end

function ClientInventory:AddItemToSlot(slotIndex: number, itemId: string, quantity: number): boolean
	if slotIndex <= 0 or slotIndex > self.MaxSlots then
		warn("Invalid slot index.")
		return false
	end

	local existingItem = self.Slots[slotIndex]
	if existingItem then
		if existingItem.ItemId == itemId then
			existingItem.Quantity += quantity
			self:_updateUISlot(slotIndex)
			return true
		else
			warn("Cannot overwrite existing item in slot.")
			return false
		end
	end

	self.Slots[slotIndex] = {
		ItemId = itemId,
		Quantity = quantity,
	}
	self:_updateUISlot(slotIndex)
	return true
end

function ClientInventory:RemoveItemFromSlot(slotIndex: number, quantity: number): boolean
	if slotIndex <= 0 or slotIndex > self.MaxSlots then return false end
	local itemInSlot = self.Slots[slotIndex]
	if not itemInSlot then return false end
	if quantity == nil then quantity = itemInSlot.Quantity end

	if itemInSlot.Quantity >= quantity then
		itemInSlot.Quantity -= quantity
		if itemInSlot.Quantity <= 0 then
			self.Slots[slotIndex] = nil
		end
		self:_updateUISlot(slotIndex)
		return true
	end
	return false
end

function ClientInventory:ClearSlot(slotIndex: number): boolean
	if slotIndex > 0 and slotIndex <= self.MaxSlots and self.Slots[slotIndex] then
		self.Slots[slotIndex] = nil
		self:_clearUISlot(slotIndex)
		return true
	end
	return false
end

function ClientInventory:AddArmorToSlot(slotIndex: number, itemId: string, quantity: number): boolean
	if slotIndex <= 0 or slotIndex > self.MaxArmorSlots then
		warn("Invalid armor slot index.")
		return false
	end
	self.ArmorSlots[slotIndex] = {
		ItemId = itemId,
		Quantity = quantity,
	}
	self:_updateArmorUISlot(slotIndex)
	return true
end

function ClientInventory:RemoveArmorFromSlot(slotIndex: number, quantity: number): boolean
	if slotIndex <= 0 or slotIndex > self.MaxArmorSlots then return false end
	local itemInSlot = self.ArmorSlots[slotIndex]
	if not itemInSlot then return false end
	if quantity == nil then quantity = itemInSlot.Quantity end

	if itemInSlot.Quantity >= quantity then
		itemInSlot.Quantity -= quantity
		if itemInSlot.Quantity <= 0 then
			self.ArmorSlots[slotIndex] = nil
		end
		self:_updateArmorUISlot(slotIndex)
		return true
	end
	return false
end

function ClientInventory:ClearArmorSlot(slotIndex: number): boolean
	if slotIndex > 0 and slotIndex <= self.MaxArmorSlots and self.ArmorSlots[slotIndex] then
		self.ArmorSlots[slotIndex] = nil
		self:_clearArmorUISlot(slotIndex)
		return true
	end
	return false
end

function ClientInventory:AddOffhandToSlot(itemId: string, quantity: number): boolean
	if quantity <= 0 then return false end
	self.OffhandSlot = {
		ItemId = itemId,
		Quantity = quantity,
	}
	self:_updateOffhandUISlot()
	return true
end

function ClientInventory:RemoveOffhandFromSlot(quantity: number?): boolean
	if not self.OffhandSlot then return false end
	if not quantity then quantity = self.OffhandSlot.Quantity end

	if self.OffhandSlot.Quantity >= quantity then
		self.OffhandSlot.Quantity -= quantity
		if self.OffhandSlot.Quantity <= 0 then
			self.OffhandSlot = nil
		end
		self:_updateOffhandUISlot()
		return true
	end
	return false
end

function ClientInventory:ClearOffhandSlot(): boolean
	if self.OffhandSlot then
		self.OffhandSlot = nil
		self:_clearOffhandUISlot()
		return true
	end
	return false
end

function ClientInventory:AddItemToHotbarSlot(slotIndex: number, itemId: string, quantity: number): boolean
	if slotIndex <= 0 or slotIndex > self.MaxHotbarSlots then
		warn("Invalid hotbar slot index.")
		return false
	end
	
	self.HotbarSlots[slotIndex] = {
		ItemId = itemId,
		Quantity = quantity,
	}
	
	self:_updateHotbarUISlot(slotIndex)
	return true
end

function ClientInventory:RemoveItemFromHotbarSlot(slotIndex: number, quantity: number): boolean
	if slotIndex <= 0 or slotIndex > self.MaxHotbarSlots then return false end
	local itemInSlot = self.HotbarSlots[slotIndex]
	if not itemInSlot then return false end
	if quantity == nil then quantity = itemInSlot.Quantity end

	if itemInSlot.Quantity >= quantity then
		itemInSlot.Quantity -= quantity
		if itemInSlot.Quantity <= 0 then
			self.HotbarSlots[slotIndex] = nil
		end
		self:_updateHotbarUISlot(slotIndex)
		return true
	end
	return false
end

function ClientInventory:ClearItemFromHotbarSlot(slotIndex: number): boolean
	if slotIndex > 0 and slotIndex <= self.MaxHotbarSlots and self.HotbarSlots[slotIndex] then
		self.HotbarSlots[slotIndex] = nil
		self:_clearHotbarUISlot(slotIndex)
		return true
	end
	return false
end

function ClientInventory:RenderAll()
	self:RenderFromData()
	self:RenderArmorFromData()
	self:RenderOffhandFromData()
	self:RenderHotbarFromData()
end

function ClientInventory:RenderFromData()
	if not self._isInitialized then return end
	for i = 1, self.MaxSlots do
		self:_updateUISlot(i)
	end
end

function ClientInventory:RenderArmorFromData()
	if not self._isArmorInitialized then return end
	for i = 1, self.MaxArmorSlots do
		self:_updateArmorUISlot(i)
	end
end

function ClientInventory:RenderOffhandFromData()
	if not self._isOffhandInitialized then return end
	self:_updateOffhandUISlot()
end

function ClientInventory:RenderHotbarFromData()
	if not self._isHotbarInitialized then return end
	for i = 1, self.MaxHotbarSlots do
		self:_updateHotbarUISlot(i)
	end
end

return ClientInventory
